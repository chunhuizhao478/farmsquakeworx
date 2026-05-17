#!/usr/bin/env python3
"""
Automated Multi-Fault 2D Pipeline (CDBM rheology).

Generates a complete MOOSE .i input file for multi-fault dynamic rupture
simulations using the unified ComputeDamageBreakageStress3DSlipWeakening
material and the CDBM-coupled CZM friction (SlipWeakeningFrictionczm2dCDBM).

Reuses the geometry/mesh helpers from
applications/dynamicelastic_app/generate_multifault.py via sibling-app
import (see imports below). The only CDBM-specific logic lives here:
schema validation, parameter mapping, function block, and renderer.

Usage:
    python generate_multifault.py config.json [--dry-run] [--output-dir DIR]
"""

import argparse
import json
import math
import os
import sys
from typing import Optional, Tuple

# ---------------------------------------------------------------------------
# Sibling-app import: reuse the pure-geometry helpers from dynamicelastic_app.
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATES_DIR = os.path.join(SCRIPT_DIR, "templates")
ELASTIC_APP_DIR = os.path.abspath(
    os.path.join(SCRIPT_DIR, "..", "dynamicelastic_app")
)
sys.path.insert(0, ELASTIC_APP_DIR)
from generate_multifault import (  # noqa: E402
    validate_config,
    evaluate_fault_initial_stress,
    generate_geo,
    run_gmsh,
    extract_fault_elements,
    sort_fault_elements,
    build_mesh_data,
    get_block_pairs_string,
    get_boundary_list_string,
)


# ---------------------------------------------------------------------------
# CDBM-specific config schema validation
# ---------------------------------------------------------------------------

# Required CDBM keys for the unified ComputeDamageBreakageStress3DSlipWeakening
# (matches the addRequiredParam<Real> calls in
# src/materials/cdbm3d/ComputeDamageBreakageStress3DSlipWeakening.C).
CDBM_REQUIRED_KEYS = [
    "xi_0", "xi_d", "xi_max", "xi_min",
    "chi", "C_g", "m1", "m2",
    "Cd_constant", "C_1", "C_2", "beta_width",
    "CdCb_multiplier", "CBH_constant",
]

# Required base-physics keys (already needed by the elastic-app pipeline).
BASE_PHYSICS_REQUIRED_KEYS = [
    "q", "Dc", "mu_s", "mu_d",
    "density", "lambda_o", "shear_modulus_o",
]

# Defaults for the optional `nonlocal` block (match
# 2d_damagebreakage_case1/dynamic_solve.i header values).
DEFAULT_NONLOCAL = {
    "averaging_length_scale": 200,
    "averaging_radius": 400,
    "use_strain_rate_dependent_Cd": False,
    "m_exponent": 0.8,
    "strain_rate_hat": 5e-9,
    "cd_hat": 10,
}

# When the entire `nucleation` block is missing -> zero patch (R-007).
DEFAULT_NUCLEATION_ABSENT = {
    "peak_shear_stress": 0.0,
    "center": [0.0, 0.0],
    "radius": 0.0,
}

# When the `nucleation` block is present but a key is missing -> case1 values.
DEFAULT_NUCLEATION_PARTIAL = {
    "peak_shear_stress": 81.6e6,
    "center": [0.0, 0.0],
    "radius": 1500.0,
}


def validate_cdbm_physics(config):
    """Validate that the config carries every CDBM-required physics key.

    Raises ValueError with the documented message on missing key. Also enforces
    numeric-range constraints once all keys are present (per R-008, no
    'default if not given' fall-through).
    """
    physics = config.get("physics", {})

    for key in BASE_PHYSICS_REQUIRED_KEYS + CDBM_REQUIRED_KEYS:
        if key not in physics:
            if key in CDBM_REQUIRED_KEYS:
                raise ValueError(
                    f"Missing required CDBM physics key '{key}'. The unified "
                    f"ComputeDamageBreakageStress3DSlipWeakening material "
                    f"requires this parameter."
                )
            else:
                raise ValueError(
                    f"Missing required physics key '{key}'."
                )

    # Numeric ranges (R-008: xi_min/xi_max are required, so always defined).
    xi_0 = physics["xi_0"]
    xi_d = physics["xi_d"]
    xi_min = physics["xi_min"]
    xi_max = physics["xi_max"]
    if not (xi_min <= xi_0 <= xi_max):
        raise ValueError(
            f"xi_0 = {xi_0} must lie in [xi_min={xi_min}, xi_max={xi_max}]."
        )
    if not (xi_min <= xi_d <= xi_max):
        raise ValueError(
            f"xi_d = {xi_d} must lie in [xi_min={xi_min}, xi_max={xi_max}]."
        )

    if physics["Cd_constant"] < 0:
        raise ValueError(
            f"Cd_constant = {physics['Cd_constant']} must be >= 0."
        )
    if physics["CdCb_multiplier"] < 0:
        raise ValueError(
            f"CdCb_multiplier = {physics['CdCb_multiplier']} must be >= 0."
        )
    chi = physics["chi"]
    if not (0.0 < chi <= 1.0):
        raise ValueError(
            f"chi = {chi} must lie in (0, 1]."
        )

    # Nonlocal sanity warnings (not errors).
    nonlocal_cfg = config.get("nonlocal", DEFAULT_NONLOCAL)
    radius = nonlocal_cfg.get("averaging_radius",
                               DEFAULT_NONLOCAL["averaging_radius"])
    elem_size = config["domain"]["element_size"]
    if radius < elem_size:
        print(
            f"  WARNING: nonlocal averaging_radius ({radius}) < "
            f"element_size ({elem_size}); averaging will mostly degenerate "
            f"to local values."
        )
    if elem_size > 0 and radius / elem_size > 5:
        print(
            f"  WARNING: nonlocal averaging_radius / element_size = "
            f"{radius / elem_size:.1f} > 5; expect O(N^2) cost per timestep."
        )


# ---------------------------------------------------------------------------
# Parameter block builder
# ---------------------------------------------------------------------------

def _resolve_nucleation(config):
    """Resolve nucleation parameters per the R-007 rule.

    Returns dict with keys: peak_shear_stress, center, radius.
    """
    if "nucleation" not in config:
        # Entire block missing -> zero patch.
        return dict(DEFAULT_NUCLEATION_ABSENT)
    nucl = config["nucleation"]
    return {
        "peak_shear_stress": nucl.get(
            "peak_shear_stress", DEFAULT_NUCLEATION_PARTIAL["peak_shear_stress"]
        ),
        "center": nucl.get(
            "center", DEFAULT_NUCLEATION_PARTIAL["center"]
        ),
        "radius": nucl.get(
            "radius", DEFAULT_NUCLEATION_PARTIAL["radius"]
        ),
    }


def _resolve_nonlocal(config):
    """Resolve the nonlocal config sub-block, falling back to defaults."""
    user = config.get("nonlocal", {})
    out = dict(DEFAULT_NONLOCAL)
    out.update(user)
    return out


def build_param_block_cdbm(config):
    """Build the MOOSE parameter declarations injected at the top of the .i.

    Mirrors the elastic-app build_param_block() but emits the full CDBM key
    set plus the nonlocal/strain-rate-dependent-Cd parameters.
    """
    physics = config["physics"]
    execution = config["execution"]
    output = config.get("output", {})
    nonlocal_cfg = _resolve_nonlocal(config)
    nucl = _resolve_nucleation(config)

    rho = physics["density"]
    lam = physics["lambda_o"]
    mu = physics["shear_modulus_o"]

    params = {}

    # From physics (the keys actually consumed by the template's GlobalParams
    # and Materials blocks).
    physics_keys = [
        "q", "Dc", "mu_s", "mu_d",
        "density", "lambda_o", "shear_modulus_o",
        "xi_0", "xi_d", "xi_max", "xi_min",
        "chi", "C_g", "m1", "m2",
        "Cd_constant", "C_1", "C_2", "beta_width",
        "CdCb_multiplier", "CBH_constant",
    ]
    for k in physics_keys:
        params[k] = physics[k]
    # `len` = element_size (template references ${len}).
    params["len"] = config["domain"]["element_size"]

    # Wave speeds (derived).
    params["p_wave_speed"] = math.sqrt((lam + 2.0 * mu) / rho)
    params["shear_wave_speed"] = math.sqrt(mu / rho)

    # Nonlocal averaging + strain-rate-dependent Cd.
    params["nonlocal_averaging_length_scale"] = nonlocal_cfg["averaging_length_scale"]
    params["nonlocal_averaging_radius"] = nonlocal_cfg["averaging_radius"]
    params["use_strain_rate_dependent_Cd"] = (
        "true" if nonlocal_cfg["use_strain_rate_dependent_Cd"] else "false"
    )
    params["m_exponent"] = nonlocal_cfg["m_exponent"]
    params["strain_rate_hat"] = nonlocal_cfg["strain_rate_hat"]
    params["cd_hat"] = nonlocal_cfg["cd_hat"]

    # Nucleation (R-007 defaults applied above).
    params["peak_shear_stress"] = nucl["peak_shear_stress"]
    params["nucl_center_x"] = nucl["center"][0]
    params["nucl_center_y"] = nucl["center"][1]
    params["nucl_radius"] = nucl["radius"]

    # Execution.
    params["dt"] = execution["dt"]
    params["end_time"] = execution["end_time"]

    # Output intervals.
    exodus_interval = output.get("exodus_interval", 40)
    params["exodus_interval"] = exodus_interval
    params["csv_interval"] = output.get("csv_interval", exodus_interval)
    params["checkpoint_interval"] = output.get("checkpoint_interval", 200)
    params["checkpoint_num_files"] = output.get("checkpoint_num_files", 2)

    lines = ["#parameters (auto-generated from JSON config)", ""]
    for key in sorted(params.keys()):
        value = params[key]
        if isinstance(value, bool):
            lines.append(f"{key} = {'true' if value else 'false'}")
        elif isinstance(value, float):
            lines.append(f"{key} = {value:.10g}")
        else:
            lines.append(f"{key} = {value}")
    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Functions block builder (R-005: exactly four ConstantFunctions)
# ---------------------------------------------------------------------------

def build_functions_block_cdbm(config):
    """Build the [Functions] block.

    Per the plan (R-005), exactly FOUR ConstantFunctions are emitted:
    func_initial_stress_xx/xy/yy and func_zero. No friction-coefficient
    function (CDBM CZM uses a scalar from GlobalParams) and no nucleation
    patch function (the patch is a CZM material parameter).
    """
    ist = config.get("initial_stress_tensor", {})
    sxx = float(ist.get("stress_xx", -120e6))
    sxy = float(ist.get("stress_xy", 70e6))
    syy = float(ist.get("stress_yy", -120e6))

    lines = ["[Functions]"]
    lines.append("  [func_initial_stress_xx]")
    lines.append("    type = ConstantFunction")
    lines.append(f"    value = {sxx:.10g}")
    lines.append("  []")
    lines.append("  [func_initial_stress_xy]")
    lines.append("    type = ConstantFunction")
    lines.append(f"    value = {sxy:.10g}")
    lines.append("  []")
    lines.append("  [func_initial_stress_yy]")
    lines.append("    type = ConstantFunction")
    lines.append(f"    value = {syy:.10g}")
    lines.append("  []")
    lines.append("  [func_zero]")
    lines.append("    type = ConstantFunction")
    lines.append("    value = 0.0")
    lines.append("  []")
    lines.append("[]")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# VectorPostprocessors builder (one SideValueSampler per fault)
# ---------------------------------------------------------------------------

def build_vectorpostprocessors_cdbm(faults):
    """Build N SideValueSampler blocks, one per fault, on each fault interface."""
    variables = (
        "jump_strike_aux jump_normal_aux "
        "jump_strike_rate_aux jump_normal_rate_aux "
        "traction_strike_aux traction_normal_aux "
        "alpha_damagedvar_aux B_aux"
    )

    lines = ["[VectorPostprocessors]"]
    for fi, fault in enumerate(faults):
        label = fault["label"]
        sub_u = (2 * fi + 1) * 100
        sub_l = (2 * fi + 2) * 100
        boundary = f"Block{sub_u}_Block{sub_l}"
        dx = fault["end"][0] - fault["start"][0]
        dy = fault["end"][1] - fault["start"][1]
        sort_by = "x" if abs(dx) >= abs(dy) else "y"
        lines.append(f"  [{label}]")
        lines.append(f"    type = SideValueSampler")
        lines.append(f"    variable = '{variables}'")
        lines.append(f"    boundary = '{boundary}'")
        lines.append(f"    sort_by = {sort_by}")
        lines.append(f"  []")
    lines.append("[]")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Template renderer
# ---------------------------------------------------------------------------

def render_input_file_cdbm(template_path: str,
                           config: dict,
                           mesh_data: dict,
                           msh_path: str) -> str:
    """Read the Phase-2 template and substitute the marker tokens.

    Returns the rendered string. Does NOT write to disk.
    """
    with open(template_path, "r") as f:
        template = f.read()

    param_block = build_param_block_cdbm(config)
    functions_block = build_functions_block_cdbm(config)
    vpp_block = build_vectorpostprocessors_cdbm(config["faults"])

    replacements = {
        "__PARAM_BLOCK__": param_block,
        "__MESH_FILE__": msh_path,
        "__ELEMENT_IDS__": mesh_data["element_ids"],
        "__SUBDOMAIN_IDS__": mesh_data["subdomain_ids"],
        "__BLOCK_PAIRS__": mesh_data["block_pairs"],
        "__BOUNDARY_LIST__": mesh_data["boundary_list"],
        "__FUNCTIONS_BLOCK__": functions_block,
        "__VECTORPOSTPROCESSORS__": vpp_block,
    }

    result = template
    for marker, value in replacements.items():
        result = result.replace(marker, str(value))
    return result


# ---------------------------------------------------------------------------
# Pipeline driver
# ---------------------------------------------------------------------------

def run_pipeline(config_path, output_dir=None, dry_run=False):
    """Run the full multi-fault CDBM pipeline.

    Mirrors the elastic-app's six-step pipeline.
    """
    def _step(step_num, total, msg):
        print(f"[{step_num}/{total}] {msg}")

    with open(config_path, "r") as f:
        config = json.load(f)
    n_faults = len(config.get("faults", []))

    # Step 1: Validate (elastic-app + CDBM-specific).
    _step(1, 6, f"Validating config ({n_faults} faults)...")
    validate_config(config)
    validate_cdbm_physics(config)
    evaluate_fault_initial_stress(config)
    _step(1, 6, "Config validated OK")

    if output_dir is None:
        output_dir = os.path.join(SCRIPT_DIR, "2d_damagebreakage_multifault")
    os.makedirs(output_dir, exist_ok=True)

    template_path = os.path.join(TEMPLATES_DIR, "multifault_2d_cdbm.i.template")

    # Step 2 & 3: Mesh generation.
    msh_path = config.get("mesh_file")
    if msh_path is None:
        geo_path = os.path.join(output_dir, "output.geo")
        msh_path = os.path.join(output_dir, "output.msh")
        _step(2, 6, f"Generating .geo file: {geo_path}")
        geo_content = generate_geo(config, geo_path)
        _step(2, 6, "Generated .geo OK")
        if dry_run:
            print("=== Generated .geo ===")
            print(geo_content)
            print(f"# Would write .geo to: {geo_path}", file=sys.stderr)
            print(
                f"\n# Would run: gmsh -2 {geo_path} -o {msh_path} -format msh2",
                file=sys.stderr,
            )

            # Build remaining blocks for dry-run preview (no mesh required).
            param_block = build_param_block_cdbm(config)
            functions_block = build_functions_block_cdbm(config)
            vpp_block = build_vectorpostprocessors_cdbm(config["faults"])
            block_pairs = get_block_pairs_string(config["faults"])
            boundary_list = get_boundary_list_string(config["faults"])

            with open(template_path, "r") as f:
                template = f.read()
            replacements = {
                "__PARAM_BLOCK__": param_block,
                "__MESH_FILE__": msh_path,
                "__ELEMENT_IDS__": "<requires mesh>",
                "__SUBDOMAIN_IDS__": "<requires mesh>",
                "__BLOCK_PAIRS__": block_pairs,
                "__BOUNDARY_LIST__": boundary_list,
                "__FUNCTIONS_BLOCK__": functions_block,
                "__VECTORPOSTPROCESSORS__": vpp_block,
            }
            result = template
            for marker, value in replacements.items():
                result = result.replace(marker, str(value))
            print("\n=== Generated .i (dry-run, no mesh) ===")
            print(result)
            return None
        _step(3, 6, f"Running Gmsh: {geo_path} -> {msh_path}")
        run_gmsh(geo_path, msh_path)
        _step(3, 6, "Gmsh meshing OK")
    else:
        _step(2, 6, f"Using existing mesh: {msh_path}")
        _step(3, 6, "Skipped Gmsh (mesh_file provided)")

    # Step 4: Extract elements.
    _step(4, 6, "Extracting fault elements from mesh...")
    fault_elements, mesh_obj = extract_fault_elements(msh_path, config["faults"])
    for label, fe in fault_elements.items():
        n_upper = len(fe["upper"])
        n_lower = len(fe["lower"])
        print(f"       {label}: {n_upper} upper + {n_lower} lower elements")
    _step(4, 6, "Fault element extraction OK")

    # Step 5: Sort elements.
    _step(5, 6, "Sorting fault elements by subdomain...")
    sort_fault_elements(mesh_obj, config["faults"], fault_elements)
    _step(5, 6, "Fault element sorting OK")

    # Step 6: Render .i file.
    _step(6, 6, "Rendering MOOSE input file...")
    mesh_data = build_mesh_data(config, fault_elements)

    rel_msh = os.path.relpath(msh_path, output_dir)
    rendered = render_input_file_cdbm(template_path, config, mesh_data, rel_msh)

    output_i_path = os.path.join(output_dir, "multifault_2d_cdbm.i")
    if dry_run:
        print("\n=== Generated .i ===")
        print(rendered)
        print(f"\n# Would write to: {output_i_path}", file=sys.stderr)
    else:
        with open(output_i_path, "w") as f:
            f.write(rendered)
    _step(6, 6, f"Generated: {output_i_path}")
    print(f"\nPipeline complete: {n_faults} faults -> {output_i_path}")
    return output_i_path, rendered


def generate(config_path: str,
             output_dir: Optional[str] = None,
             dry_run: bool = False) -> Tuple[str, str]:
    """Backend-friendly wrapper around run_pipeline.

    Returns (output_i_path, rendered_string).
    """
    result = run_pipeline(config_path, output_dir=output_dir, dry_run=dry_run)
    if result is None:
        return ("", "")
    return result


def main():
    parser = argparse.ArgumentParser(
        description="Automated Multi-Fault 2D Pipeline for CDBM"
    )
    parser.add_argument(
        "config",
        help="Path to JSON configuration file",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print output to stdout instead of writing files",
    )
    parser.add_argument(
        "--output-dir",
        help="Output directory (default: <script_dir>/2d_damagebreakage_multifault)",
    )
    args = parser.parse_args()
    run_pipeline(args.config, args.output_dir, args.dry_run)


if __name__ == "__main__":
    main()

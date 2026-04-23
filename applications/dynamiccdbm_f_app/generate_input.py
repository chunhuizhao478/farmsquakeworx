#!/usr/bin/env python3
"""
Generate MOOSE .i input files from JSON configuration for CDBM dynamic rupture.

Usage:
    python generate_input.py config.json [--output-dir DIR]
    python generate_input.py --list-params --preset uniform_stress

The script reads a user JSON config that specifies a preset (which sets defaults)
and optionally overrides parameters.  It then processes .i.template files,
evaluating conditional blocks and substituting MOOSE ${variable} declarations.

Presets:
    uniform_stress  - constant stress field, no static solve (formerly v1)
    linear_stress   - depth-dependent stress via gravity, requires static solve (formerly case1/case2)
    depth_dependent - depth-dependent stress + seismic properties (formerly case3)
"""

import argparse
import copy
import json
import math
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULTS_PATH = os.path.join(SCRIPT_DIR, "config", "defaults.json")
TEMPLATES_DIR = os.path.join(SCRIPT_DIR, "templates")

VALID_PRESETS = ["uniform_stress", "linear_stress", "depth_dependent"]


# ---------------------------------------------------------------------------
#  Config loading and merging
# ---------------------------------------------------------------------------

def load_defaults(defaults_path=None):
    path = defaults_path or DEFAULTS_PATH
    with open(path, "r") as f:
        return json.load(f)


def deep_merge(base, overrides):
    """Recursively merge *overrides* into *base*.  Returns a new dict."""
    result = copy.deepcopy(base)
    for key, value in overrides.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def build_params(user_config, defaults=None):
    """Three-layer merge:  common -> preset -> user overrides."""
    if defaults is None:
        defaults = load_defaults()

    preset_name = user_config.get("preset")
    if preset_name not in defaults["presets"]:
        raise ValueError(
            f"Unknown preset '{preset_name}'. Valid: {', '.join(defaults['presets'].keys())}"
        )

    # Layer 1: common
    params = copy.deepcopy(defaults["common"])

    # Layer 2: preset
    preset = defaults["presets"][preset_name]
    params = deep_merge(params, preset)

    # Layer 3: user overrides
    overrides = user_config.get("overrides", {})
    params = deep_merge(params, overrides)

    # Stash metadata
    params["_preset_name"] = preset_name
    if "output_dir" in user_config:
        params["_output_dir"] = user_config["output_dir"]

    return params


# ---------------------------------------------------------------------------
#  Validation
# ---------------------------------------------------------------------------

def validate_params(params):
    errors = []

    def _positive(cat, key):
        if cat in params and key in params[cat]:
            if params[cat][key] <= 0:
                errors.append(f"{cat}.{key} must be positive, got {params[cat][key]}")

    _positive("material", "density")
    _positive("material", "lambda_o")
    _positive("material", "shear_modulus_o")
    _positive("execution", "dt")
    _positive("execution", "end_time")
    _positive("slip_weakening", "Dc")
    _positive("nucleation", "r_crit")
    _positive("nucleation", "Vs")

    if errors:
        raise ValueError("Validation failed:\n  " + "\n  ".join(errors))


# ---------------------------------------------------------------------------
#  Flattening: nested dict -> flat key/value for MOOSE variable declarations
# ---------------------------------------------------------------------------

def flatten_params(params):
    """Flatten nested param dict to single-level dict.

    Skips internal keys (starting with _) and non-parameter dicts.
    """
    skip_keys = {"template", "static_template", "_preset_name", "_output_dir",
                 "_description", "stress_profile", "seismic_properties"}
    flat = {}
    for key, value in params.items():
        if key.startswith("_") or key in skip_keys:
            continue
        if isinstance(value, dict):
            for sub_key, sub_value in value.items():
                if sub_key.startswith("_"):
                    continue
                if isinstance(sub_value, (int, float, bool, str)):
                    flat[sub_key] = sub_value
            continue
        if isinstance(value, (int, float, bool, str)):
            flat[key] = value
    return flat


def format_value(value):
    """Format a Python value for MOOSE .i file variable declaration."""
    if isinstance(value, bool):
        return "true" if value else "false"
    elif isinstance(value, float):
        if value != 0 and (abs(value) >= 1e7 or abs(value) < 1e-3):
            return f"{value:.10g}"
        return f"{value:.10g}"
    elif isinstance(value, int):
        return str(value)
    return str(value)


def compute_derived_params(flat):
    """Add derived parameters that MOOSE needs (e.g. background strain from Hooke's law)."""
    # For uniform stress preset: compute background strains
    if "stress_xx" in flat:
        lam = flat["lambda_o"]
        mu = flat["shear_modulus_o"]
        sxx = flat["stress_xx"]
        syy = flat["stress_yy"]
        szz = flat["stress_zz"]
        sxy = flat["stress_xy"]
        sxz = flat["stress_xz"]
        syz = flat["stress_yz"]
        mean = sxx + syy + szz
        f1 = 1.0 / (2.0 * mu)
        f2 = lam / (2.0 * mu * (3.0 * lam + 2.0 * mu))
        flat["background_strain_xx"] = f1 * sxx - f2 * mean
        flat["background_strain_yy"] = f1 * syy - f2 * mean
        flat["background_strain_zz"] = f1 * szz - f2 * mean
        flat["background_strain_xy"] = f1 * sxy
        flat["background_strain_xz"] = f1 * sxz
        flat["background_strain_yz"] = f1 * syz

    # bottom_nodes_coord is always needed
    flat.setdefault("bottom_nodes_coord",
                    "' -60000 -60000 -60000; 60000 -60000 -60000; "
                    "60000 60000 -60000; -60000 60000 -60000'")

    return flat


def generate_param_block(flat):
    """Generate MOOSE variable declaration lines."""
    lines = ["#parameters (auto-generated from JSON config)", ""]
    for key in sorted(flat.keys()):
        if key.startswith("_"):
            continue
        val = flat[key]
        formatted = format_value(val)
        lines.append(f"{key} = {formatted}")
    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
#  Conditional template processing
# ---------------------------------------------------------------------------

def compute_features(params):
    """Determine which conditional features are active."""
    stress_profile = params.get("stress_profile", "uniform")
    seismic = params.get("seismic_properties", "constant")
    nonlocal_cfg = params.get("nonlocal", {})
    cohesion_cfg = params.get("cohesion", {})
    damage_cfg = params.get("initial_damage", {})
    cdb_cfg = params.get("cdb_model", {})
    tapering_cfg = params.get("tapering", {})

    features = {}
    features["STATIC_SOLVE"] = (stress_profile == "linear_depth")
    features["UNIFORM_STRESS"] = (stress_profile == "uniform")
    features["NONLOCAL"] = nonlocal_cfg.get("enabled", False)
    features["NOT_NONLOCAL"] = not features["NONLOCAL"]
    features["DEPTH_DEPENDENT"] = (seismic == "depth_dependent")
    features["NOT_DEPTH_DEPENDENT"] = not features["DEPTH_DEPENDENT"]
    features["STRAIN_RATE_CD"] = cdb_cfg.get("use_strain_rate_dependent_Cd", False)
    features["ZERO_CD_BELOW"] = cdb_cfg.get("zero_Cd_below_threshold", False)
    features["COHESION"] = cohesion_cfg.get("enabled", False)
    features["NOT_COHESION"] = not features["COHESION"]
    features["INITIAL_DAMAGE"] = damage_cfg.get("enabled", False)
    features["NOT_INITIAL_DAMAGE"] = not features["INITIAL_DAMAGE"]
    features["FLUID_PRESSURE_DEPTH"] = (stress_profile == "linear_depth")
    features["FLUID_PRESSURE_ZERO"] = (stress_profile == "uniform")

    return features


def process_conditionals(text, features):
    """Process #{IF FEATURE} ... #{ENDIF FEATURE} blocks in template text."""
    lines = text.split("\n")
    result = []
    skip_stack = []  # stack of booleans: True = currently skipping

    for line in lines:
        stripped = line.strip()

        if stripped.startswith("#{IF "):
            feature = stripped[len("#{IF "):-1] if stripped.endswith("}") else stripped[len("#{IF "):]
            feature = feature.strip().rstrip("}")
            active = features.get(feature, False)
            skip_stack.append(not active)
            continue

        if stripped.startswith("#{ENDIF "):
            if skip_stack:
                skip_stack.pop()
            continue

        if skip_stack and any(skip_stack):
            continue

        result.append(line)

    return "\n".join(result)


# ---------------------------------------------------------------------------
#  Template rendering
# ---------------------------------------------------------------------------

def render_template(template_path, param_block, features):
    """Read template, process conditionals, insert param block."""
    with open(template_path, "r") as f:
        content = f.read()

    # Process conditionals
    content = process_conditionals(content, features)

    # Insert param block at #PARAM_BLOCK marker
    content = content.replace("#PARAM_BLOCK", param_block)

    return content


def add_fluid_pressure_type(flat, params):
    """Set the fluid pressure function type based on seismic properties."""
    seismic = params.get("seismic_properties", "constant")
    if seismic == "depth_dependent":
        flat["fluid_pressure_function_type"] = "InitialStressStrainTPV26VaryingDensity"
    else:
        flat["fluid_pressure_function_type"] = "InitialStressStrainTPV26"


def add_initial_damage_keys(flat, params):
    """Prefix initial_damage keys for template substitution."""
    dmg = params.get("initial_damage", {})
    if dmg.get("enabled", False):
        for key in ("sigma", "peak_val", "fault_strike_len", "fault_dip_len", "fault_center"):
            if key in dmg:
                flat[f"initial_damage_{key}"] = dmg[key]


# ---------------------------------------------------------------------------
#  Main pipeline
# ---------------------------------------------------------------------------

def generate(config_path, output_dir=None, defaults_path=None):
    """Main entry point: load config, merge, validate, render templates."""
    with open(config_path, "r") as f:
        user_config = json.load(f)

    params = build_params(user_config, load_defaults(defaults_path))
    validate_params(params)

    features = compute_features(params)
    flat = flatten_params(params)
    compute_derived_params(flat)
    add_fluid_pressure_type(flat, params)
    add_initial_damage_keys(flat, params)

    # Store preset name for template header
    flat["_preset_name"] = params["_preset_name"]

    param_block = generate_param_block(flat)

    # Determine output directory
    if output_dir is None:
        output_dir = params.get("_output_dir", os.path.join(SCRIPT_DIR, "generated"))
    os.makedirs(output_dir, exist_ok=True)

    generated_files = []

    # --- Static solve (if needed) ---
    if features["STATIC_SOLVE"]:
        static_dir = os.path.join(output_dir, "static_solve")
        os.makedirs(static_dir, exist_ok=True)
        static_template = os.path.join(TEMPLATES_DIR,
                                       params.get("static_template", "static_solve.i.template"))
        static_content = render_template(static_template, param_block, features)
        static_path = os.path.join(static_dir, "static_solve.i")
        with open(static_path, "w") as f:
            f.write(static_content)
        generated_files.append(static_path)
        print(f"  Static solve: {static_path}")

    # --- Dynamic solve ---
    dynamic_dir = os.path.join(output_dir, "dynamic_solve")
    os.makedirs(dynamic_dir, exist_ok=True)
    dynamic_template = os.path.join(TEMPLATES_DIR,
                                    params.get("template", "dynamic_solve.i.template"))
    dynamic_content = render_template(dynamic_template, param_block, features)
    dynamic_path = os.path.join(dynamic_dir, "dynamic_solve.i")
    with open(dynamic_path, "w") as f:
        f.write(dynamic_content)
    generated_files.append(dynamic_path)
    print(f"  Dynamic solve: {dynamic_path}")

    return generated_files


def list_params(preset_name, defaults_path=None):
    """Print all parameters for a given preset."""
    defaults = load_defaults(defaults_path)
    if preset_name not in defaults["presets"]:
        print(f"Unknown preset: {preset_name}", file=sys.stderr)
        sys.exit(1)

    params = copy.deepcopy(defaults["common"])
    params = deep_merge(params, defaults["presets"][preset_name])

    def _print_section(name, d, indent=2):
        print(f"\n{'=' * 60}")
        print(f"  {name}")
        print(f"{'=' * 60}")
        for k, v in sorted(d.items()):
            if k.startswith("_"):
                continue
            if isinstance(v, dict):
                print(f"  [{k}]")
                for sk, sv in sorted(v.items()):
                    if not sk.startswith("_"):
                        print(f"    {sk} = {sv}")
            else:
                print(f"  {k} = {v}")

    _print_section(f"Preset: {preset_name}", params)


# ---------------------------------------------------------------------------
#  CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Generate MOOSE input files for CDBM dynamic rupture simulations."
    )
    parser.add_argument("config", nargs="?", help="Path to user JSON config file")
    parser.add_argument("--output-dir", help="Override output directory")
    parser.add_argument("--list-params", action="store_true",
                        help="List all parameters for a preset")
    parser.add_argument("--preset", help="Preset name (for --list-params)")
    parser.add_argument("--defaults", help="Path to defaults.json (default: config/defaults.json)")

    args = parser.parse_args()

    if args.list_params:
        preset = args.preset
        if not preset:
            print("Error: --preset required with --list-params", file=sys.stderr)
            sys.exit(1)
        list_params(preset, args.defaults)
        return

    if not args.config:
        parser.print_help()
        sys.exit(1)

    print(f"Generating input files from: {args.config}")
    files = generate(args.config, args.output_dir, args.defaults)
    print(f"\nGenerated {len(files)} file(s).")


if __name__ == "__main__":
    main()

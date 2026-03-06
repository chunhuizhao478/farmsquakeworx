#!/usr/bin/env python3
"""
Generate MOOSE .i input files from JSON configuration for dynamic elastic benchmarks.

Usage:
    python generate_input.py config.json [--output-dir DIR]
    python generate_input.py --list-params --benchmark tpv205_2d

The script reads a user JSON config that specifies a benchmark type (which sets
defaults) and optionally overrides parameters. It then substitutes values into
.i template files using MOOSE's native ${variable} syntax.
"""

import argparse
import copy
import json
import os
import subprocess
import sys


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULTS_PATH = os.path.join(SCRIPT_DIR, "config", "defaults.json")
TEMPLATES_DIR = os.path.join(SCRIPT_DIR, "templates")

VALID_BENCHMARKS = ["tpv14_2d", "tpv205_2d", "tpv205_3d", "tpv26_3d"]


def load_defaults(defaults_path=None):
    """Load benchmark preset defaults from defaults.json."""
    path = defaults_path or DEFAULTS_PATH
    with open(path, "r") as f:
        return json.load(f)


def resolve_preset_key(benchmark, mesh_variant=None):
    """Map (benchmark, mesh_variant) to a defaults.json key.

    Examples:
        ("tpv14_2d", None)    -> "tpv14_2d_tria"  (default)
        ("tpv14_2d", "tria")  -> "tpv14_2d_tria"
        ("tpv205_2d", "tria") -> "tpv205_2d_tria"
        ("tpv205_2d", None)   -> "tpv205_2d_tria"  (default)
        ("tpv205_3d", None)   -> "tpv205_3d"
        ("tpv26_3d", None)    -> "tpv26_3d"
    """
    if benchmark == "tpv14_2d":
        variant = mesh_variant or "tria"
        if variant not in ("tria",):
            raise ValueError(
                f"Invalid mesh_variant '{variant}' for tpv14_2d. "
                "Must be 'tria'."
            )
        return f"tpv14_2d_{variant}"
    elif benchmark == "tpv205_2d":
        variant = mesh_variant or "tria"
        if variant not in ("tria", "quad"):
            raise ValueError(
                f"Invalid mesh_variant '{variant}' for tpv205_2d. "
                "Must be 'tria' or 'quad'."
            )
        return f"tpv205_2d_{variant}"
    elif benchmark in ("tpv205_3d", "tpv26_3d"):
        if mesh_variant is not None:
            print(
                f"Warning: mesh_variant '{mesh_variant}' ignored for {benchmark}",
                file=sys.stderr,
            )
        return benchmark
    else:
        raise ValueError(
            f"Unknown benchmark '{benchmark}'. "
            f"Valid options: {', '.join(VALID_BENCHMARKS)}"
        )


def deep_merge(base, overrides):
    """Recursively merge overrides into base dict. Returns a new dict."""
    result = copy.deepcopy(base)
    for key, value in overrides.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def validate_params(params):
    """Validate parameter ranges. Raises ValueError on invalid values."""
    errors = []

    def _check_positive(category, key):
        if category in params and key in params[category]:
            val = params[category][key]
            if val <= 0:
                errors.append(f"{category}.{key} must be positive, got {val}")

    def _check_range(category, key, lo, hi):
        if category in params and key in params[category]:
            val = params[category][key]
            if not (lo <= val <= hi):
                errors.append(
                    f"{category}.{key} must be in [{lo}, {hi}], got {val}"
                )

    def _check_non_negative(category, key):
        if category in params and key in params[category]:
            val = params[category][key]
            if val < 0:
                errors.append(f"{category}.{key} must be non-negative, got {val}")

    # slip_weakening
    _check_range("slip_weakening", "q", 0, 1)
    _check_positive("slip_weakening", "Dc")
    _check_positive("slip_weakening", "len")

    # material
    _check_positive("material", "density")
    _check_positive("material", "lambda_o")
    _check_positive("material", "shear_modulus_o")

    # execution
    _check_positive("execution", "dt")
    _check_positive("execution", "end_time")

    # output
    for key in ("exodus_interval", "csv_interval", "checkpoint_interval"):
        if "output" in params and key in params["output"]:
            val = params["output"][key]
            if not isinstance(val, int) or val <= 0:
                errors.append(f"output.{key} must be a positive integer, got {val}")

    # boundary_conditions
    _check_positive("boundary_conditions", "p_wave_speed")
    _check_positive("boundary_conditions", "shear_wave_speed")

    # initial_stress
    _check_positive("initial_stress", "gravity")

    # cohesion
    _check_non_negative("cohesion", "cohesion_depth")

    # nucleation
    _check_positive("nucleation", "r_crit")
    _check_positive("nucleation", "Vs")

    # cdb_model
    _check_non_negative("cdb_model", "Cd_constant")

    if errors:
        raise ValueError("Parameter validation failed:\n  " + "\n  ".join(errors))


def flatten_params(params):
    """Flatten nested parameter dict to single-level dict for template substitution.

    Skips non-parameter top-level keys (template, output_dir, output_filename).
    For nested dicts, uses the leaf key directly (no prefixing).
    """
    skip_keys = {"template", "output_dir", "output_filename"}
    flat = {}
    for key, value in params.items():
        if key in skip_keys:
            continue
        if isinstance(value, dict):
            for sub_key, sub_value in value.items():
                flat[sub_key] = sub_value
        else:
            flat[key] = value
    return flat


def format_value(value):
    """Format a Python value for MOOSE .i file variable declaration."""
    if isinstance(value, bool):
        return "true" if value else "false"
    elif isinstance(value, float):
        # Use scientific notation for very large or very small numbers
        if value != 0 and (abs(value) >= 1e7 or abs(value) < 1e-3):
            return f"{value:.10g}"
        else:
            return f"{value:.10g}"
    elif isinstance(value, int):
        return str(value)
    else:
        return str(value)


def generate_param_block(flat_params):
    """Generate MOOSE variable declaration lines from flat parameter dict."""
    lines = ["#parameters (auto-generated from JSON config)", ""]
    for key, value in sorted(flat_params.items()):
        formatted = format_value(value)
        lines.append(f"{key} = {formatted}")
    lines.append("")
    return "\n".join(lines)


def render_template(template_path, param_block):
    """Replace __PARAM_BLOCK__ marker in template with generated parameter block."""
    with open(template_path, "r") as f:
        content = f.read()

    if "__PARAM_BLOCK__" not in content:
        raise ValueError(
            f"Template {template_path} does not contain __PARAM_BLOCK__ marker"
        )

    return content.replace("__PARAM_BLOCK__", param_block)


def generate_mesh_if_needed(mesh_file, output_dir):
    """Generate .msh from .geo via Gmsh if the .msh file does not exist.

    The .geo file is located by replacing the .msh extension with .geo.
    Gmsh dimension (-2 or -3) is auto-detected from the .geo content.

    Args:
        mesh_file: The mesh_file value from params (may be relative path).
        output_dir: The output directory for resolving relative paths.

    Returns:
        The (possibly unchanged) mesh_file path.

    Raises:
        FileNotFoundError: If neither .msh nor .geo exists.
        RuntimeError: If Gmsh fails.
    """
    # Resolve mesh path relative to output_dir (matches how MOOSE will find it)
    if os.path.isabs(mesh_file):
        msh_path = mesh_file
    else:
        msh_path = os.path.normpath(os.path.join(output_dir, mesh_file))

    if os.path.exists(msh_path):
        return mesh_file

    # Derive .geo path from .msh path
    geo_path = os.path.splitext(msh_path)[0] + ".geo"
    if not os.path.exists(geo_path):
        raise FileNotFoundError(
            f"Mesh file '{msh_path}' not found and no .geo file at '{geo_path}' "
            f"to generate it from. Please provide the .geo file or a pre-built .msh."
        )

    # Auto-detect dimension from .geo content
    with open(geo_path, "r") as f:
        geo_content = f.read()
    is_3d = any(
        kw in geo_content
        for kw in ("Extrude", "Volume", "Physical Volume")
    )
    dim = "-3" if is_3d else "-2"

    print(f"Mesh file '{msh_path}' not found. Generating from '{geo_path}' (dim={dim})...")
    result = subprocess.run(
        ["gmsh", dim, geo_path, "-o", msh_path, "-format", "msh2"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Gmsh failed with return code {result.returncode}.\n"
            f"stdout: {result.stdout}\n"
            f"stderr: {result.stderr}"
        )
    print(f"Generated mesh: {msh_path}")
    return mesh_file


def generate(config_path, output_dir_override=None, defaults_path=None, dry_run=False):
    """Main generation logic. Returns (output_path, rendered_content)."""
    # Load user config
    with open(config_path, "r") as f:
        user_config = json.load(f)

    # Validate required fields
    if "benchmark" not in user_config:
        raise ValueError("Config must specify 'benchmark' field")

    benchmark = user_config["benchmark"]
    mesh_variant = user_config.get("mesh_variant")

    # Load defaults and resolve preset
    defaults = load_defaults(defaults_path)
    preset_key = resolve_preset_key(benchmark, mesh_variant)

    benchmarks = defaults.get("benchmarks", defaults)
    if preset_key not in benchmarks:
        raise ValueError(
            f"Preset '{preset_key}' not found in defaults.json. "
            f"Available: {', '.join(benchmarks.keys())}"
        )

    # Merge: common defaults -> benchmark defaults -> user overrides
    common = defaults.get("common", {})
    params = deep_merge(common, benchmarks[preset_key])
    if "overrides" in user_config:
        params = deep_merge(params, user_config["overrides"])

    # Apply top-level output overrides
    if "output_dir" in user_config:
        params["output_dir"] = user_config["output_dir"]
    if "output_filename" in user_config:
        params["output_filename"] = user_config["output_filename"]

    # Validate
    validate_params(params)

    # Determine template and output paths
    template_name = params["template"]
    template_path = os.path.join(TEMPLATES_DIR, template_name)
    if not os.path.exists(template_path):
        raise FileNotFoundError(f"Template not found: {template_path}")

    output_dir = output_dir_override or params.get("output_dir", ".")
    output_filename = params.get("output_filename", template_name.replace(".template", ""))

    # Make output_dir relative to SCRIPT_DIR
    if not os.path.isabs(output_dir):
        output_dir = os.path.join(SCRIPT_DIR, output_dir)

    output_path = os.path.join(output_dir, output_filename)

    # Generate mesh from .geo if .msh is missing (skip for quad meshes which use GeneratedMesh)
    mesh_params = params.get("mesh", {})
    if "mesh_file" in mesh_params and not dry_run:
        os.makedirs(output_dir, exist_ok=True)
        generate_mesh_if_needed(mesh_params["mesh_file"], output_dir)

    # Flatten and render
    flat_params = flatten_params(params)
    param_block = generate_param_block(flat_params)
    rendered = render_template(template_path, param_block)

    return output_path, rendered


def list_params(benchmark, mesh_variant=None, defaults_path=None):
    """Print all parameters and their defaults for a given benchmark."""
    defaults = load_defaults(defaults_path)
    preset_key = resolve_preset_key(benchmark, mesh_variant)

    benchmarks = defaults.get("benchmarks", defaults)
    if preset_key not in benchmarks:
        raise ValueError(f"Preset '{preset_key}' not found in defaults.json")

    common = defaults.get("common", {})
    params = deep_merge(common, benchmarks[preset_key])
    print(f"Parameters for {preset_key}:")
    print(f"  Template: {params.get('template', 'N/A')}")
    print(f"  Output dir: {params.get('output_dir', 'N/A')}")
    print(f"  Output filename: {params.get('output_filename', 'N/A')}")
    print()

    skip_keys = {"template", "output_dir", "output_filename"}
    for category, values in sorted(params.items()):
        if category in skip_keys:
            continue
        if isinstance(values, dict):
            print(f"  [{category}]")
            for key, val in sorted(values.items()):
                print(f"    {key} = {format_value(val)}")
            print()


def main():
    parser = argparse.ArgumentParser(
        description="Generate MOOSE .i input files from JSON configuration"
    )
    parser.add_argument(
        "config",
        nargs="?",
        help="Path to user JSON configuration file",
    )
    parser.add_argument(
        "--output-dir",
        help="Override output directory",
    )
    parser.add_argument(
        "--list-params",
        action="store_true",
        help="List all parameters and defaults for a benchmark",
    )
    parser.add_argument(
        "--benchmark",
        help="Benchmark name (for --list-params)",
    )
    parser.add_argument(
        "--mesh-variant",
        help="Mesh variant (for --list-params with tpv205_2d)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print output to stdout instead of writing to file",
    )

    args = parser.parse_args()

    if args.list_params:
        if not args.benchmark:
            parser.error("--list-params requires --benchmark")
        list_params(args.benchmark, args.mesh_variant)
        return

    if not args.config:
        parser.error("config file is required (unless using --list-params)")

    output_path, rendered = generate(args.config, args.output_dir, dry_run=args.dry_run)

    if args.dry_run:
        print(rendered)
        print(f"\n# Would write to: {output_path}", file=sys.stderr)
    else:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, "w") as f:
            f.write(rendered)
        print(f"Generated: {output_path}")


if __name__ == "__main__":
    main()

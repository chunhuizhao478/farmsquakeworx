# QuakeWorx MOOSE-FARMS DynamicElastic Application

Created By Chunhui Zhao, Feb 24th, 2026

## Overview

This app uses JSON to drive jobs. It's a **two-stage pipeline**:
JSON config → MOOSE `.i` file → run with MOOSE.

You don't write the MOOSE `.i` file by hand. You write a small JSON config that
says *"I want benchmark X with these tweaks"*, and `generate_input.py` produces
the full `.i` file by substituting your values into a template.

### Three layers of config

1. **`config/defaults.json`** — central registry of all benchmarks
   (`tpv14_2d`, `tpv205_2d_tria`, `tpv205_2d_quad`, `tpv205_3d`, `tpv26_3d`).
   Holds the canonical default values for each, plus a `common` block shared
   by all.
2. **`config/example_config_*.json`** — user-facing config. Picks a benchmark
   and optionally overrides parameters.
3. **`templates/*.i.template`** — MOOSE `.i` files with `${variable}`
   placeholders and a `__PARAM_BLOCK__` marker at the top.

### User JSON shape

```json
{
    "benchmark": "tpv205_2d",
    "mesh_variant": "tria",
    "overrides": {
        "execution": { "dt": 0.01, "end_time": 12 },
        "slip_weakening": { "Dc": 0.4, "mu_s": 0.677 }
    }
}
```

Only `benchmark` is required. Everything in `overrides` is merged on top of
the defaults (deep-merge per category).

### What `generate_input.py` does

1. Load user JSON; require `benchmark` field.
2. Resolve `(benchmark, mesh_variant)` → preset key in `defaults.json`
   (`resolve_preset_key`).
3. Deep-merge: `common` → benchmark preset → user `overrides`.
4. Validate ranges (`validate_params`) — `q ∈ [0,1]`, `Dc > 0`, positive
   timesteps, etc.
5. Auto-generate `.msh` from `.geo` via Gmsh if missing
   (`generate_mesh_if_needed`).
6. Flatten the nested dict to a flat `key = value` block, format MOOSE-style.
7. Substitute that block into the template's `__PARAM_BLOCK__` marker, then
   write the `.i` file.

### Why this design

- Defaults are versioned in one place (`defaults.json`); users only write the
  small diff they care about.
- The `${var}` placeholders are MOOSE-native — the rendered `.i` is still
  valid MOOSE syntax that you can hand-edit if needed.
- It's web-backend friendly: `generate(user_config_path)` returns
  `(output_path, rendered_string)`, so a server can return the `.i` content
  without touching disk.

## Single-fault benchmarks (generate_input.py)

```bash
# Generate the .i input file (writes to output_dir from defaults)
python generate_input.py config/example_config_tpv205_2d.json

# Preview without writing (print to stdout)
python generate_input.py config/example_config_tpv205_2d.json --dry-run

# Override output directory
python generate_input.py config/example_config_tpv205_2d.json --output-dir /tmp/my_run

# See all default parameters for a benchmark
python generate_input.py --list-params --benchmark tpv205_2d

# Then run MOOSE on the produced .i
cd 2d_slipweakening_tpv205
mpirun -n N /path/to/farms-opt -i tpv2052D_tria.i
```

For the website backend, the call would be something like:

```python
from generate_input import generate

# user_config_path = path to the JSON file the user submitted
output_path, rendered_content = generate(user_config_path)

# rendered_content is the complete MOOSE .i file as a string
# output_path is where it would be written
```

## Multi-fault pipeline (generate_multifault.py)

Generates a complete MOOSE .i input file for multi-fault 2D dynamic rupture
simulations from a single JSON config. Adds an upstream step over the
single-fault pipeline: it also generates the `.geo`, runs Gmsh, and extracts
boundary IDs before rendering the `.i`.

```bash
# Full pipeline (generates .geo, runs Gmsh, renders .i)
python generate_multifault.py config/example_config_multifault.json

# Preview without mesh generation (dry-run)
python generate_multifault.py config/example_config_multifault.json --dry-run

# Override output directory
python generate_multifault.py config/example_config_multifault.json --output-dir /tmp/my_run
```

Key design choices (following `farms_benchmark/tpv142D_tria.i` reference):

- CZM material: `SlipWeakeningFrictionczm2dParametricStudy` (declares
  `total_shear_traction`)
- AuxKernels: `FarmsMaterialRealAux` for local (fault-aligned) quantities
  (`local_shear_jump`, `local_normal_jump`, `local_shear_traction`, etc.)
- VectorPostprocessors: `SideValueSampler` (1 block per fault, boundary-based,
  sorted spatially)
- Outputs: Exodus + CSV with configurable intervals

## Unit tests

- `tests/test_generate_input.py` — tests covering all functions plus
  integration tests
- `tests/test_generate_multifault.py` — tests for multi-fault pipeline
- Run with: `python -m unittest discover -s tests -v`

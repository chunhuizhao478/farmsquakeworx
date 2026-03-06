# Plan: JSON Configuration System for dynamicelastic_app

## Context

The `dynamicelastic_app` examples contain `.i` input files for three SCEC benchmarks (TPV205 2D, TPV205 3D, TPV26 3D) with many hardcoded parameters. The goal is to create a JSON config system where users specify a benchmark type (which sets defaults) and optionally override parameters. A Python script reads the JSON and substitutes values into `.i` template files.

**Scope**: Elastic cases only (`dynamicelastic_app`). CDBM damage-breakage app will be added later.

## File Layout

```
examples/dynamicelastic_app/
    generate_input.py                    # Python script (entry point)
    config/
        defaults.json                    # All benchmark preset defaults
    templates/
        tpv2052D_tria.i.template         # .i template with ${var} placeholders
        tpv2052D_quad.i.template
        tpv2053D_tet.i.template
        tpv263D_tet.i.template
    example_config_tpv205_2d.json        # Example user configs
    example_config_tpv205_3d.json
    example_config_tpv26_3d.json
    2d_slipweakening_tpv205/             # (existing) output directories
    3d_slipweakening_tpv205/
    3d_slipweakening_tpv26/
    mesh/                                # (existing) mesh files
```

## JSON Schema: User Config

A user creates a minimal JSON like:

```json
{
    "benchmark": "tpv205_2d",
    "mesh_variant": "tria",
    "overrides": {
        "slip_weakening": { "Dc": 0.5 },
        "execution": { "end_time": 6.0 }
    }
}
```

Only `benchmark` is required. Everything else has defaults from the preset.

### Top-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `benchmark` | `"tpv205_2d"` / `"tpv205_3d"` / `"tpv26_3d"` | Yes | Selects preset |
| `mesh_variant` | string | No | `"tria"` (default) or `"quad"` for tpv205_2d only |
| `output_dir` | string | No | Output directory (defaults per benchmark) |
| `output_filename` | string | No | Output filename |
| `overrides` | object | No | Parameter overrides by category |

### Override Categories and Parameters

**`overrides.material`** — Elastic properties (all benchmarks):

| Parameter | Type | TPV205 2D | TPV205 3D | TPV26 3D | Description |
|-----------|------|-----------|-----------|----------|-------------|
| `density` | number | 2670 | 2670 | 2670 | kg/m^3 |
| `lambda_o` | number | 3.204e10 | 3.204e10 | 3.204e10 | First Lame constant (Pa) |
| `shear_modulus_o` | number | 3.204e10 | 3.204e10 | 3.204e10 | Shear modulus (Pa) |

**`overrides.slip_weakening`** — Friction law (all benchmarks):

| Parameter | Type | TPV205 2D tria | TPV205 2D quad | TPV205 3D | TPV26 3D |
|-----------|------|----------------|----------------|-----------|----------|
| `q` | number | 0.2 | 0.1 | 0.1 | 0.4 |
| `Dc` | number | 0.4 | 0.4 | 0.4 | 0.3 |
| `T2_o` | number | 120e6 | 120e6 | 120e6 | — |
| `T3_o` | number | — | — | 0.0 | — |
| `mu_d` | number | 0.525 | 0.525 | 0.525 | 0.12 |
| `mu_s` | number | — | — | — | 0.18 |
| `len` | number | 200 | 200 | 100 | 100 |

**`overrides.mesh`** — Mesh configuration:

| Parameter | Type | Benchmarks | Default | Description |
|-----------|------|-----------|---------|-------------|
| `mesh_file` | string | tria/3D/tpv26 | per benchmark | Path to .msh file |
| `nx`, `ny` | integer | quad only | 400 | Element count |
| `xmin`, `xmax`, `ymin`, `ymax` | number | quad only | -40000/40000 | Domain bounds |
| `elem_size` | number | tpv26 only | 100 | Element size near fault |
| `xmin_fault`, `xmax_fault`, `zmin_fault` | number | tpv26 only | -20000/20000/-20000 | Fault extent |

**`overrides.boundary_conditions`** — Absorbing BCs (TPV205 2D only):

| Parameter | Default | Description |
|-----------|---------|-------------|
| `p_wave_speed` | 6000 | P-wave speed (m/s) |
| `shear_wave_speed` | 3464 | S-wave speed (m/s) |

**`overrides.initial_stress`** — Depth-dependent stress (TPV26 3D only):

| Parameter | Default | Description |
|-----------|---------|-------------|
| `fluid_density` | 1000 | kg/m^3 |
| `gravity` | 9.8 | m/s^2 |
| `bxx` | 0.926793 | Stress ratio for sigma_xx |
| `byy` | 1.073206 | Stress ratio for sigma_yy |
| `bxy` | -0.169029 | Stress ratio for sigma_xy |

**`overrides.cohesion`** — (TPV26 3D only):

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cohesion_depth` | 5000 | Depth threshold (m) |
| `cohesion_slope` | 0.00072 | Rate of decrease (MPa/m) |
| `cohesion_min` | 0.4 | Minimum value (MPa) |

**`overrides.nucleation`** — (TPV26 3D only):

| Parameter | Default | Description |
|-----------|---------|-------------|
| `nucl_center_x` | -5000 | Hypocenter x (m) |
| `nucl_center_y` | 0 | Hypocenter y (m) |
| `nucl_center_z` | -10000 | Hypocenter z (m) |
| `r_crit` | 4000 | Critical radius (m) |
| `Vs` | 3464 | Shear wave speed (m/s) |
| `t0` | 0.5 | Nucleation time (s) |

**`overrides.tapering`** — (TPV26 3D only):

| Parameter | Default | Description |
|-----------|---------|-------------|
| `use_tapering` | true | Enable tapering |
| `tapering_depth_A` | 15000 | Tapering start depth (m) |
| `tapering_depth_B` | 20000 | Tapering end depth (m) |

**`overrides.cdb_model`** — CDB parameters (TPV26 3D only, inactive for elastic: `Cd_constant=0`):

| Parameter | Default | Description |
|-----------|---------|-------------|
| `xi_0` | -1.1 | Onset of damage evolution |
| `xi_d` | -1.1 | Onset of breakage healing |
| `Cd_constant` | 0 | Damage coefficient (0=off) |
| `CdCb_multiplier` | 100 | Cd to Cb ratio |
| `CBH_constant` | 1e4 | Breakage healing |
| `C_1` | 300 | Damage healing 1 |
| `C_2` | 0.05 | Damage healing 2 |
| `beta_width` | 0.05 | Transition width |
| `C_g` | 1e-10 | Granular compliance |
| `m1` | 10 | Power law index |
| `m2` | 1 | Power law index |
| `chi` | 0.8 | Energy ratio |

**`overrides.execution`** — Time stepping (all benchmarks):

| Parameter | TPV205 2D | TPV205 3D | TPV26 3D | Description |
|-----------|-----------|-----------|----------|-------------|
| `dt` | 0.01 | 0.0025 | 0.0025 | Time step (s) |
| `end_time` | 12 | 12 | 12 | End time (s) |

**`overrides.output`** — Output intervals:

| Parameter | TPV205 2D | TPV205 3D | TPV26 3D | Description |
|-----------|-----------|-----------|----------|-------------|
| `exodus_interval` | 10 | 10 | 40 | Exodus frequency |
| `csv_interval` | — | 20 | 40 | CSV frequency |
| `checkpoint_interval` | — | 160 | 40 | Checkpoint frequency |
| `checkpoint_num_files` | — | 2 | 2 | Rolling checkpoints |

## Template Strategy

Use MOOSE's native `${variable}` substitution. Each template has a `__PARAM_BLOCK__` marker at the top. The Python script generates variable declarations and injects them there. The template body uses `${var}` references — no regex needed in the body.

**TPV26** (`tpv263D_tet.i`): Already uses this pattern. Convert the existing variable block at the top to `__PARAM_BLOCK__`.

**TPV205 2D/3D**: Currently have hardcoded values. Convert to `${var}` references in GlobalParams, Materials, BCs, Executioner, and Outputs blocks.

## Python Script (`generate_input.py`)

Single-file script with these functions:

1. **`load_defaults()`** — Reads `config/defaults.json`
2. **`resolve_preset_key(benchmark, mesh_variant)`** — Maps `("tpv205_2d", "tria")` to `"tpv205_2d_tria"` key
3. **`deep_merge(base, overrides)`** — Recursively merges user overrides into preset defaults
4. **`validate_params(params)`** — Checks ranges (q in [0,1], dt > 0, etc.)
5. **`flatten_params(params)`** — Flattens nested dict to single-level for template substitution
6. **`generate_param_block(flat_params)`** — Generates MOOSE variable declaration lines
7. **`render_template(template_path, param_block)`** — Replaces `__PARAM_BLOCK__` in template
8. **CLI**: `python generate_input.py config.json [--output-dir DIR]`
9. **List mode**: `python generate_input.py --list-params --benchmark tpv205_2d`

## Implementation Steps

### Step 1: Create `config/defaults.json`
Contains 4 preset keys: `tpv205_2d_tria`, `tpv205_2d_quad`, `tpv205_3d`, `tpv26_3d`, each with all parameter categories and their default values.

### Step 2: Create template files (4 files)
- Copy each `.i` file to `templates/*.i.template`
- Add `__PARAM_BLOCK__` marker at line 1
- Replace hardcoded values with `${variable}` references
- For TPV26: remove existing variable block, keep only body with `${var}` refs

### Step 3: Create `generate_input.py`
Single Python script with the architecture described above.

### Step 4: Create example config JSONs (3 files)
- `example_config_tpv205_2d.json` — minimal, just benchmark selection
- `example_config_tpv205_3d.json` — minimal
- `example_config_tpv26_3d.json` — shows overriding a few TPV26 params

## Verification

1. `python generate_input.py example_config_tpv205_2d.json` — diff output against original `tpv2052D_tria.i`
2. `python generate_input.py example_config_tpv26_3d.json` — diff against original `tpv263D_tet.i`
3. Test with overrides: verify changed values appear, unchanged values stay at defaults
4. Run generated `.i` files with farmsquakeworx (once build environment is working): `conda activate moose && make -j4 && ./farmsquakeworx-opt -i <generated.i>`

## Key Files

- `examples/dynamicelastic_app/2d_slipweakening_tpv205/tpv2052D_tria.i` — source for tria template
- `examples/dynamicelastic_app/2d_slipweakening_tpv205/tpv2052D_quad.i` — source for quad template
- `examples/dynamicelastic_app/3d_slipweakening_tpv205/tpv2053D_tet.i` — source for 3D template
- `examples/dynamicelastic_app/3d_slipweakening_tpv26/tpv263D_tet.i` — source for TPV26 template (already parameterized)
- `pythonfiles/tpv2052D_prop_functions.py` — existing regex approach (replaced by new system)

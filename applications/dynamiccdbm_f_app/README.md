QuakeWorx MOOSE-FARMS DynamicCDBM_F Application
Created By Chunhui Zhao, Feb 24th, 2026

## Config-driven input generation

Generate MOOSE `.i` input files from JSON configs:

```bash
# Uniform stress (formerly v1)
python generate_input.py config/example_config_uniform_stress.json

# Linear depth-dependent stress (formerly case1/case2)
python generate_input.py config/example_config_linear_stress.json

# Depth-dependent seismic properties (formerly case3)
python generate_input.py config/example_config_depth_dependent.json

# Custom output directory
python generate_input.py config/my_config.json --output-dir /path/to/output

# List all parameters for a preset
python generate_input.py --list-params --preset linear_stress
```

### Presets

| Preset | Stress field | Seismic props | Static solve | Former case |
|--------|-------------|---------------|--------------|-------------|
| `uniform_stress` | Constant | Constant | No | v1 |
| `linear_stress` | Depth-dependent | Constant | Yes | case1/case2 |
| `depth_dependent` | Depth-dependent | Depth-dependent | Yes | case3 |

### Config structure

User configs use a 3-layer merge: `common defaults` -> `preset defaults` -> `user overrides`.

```json
{
    "preset": "linear_stress",
    "overrides": {
        "execution": { "end_time": 20 },
        "cdb_model": { "xi_0": -1.0 }
    }
}
```

See `config/example_config_reference.json` for all available fields.

## Multi-fault pipeline (generate_multifault.py)

Generates a complete MOOSE `.i` input for multi-fault 2D dynamic rupture
simulations with continuum-damage-breakage rheology, from a single JSON
config. Automates `.geo` generation, Gmsh meshing, element extraction,
fault sorting, and `.i` rendering.

```bash
# Full pipeline (generates .geo, runs Gmsh, renders .i)
python generate_multifault.py config/example_config_multifault_cdbm.json

# Preview without mesh generation (dry-run)
python generate_multifault.py config/example_config_multifault_cdbm.json --dry-run

# Override output directory
python generate_multifault.py config/example_config_multifault_cdbm.json \
    --output-dir /tmp/my_run
```

Output goes to `2d_damagebreakage_multifault/multifault_2d_cdbm.i` by
default. See `2d_damagebreakage_multifault/README.md` for the schema deltas
relative to the elastic-app multifault config and the global-nonlocal
trade-off.

Key design choices:
- CZM friction: `SlipWeakeningFrictionczm2dCDBM` (with stress-tensor rotation
  to fault-local coords; see
  `test/tests/materials/slip_weakening_czm_2d_cdbm_rotated/`).
- Bulk stress: `ComputeDamageBreakageStress3DSlipWeakening`
  (`use_nonlocal_eqstrain = true` with no `nonlocal_eqstrain_blocks` →
  applied on every block).
- Nonlocal averaging: ONE global `ElkRadialAverageUpdated` UO + ONE global
  `ElkNonlocalEqstrainUpdated` material (no per-fault partitioning).

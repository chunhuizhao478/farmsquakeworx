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

# Plan: Automated Multi-Fault 2D Pipeline (`generate_multifault.py`)

## Context

The current TPV14 workflow requires 5+ manual steps: edit `.geo` by hand, run Gmsh, run `meshio_run_tria.py`, run `process_coords.py` (twice, editing parameters), then manually copy-paste thousands of element IDs into the `.i` file. This plan automates the entire pipeline into a single script driven by a JSON config.

## User Input: JSON Config

```json
{
  "domain": {
    "xmin": -26000, "xmax": 24000,
    "ymin": -20000, "ymax": 20000,
    "element_size": 100
  },
  "faults": [
    {
      "label": "fault_1",
      "start": [-16000, 0.0],
      "end": [12000, 0.0]
    },
    {
      "label": "fault_2",
      "start": [0.0, 0.0],
      "end": [10392.3, -6000]
    }
  ],
  "initial_shear_stress": {
    "background": 70.0e6,
    "patches": [
      { "xmin": -9500, "xmax": -6500, "ymin": -6500, "ymax": 6500,
        "value": 81.6e6, "label": "nucleation" }
    ]
  },
  "physics": {
    "q": 0.1, "Dc": 0.4, "T2_o": 120e6,
    "mu_s": 0.677, "mu_d": 0.525, "len": 100,
    "density": 2670, "lambda_o": 3.204e10,
    "shear_modulus_o": 3.204e10
  },
  "execution": { "dt": 0.0025, "end_time": 12 },
  "boundary_conditions": { "p_wave_speed": 6000, "shear_wave_speed": 3464 },
  "output": { "exodus_interval": 40 },
  "mesh_file": null
}
```

- If `mesh_file` is set (path to existing `.msh`), skip `.geo` generation and Gmsh.
- If `mesh_file` is null, generate `.geo` from `domain` + `faults`, run Gmsh.

## Custom Function Objects

Instead of exposing raw MOOSE function syntax in the config, two Python classes build the `[Functions]` block from user-friendly parameters.

### `StaticFrictionFunction`

Takes `mu_s` from `config["physics"]["mu_s"]`. Generates a MOOSE `ConstantFunction`:

```moose
[func_static_friction_coeff_mus]
  type = ConstantFunction
  value = 0.677
[]
```

**Input**: `physics.mu_s` — one value applied uniformly to all faults (single CZM material with shared aux variable).

### `InitialShearStressFunction`

Takes `background` value + list of 2D rectangular `patches` (each with `xmin`, `xmax`, `ymin`, `ymax`, `value`, optional `label`). Generates a MOOSE `ParsedFunction` with nested `if()` expressions for each rectangular region:

```python
class InitialShearStressFunction:
    def __init__(self, background, patches):
        self.background = background
        self.patches = patches  # each: {xmin, xmax, ymin, ymax, value, label?}

    def to_moose(self):
        """Build ParsedFunction with nested if() for 2D rectangular patches."""
        # Build expression from inside out:
        # if(x>=xmin1 & x<=xmax1 & y>=ymin1 & y<=ymax1, val1,
        #   if(x>=xmin2 & x<=xmax2 & y>=ymin2 & y<=ymax2, val2,
        #     background))
        expr = str(self.background)
        for p in reversed(self.patches):
            cond = (f"x>={p['xmin']} & x<={p['xmax']} "
                    f"& y>={p['ymin']} & y<={p['ymax']}")
            expr = f"if({cond}, {p['value']}, {expr})"
        return {
            "type": "ParsedFunction",
            "expression": f"'{expr}'",
        }
```

**Example output** (single nucleation patch):
```moose
[func_initial_strike_shear_stress]
  type = ParsedFunction
  expression = 'if(x>=-9500 & x<=-6500 & y>=-6500 & y<=6500, 81600000.0, 70000000.0)'
[]
```

**Example output** (two patches):
```moose
[func_initial_strike_shear_stress]
  type = ParsedFunction
  expression = 'if(x>=-9500 & x<=-6500 & y>=-6500 & y<=6500, 81600000.0, if(x>=3000 & x<=6000 & y>=-3000 & y<=3000, 78000000.0, 70000000.0))'
[]
```

**Validation** (with unit tests):
- Patch rectangles must not overlap (2D intersection check)
- All patch bounds must be within domain bounds (both x and y)
- `background` and all `value` fields must be numeric and positive

**Unit tests** for both function objects:
- `test_constant_friction_generates_correct_moose_block`
- `test_shear_stress_no_patches_gives_constant`  → just `ParsedFunction` with `expression = 'background'`
- `test_shear_stress_single_patch` → single `if()` expression
- `test_shear_stress_multiple_patches_nested` → nested `if()` expressions
- `test_shear_stress_overlapping_patches_raises`
- `test_shear_stress_patch_outside_domain_raises`

## Pipeline Steps

### Step 1: Validate config
- No two fault lines cross each other (segment intersection test; shared endpoints OK)
- All fault endpoints within domain bounds
- Initial shear stress patches don't overlap and are within domain
- Required physics/execution/output fields present

### Step 2: Generate `.geo` file (if no `mesh_file`)
- Write domain boundary (4 corner Points, 4 Lines, Line Loop, Plane Surface)
- Collect all unique fault endpoints; assign Point IDs (deduplicate shared junctions)
- For each fault, write Line(s) — split at junctions if a fault passes through a shared point
- Write `Physical Curve("<label>")` for each fault
- Write domain boundary Physical Curves (bottom, right, top, left)
- Write `Physical Surface`, set `Mesh.Algorithm = 6`

### Step 3: Run Gmsh
- `gmsh -2 output.geo -o output.msh -format msh2`
- Check return code

### Step 4: Extract elements per fault (meshio)
Generalized from `meshio_run_tria.py`:

For each fault `i` with start `(x0,y0)` and end `(x1,y1)`:
- Read Physical Curve nodes for that fault's label from the `.msh`
- Find all triangle elements with at least 1 node on the fault
- **Upper/lower side** — generalized vector approach:
  - Fault direction `d = (x1-x0, y1-y0)`
  - Left-normal `n = (-dy, dx)` (points to "upper" side)
  - For each candidate element centroid `c`: `dot(c - start, n)` → positive = upper, negative = lower
  - **Corridor check**: project centroid onto fault direction, must be between 0 and `|d|` (with tolerance)
- Subdomain IDs for N faults: fault_1 → 100/200, fault_2 → 300/400, fault_3 → 500/600, ..., fault_N → `(2N-1)*100` / `(2N)*100`
- **Constraint**: Block pairs always have `id1 < id2` (guaranteed: upper < lower in this scheme)
- Fault labels come from user config (`fault_1`, `fault_2`, etc.) — used for VPP names and .geo Physical Curve labels

### Step 5: Sort elements along fault (for VectorPostprocessors)
Generalized from `process_coords.py`:

For each fault (upper-side elements):
- Find elements with exactly 2 nodes on the fault line (edge elements)
- Compute average position of those 2 on-fault nodes
- **Sort by distance along fault** from start point: `dot(avg_pos - start, d/|d|)`
- Collect sorted element IDs per fault

### Step 6: Render `.i` file from template
Build the MOOSE input using `__PLACEHOLDER__` markers to avoid conflicts with MOOSE `${var}`:

| Placeholder | Content |
|---|---|
| `__PARAM_BLOCK__` | Physics/execution/output params as MOOSE variable declarations |
| `__MESH_FILE__` | Path to .msh file |
| `__ELEMENT_IDS__` | Space-separated element IDs (all faults concatenated) |
| `__SUBDOMAIN_IDS__` | Parallel list of subdomain IDs |
| `__BLOCK_PAIRS__` | e.g. `'100 200; 300 400'` |
| `__BOUNDARY_LIST__` | e.g. `'Block100_Block200 Block300_Block400'` |
| `__FUNCTIONS_BLOCK__` | Generated by StaticFrictionFunction + InitialShearStressFunction |
| `__VECTORPOSTPROCESSORS__` | Per-fault VPP blocks (see below) |

**VectorPostprocessors** — 4 quantities × N faults, using fault labels:
```moose
[VectorPostprocessors]
  # fault_1: 4 VPP blocks
  [shear_jump_fault_1]
    type = ElementMaterialSampler
    material = 'shear_jump_mat'
    elem_ids = '...'   # sorted IDs for fault_1
  []
  [normal_jump_fault_1]
    type = ElementMaterialSampler
    material = 'normal_jump_mat'
    elem_ids = '...'
  []
  [shear_traction_fault_1]
    ...
  []
  [shear_jump_rate_fault_1]
    ...
  []
  # fault_2: 4 VPP blocks
  [shear_jump_fault_2]
    type = ElementMaterialSampler
    material = 'shear_jump_mat'
    elem_ids = '...'   # sorted IDs for fault_2
  []
  # ... same pattern for all N faults
[]
```
Each fault produces a separate CSV file per quantity for clean post-processing.

## Validation Checks (with descriptive error messages)

All validation errors raise `ValueError` with messages that pinpoint the problem and how to fix it.

1. **No fault crossings**:
   - Check: Segment intersection test for every pair of faults (shared endpoints allowed as junctions)
   - Error: `"Fault 'fault_2' (start=[0,0], end=[5000,-3000]) crosses fault 'fault_3' (start=[-2000,-1000], end=[3000,-2000]) at approximately (1234, -1567). Faults may share endpoints but must not cross. Adjust the start/end coordinates of one of these faults."`

2. **Faults within domain**:
   - Check: All start/end `(x,y)` satisfy `xmin <= x <= xmax` and `ymin <= y <= ymax`
   - Error: `"Fault 'fault_1' endpoint end=[30000, 0] is outside the domain (xmin=-26000, xmax=24000, ymin=-20000, ymax=20000). The x-coordinate 30000 exceeds xmax=24000. Adjust the fault endpoint or expand the domain."`

3. **Block ID ordering**: Guaranteed by numbering scheme — no validation needed (100<200, 300<400, ...)

4. **Stress patches — no overlaps**:
   - Check: For every pair of patches, their 2D rectangles must not overlap
   - Error: `"Initial shear stress patch 'nucleation' (x=[-9500,-6500], y=[-6500,6500]) overlaps with patch 'elevated' (x=[-8000,-5000], y=[-3000,3000]). Adjust the xmin/xmax/ymin/ymax bounds so patches do not overlap."`

5. **Stress patches — within domain**:
   - Check: All patch bounds within domain
   - Error: `"Initial shear stress patch 'nucleation' has xmin=-9500 which is outside the domain (xmin=-8000). Adjust the patch bounds or expand the domain."`

6. **Fault labels unique**:
   - Check: No two faults share the same label
   - Error: `"Duplicate fault label 'fault_1' found at indices 0 and 2. Each fault must have a unique label."`

7. **Required fields present**:
   - Check: Config has `domain`, `faults` (non-empty), `physics` (including `mu_s`), `execution`, `output`
   - Error: `"Missing required config section: 'physics'. The config must include: domain, faults, physics, execution, output."`
   - Error: `"Missing required field: 'physics.mu_s'. Specify the static friction coefficient (e.g., 0.677)."`

## Files to Create

All under `examples/dynamicelastic_app/`:

### 1. `generate_multifault.py` (~500 lines)

Functions/classes:
- `class StaticFrictionFunction` — builds `[func_static_friction_coeff_mus]` from `mu_s`
- `class InitialShearStressFunction` — builds `[func_initial_strike_shear_stress]` from background + patches
- `validate_config(config)` — crossing check, bounds check, patch overlap check
- `generate_geo(config, output_path)` — write .geo from config
- `run_gmsh(geo_path, msh_path)` — subprocess call
- `extract_fault_elements(msh_path, faults)` — meshio extraction, returns per-fault data
- `sort_fault_elements(msh_path, faults, fault_elements)` — sort for VPP
- `build_functions_block(config)` — uses function objects to generate `[Functions]` text
- `build_vectorpostprocessors(faults, sorted_elem_ids)` — generate per-fault VPP text
- `render_input_file(template_path, config, mesh_data)` — assemble final .i
- `main()` — CLI: `python generate_multifault.py config.json [--dry-run] [--output-dir DIR]`

### 2. `templates/multifault_2d.i.template`

Based on `tpv142D_tria.i` structure with placeholder markers.

### 3. `config/example_config_multifault.json`

TPV14-equivalent config demonstrating the JSON format.

### 4. `test_generate_multifault.py`

Unit tests:
- **Function objects**:
  - `test_constant_friction_generates_correct_moose_block`
  - `test_shear_stress_no_patches` → `ParsedFunction` expression = background value
  - `test_shear_stress_single_2d_patch` → single `if(x>=.. & x<=.. & y>=.. & y<=.., val, bg)`
  - `test_shear_stress_multiple_patches_nested` → nested `if()` expressions
  - `test_shear_stress_overlapping_patches_raises`
  - `test_shear_stress_patch_outside_domain_raises`
- **Config validation**:
  - `test_crossing_faults_raises` — two faults that intersect (not at shared endpoint)
  - `test_shared_endpoint_ok` — two faults meeting at a junction (no error)
  - `test_fault_outside_domain_raises`
  - `test_valid_config_passes`
- **Geo generation**:
  - `test_geo_single_fault` — 1 fault: correct Points, Lines, Physical Curves
  - `test_geo_two_faults_with_junction` — 2 faults sharing a point (TPV14 pattern)
  - `test_geo_three_faults` — 3 independent faults: correct structure
- **Subdomain assignment**:
  - `test_subdomain_ids_two_faults` — fault_1→100/200, fault_2→300/400
  - `test_subdomain_ids_three_faults` — fault_1→100/200, fault_2→300/400, fault_3→500/600
  - `test_block_pairs_ordering` — verify id1 < id2 always
- **N-fault boundary propagation**:
  - `test_boundary_list_two_faults` — `'Block100_Block200 Block300_Block400'`
  - `test_boundary_list_three_faults` — `'Block100_Block200 Block300_Block400 Block500_Block600'`
- **VPP generation**:
  - `test_vpp_per_fault_naming` — labels use fault label from config (e.g., `shear_jump_fault_1`)
  - `test_vpp_three_faults_produces_12_blocks` — 4 quantities × 3 faults = 12 VPP blocks
- **Template rendering**:
  - `test_all_placeholders_replaced` — no `__XX__` markers remain in output
- **Integration** (skipped if gmsh not available):
  - `test_full_pipeline_tpv14_config` — end-to-end with 2-fault TPV14 config
  - `test_full_pipeline_single_fault` — single horizontal fault (TPV205-like), validates the pipeline reproduces a simple planar fault case

## Verification

1. `python -m unittest test_generate_multifault -v` — all tests pass
2. `python generate_multifault.py config/example_config_multifault.json --dry-run`
   - `.geo` matches structure of `tpv142d_100m.geo`
   - `[Functions]` block generated correctly from function objects
   - `block_pairs = '100 200; 300 400'`
   - Separate VPP per fault
3. Full run (requires gmsh + meshio): produces `.msh` and `.i` ready for MOOSE

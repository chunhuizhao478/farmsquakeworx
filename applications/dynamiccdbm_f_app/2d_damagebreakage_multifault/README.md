# 2D Multi-Fault Damage-Breakage Pipeline (CDBM)

Auto-generated MOOSE input files for multi-fault dynamic rupture simulations
that use the unified `ComputeDamageBreakageStress3DSlipWeakening` material
(continuum damage-breakage rheology) and the CDBM-coupled cohesive-zone
friction `SlipWeakeningFrictionczm2dCDBM`.

## Quick start

```bash
python applications/dynamiccdbm_f_app/generate_multifault.py \
    applications/dynamiccdbm_f_app/config/example_config_multifault_cdbm.json
```

The pipeline:
1. Validates the JSON config (geometry + CDBM-required physics keys).
2. Renders a Gmsh `.geo` from the domain + faults.
3. Runs Gmsh to produce `.msh` (requires `gmsh` on `$PATH`).
4. Extracts and sorts per-fault elements via `meshio`.
5. Renders `multifault_2d_cdbm.i` from
   `applications/dynamiccdbm_f_app/templates/multifault_2d_cdbm.i.template`.

The generator is a thin CDBM wrapper around the elastic-app's geometry/mesh
helpers (`applications/dynamicelastic_app/generate_multifault.py`); only the
parameter mapping, function block, and template are CDBM-specific.

## Schema deltas vs. the elastic-app config

The CDBM config extends `dynamicelastic_app/config/example_config_multifault.json`
with two new sub-blocks:

### `physics` — required CDBM keys

```json
"physics": {
  "...": "(elastic keys: q, Dc, mu_s, mu_d, density, lambda_o, shear_modulus_o)",
  "xi_0": -0.9, "xi_d": -0.9, "xi_max": 1.8, "xi_min": -1.8,
  "chi": 0.8, "C_g": 1e-12, "m1": 10, "m2": 1,
  "Cd_constant": 1e8, "C_1": 0, "C_2": 0.05, "beta_width": 0.05,
  "CdCb_multiplier": 100, "CBH_constant": 0
}
```
All 14 CDBM keys are required; missing keys raise `ValueError` from
`validate_cdbm_physics`.

### `nonlocal` — optional, defaults match `2d_damagebreakage_case1`

```json
"nonlocal": {
  "averaging_length_scale": 200,
  "averaging_radius": 400,
  "use_strain_rate_dependent_Cd": false,
  "m_exponent": 0.8,
  "strain_rate_hat": 5e-9,
  "cd_hat": 10
}
```

Note: there is no `blocks` key. The pipeline applies one global
`ElkRadialAverageUpdated` UO + one `ElkNonlocalEqstrainUpdated` material
across every block (no per-fault partitioning). This is the simplification
that makes the multifault topology agnostic.

## Global-nonlocal trade-off

With one global averaging UO covering the entire domain, the radial average
will reach across fault interfaces if the search radius exceeds the local
element-to-fault distance. In the case1 single-fault setup, the per-block
UOs were specifically there to *prevent* cross-fault averaging. Here we
accept some cross-fault smearing of `xi` in exchange for not having to
enumerate per-fault block IDs (which would balloon to 2N entries for an
N-fault topology).

If smearing is severe in your problem, reduce `nonlocal.averaging_radius`
in the config.

## Rotation correctness on non-horizontal faults

`SlipWeakeningFrictionczm2dCDBM` rotates the global stress tensor into
fault-local coordinates before extracting the initial tractions
(Phase-0b patch in this PR). The example config has 4 of 5 faults at
non-zero angles (fault_2/3/5 at ±30°, fault_4 at +90°), so this rotation
is essential for correct initial state — see
`test/tests/materials/slip_weakening_czm_2d_cdbm_rotated/` for the
regression test that locks the convention.

## Files in this directory

| File | Purpose |
|---|---|
| `output.geo` | Gmsh source (committed for reproducibility) |
| `output.msh` | Gmsh-meshed input (committed; ~26 MB for the 5-fault example) |
| `multifault_2d_cdbm.i` | Rendered MOOSE input (committed) |
| `README.md` | This file |

# Implementation Plan: Multifault 2D for `dynamiccdbm_f_app` (damage-breakage)

> **Revision r2** — incorporates all REVIEW.md findings (R-001 through R-009)
> and the user's directive that **nonlocal averaging is retained** but applied
> globally (no per-block partitioning).

## Overview

Port the existing config-driven multifault pipeline from
`applications/dynamicelastic_app/` (templates + `generate_multifault.py`) to
`applications/dynamiccdbm_f_app/`, replacing the elastic constitutive material
with the unified continuum-damage-breakage stress (CDBM) material and the
elastic CZM friction with the CDBM-coupled CZM friction. **Nonlocal
equivalent-strain averaging is RETAINED**, but the per-block partitioning that
`2d_damagebreakage_case1/dynamic_solve.i` uses is dropped — a single
`ElkRadialAverageUpdated` UO + `ElkNonlocalEqstrainUpdated` material pair runs
globally across every block. This eliminates the need to enumerate per-fault
block IDs in the averaging objects (which would balloon to 2N entries for an
N-fault topology) while keeping the mesh-regularisation benefit of nonlocal
strain.

The port preserves the elastic-app geometry pipeline 1-for-1 (gmsh, element
extraction, per-fault subdomain assignment, per-fault VPP) and changes only
(a) the MOOSE template, (b) the per-fault parameter mapping, (c) the rendered
output location, and (d) **two small C++ patches**:
1. Allow empty `nonlocal_eqstrain_blocks` to mean "apply on every block" in
   `ComputeDamageBreakageStress3DSlipWeakening` (the helper
   `useNonlocalEqStrainHere()` already implements this; only the
   constructor's overzealous `mooseError` needs to be downgraded).
2. **[NEW per R-001]** Add stress-tensor rotation to fault-local frame in
   `SlipWeakeningFrictionczm2dCDBM::computeInterfaceTractionAndDerivatives()`
   so the initial tractions are correct for non-horizontal faults. Without
   this fix, the entire multifault use case is silently wrong.

## Constraints

### Interface (cannot change without warning the user)
- `ComputeDamageBreakageStress3DSlipWeakening::validParams()`
  (`src/materials/cdbm3d/ComputeDamageBreakageStress3DSlipWeakening.C`,
  lines 43–107). All 16 `addRequiredParam<Real>` parameters MUST be present in
  the rendered input or the simulation fails at construction.
- `SlipWeakeningFrictionczm2dCDBM::validParams()`
  (`src/materials/slipweakeningczm/SlipWeakeningFrictionczm2dCDBM.C`,
  lines 20–35). Required: `mu_s`, `mu_d`, `Dc`, `len`, the four coupled vars.
  Optional: `peak_shear_stress`, `nucl_center` (length-2 vector for 2D),
  `nucl_radius`. The class consumes `static_initial_stress_tensor` via
  `getMaterialPropertyByName` (line 64), so a `GenericFunctionRankTwoTensor`
  with `tensor_name = static_initial_stress_tensor` MUST be declared on every
  block where the CZM material runs.
- `ElkNonlocalEqstrainUpdated` declares the material property
  `eqstrain_nonlocal` (single `Real`); the unified CDBM stress class reads
  this property's old value unconditionally
  (`ComputeDamageBreakageStress3DSlipWeakening.C` line 159). It must
  therefore be declared on every block where `stress_medium` runs.
  **NOTE [R-002]:** `eqstrain_nonlocal` and `eqstrain_nonlocal_initial` are
  *different* properties. Declaring the latter is not a substitute for the
  former.
- `ElkRadialAverageUpdated`
  (`include/userobjects/nonlocaldamage/ElkRadialAverageUpdated.h`) consumes a
  material property by name (`prop_name`, default `xi`) and provides the
  average to `ElkNonlocalEqstrainUpdated` via `average_UO`. Both objects
  support being declared without `block = ...` (run on all blocks).
- `BreakMeshByBlockGenerator` produces interface sidesets named exactly
  `Block<u>_Block<l>` (where `u` < `l`) when `split_interface = true`. The
  generator code in `dynamicelastic_app/generate_multifault.py`
  (lines 656–657 and 873) already encodes this naming with `(2*fi+1)*100` /
  `(2*fi+2)*100` — reuse verbatim.
- The MOOSE `Physics/SolidMechanics/CohesiveZone` block syntax — already used
  in `case2/case4` 3D inputs — must mirror the elastic multifault template
  exactly (`dynamicelastic_app/templates/multifault_2d.i.template`
  lines 132–138).
- `farmsquakeworxApp` registers all custom MOOSE objects under that exact app
  name. The C++ changes in this plan are limited to the two patches in
  Phase 0; no new object registrations are introduced.

### Dependencies
- The existing elastic-app helpers `extract_fault_elements`,
  `sort_fault_elements`, `generate_geo`, `run_gmsh`, `validate_config`,
  `evaluate_fault_initial_stress` in
  `applications/dynamicelastic_app/generate_multifault.py` (lines 256–723)
  are reused by import. They are pure functions and contain no rheology
  assumptions.
- `gmsh` (binary on `$PATH`), `meshio`, `numpy` — same as elastic-app.

### Convention
- New files live under `applications/dynamiccdbm_f_app/`, mirroring the layout
  of `dynamicelastic_app/`:
  - generator: `applications/dynamiccdbm_f_app/generate_multifault.py`
  - template: `applications/dynamiccdbm_f_app/templates/multifault_2d_cdbm.i.template`
  - example config: `applications/dynamiccdbm_f_app/config/example_config_multifault_cdbm.json`
  - rendered output dir: `applications/dynamiccdbm_f_app/2d_damagebreakage_multifault/`
- Filenames use the suffix `_cdbm` to disambiguate from the elastic-app
  multifault outputs.
- Numeric defaults match `2d_damagebreakage_case1/dynamic_solve.i`. **Note
  [R-006]:** "byte-for-byte equivalent on physics" applies to material
  parameters AND the static_initial_stress_tensor row-major entries; in
  particular, the (2,2) entry must be `func_zero` (σ_zz = 0), not σ_yy.

### Numerical / physics
- Unified stress class uses `use_nonlocal_eqstrain = true`,
  `nonlocal_eqstrain_blocks` left UNSET. After the Phase-0 patch the class
  treats this as "use nonlocal averaging on every block" via
  `useNonlocalEqStrainHere()` (`.h` lines 215–224).
- One global `ElkRadialAverageUpdated` UO and one global
  `ElkNonlocalEqstrainUpdated` material handle averaging across the entire
  domain. The averaging WILL cross fault interfaces if the radius is large
  enough — accepted trade-off (the case1 file's separate per-block UOs were
  there to prevent cross-fault averaging; here we accept that risk in
  exchange for multifault-topology agnosticism).
- `static_solve_flag = false` (no preceding static solve) selects the
  Hooke's-law path in `setupInitial()`
  (`ComputeDamageBreakageStress3DSlipWeakening.C` lines 605–698). The 2D
  plane-strain branch hard-codes `eps_zz_init = 0` regardless of σ_zz.

---

## Phase 0: C++ patches (constructor + CZM rotation)

### Goal
Two minimal, independently-reviewable C++ changes:
0a. Allow `use_nonlocal_eqstrain = true` with empty
    `nonlocal_eqstrain_blocks` to mean "apply on every block" (back-compat for
    existing inputs that supply the list).
0b. **[R-001]** Rotate the global stress tensor into fault-local coordinates
    in `SlipWeakeningFrictionczm2dCDBM::computeInterfaceTractionAndDerivatives()`
    so the initial T1_o (shear) and T2_o (normal) are correct for any fault
    orientation, not just horizontal faults.

### Files to Modify
- `src/materials/cdbm3d/ComputeDamageBreakageStress3DSlipWeakening.C`:
  - Constructor body (lines 168–172): downgrade `mooseError` → `mooseInfo`.
  - `validParams()` (lines 91–96): update parameter description.
- `include/materials/cdbm3d/ComputeDamageBreakageStress3DSlipWeakening.h`:
  - Comment on `_nonlocal_eqstrain_blocks` (line 196–197) — already correct,
    confirm during review.
- `src/materials/slipweakeningczm/SlipWeakeningFrictionczm2dCDBM.C`:
  - `computeInterfaceTractionAndDerivatives()` (lines 124–134): replace the
    direct global-tensor extraction with a fault-local rotation, mirroring
    `SlipWeakeningFrictionczm2dParametricStudy.C` lines 163–178.

### Detailed Requirements

**0a. Constructor downgrade.** In `ComputeDamageBreakageStress3DSlipWeakening.C`
constructor body (current lines 168–172) replace:

```cpp
// BEFORE
if (_use_nonlocal_eqstrain && _nonlocal_eqstrain_blocks.empty())
  mooseError("When 'use_nonlocal_eqstrain=true' you must provide 'nonlocal_eqstrain_blocks' "
             "(e.g., 'nonlocal_eqstrain_blocks = 100 200').");
```
with:
```cpp
// AFTER
if (_use_nonlocal_eqstrain && _nonlocal_eqstrain_blocks.empty())
  mooseInfo("'use_nonlocal_eqstrain=true' with empty 'nonlocal_eqstrain_blocks' "
            "-> nonlocal averaging will be applied on EVERY block.");
```
(Use `_console << ... << std::endl;` if `mooseInfo` is unavailable in the
project's MOOSE version.)

In `validParams()` (lines 91–96) update the description:

```cpp
// BEFORE
params.addParam<std::vector<unsigned int>>("nonlocal_eqstrain_blocks", {},
    "REQUIRED when use_nonlocal_eqstrain=true. Subdomain/Block IDs where "
    "nonlocal equivalent strain is enabled (e.g., 100 200)");
// AFTER
params.addParam<std::vector<unsigned int>>("nonlocal_eqstrain_blocks", {},
    "Subdomain/Block IDs where nonlocal equivalent strain is enabled. "
    "Empty (default) means 'apply on every block' when "
    "use_nonlocal_eqstrain=true. Example: '100 200'.");
```

**0b. CZM stress-tensor rotation [R-001].** In
`SlipWeakeningFrictionczm2dCDBM.C::computeInterfaceTractionAndDerivatives()`
(current lines 124–134), replace:

```cpp
// BEFORE
// Compute T1_o, T2_o for current qp from CDBM static stress tensor
Real T1_o = _static_initial_stress_tensor[_qp](0, 1);          // shear stress in t dir
Real T2_o = -1.0 * _static_initial_stress_tensor[_qp](1, 1);   // normal stress in n dir
```
with:
```cpp
// AFTER
// Rotate the global stress tensor into fault-local coordinates and extract
// the traction on the fault plane. The CZM rotation matrix _rot maps from
// fault-local to global; the local frame uses component(0) = normal,
// component(1) = tangential.
RankTwoTensor sts_init_local =
    _rot[_qp].transpose() * _static_initial_stress_tensor[_qp] * _rot[_qp];
RealVectorValue local_normal(1.0, 0.0, 0.0);
RealVectorValue traction_local = sts_init_local * local_normal;
Real T1_o = traction_local(1);   // shear (local-tangential)
Real T2_o = -traction_local(0);  // normal (compression-positive)
```

Verify the convention against `SlipWeakeningFrictionczm2dParametricStudy.C`
lines 163–178 before merging — if that sibling uses a different sign on T2_o
or a different `local_normal` direction, mirror its choice exactly.

### Interfaces
- No public interface added or removed in 0a (`validParams()` becomes more
  permissive only).
- 0b is a behavioural change visible only on rotated faults; horizontal-fault
  inputs (e.g., the existing 2D `2d_damagebreakage_case1`) produce identical
  T1_o/T2_o values because rotation by the identity tensor is a no-op.

### Edge Cases to Handle
- Existing single-fault inputs (case1, case2, case3, case4, v1) explicitly
  set `nonlocal_eqstrain_blocks = '...'` — they continue to work unchanged
  for 0a (no behavioural change when the list is non-empty).
- 0a removes a `mooseError` — verify no test asserts that this error fires
  (`grep -r "must provide 'nonlocal_eqstrain_blocks'" test/ unit/` returns
  nothing). If a test exists, update it.
- For 0b, verify that the existing 2D case1 single-fault simulation
  reproduces its baseline behaviour. The fault is horizontal so rotation is
  identity and tractions should be unchanged to roundoff.

### Acceptance Criteria
- [ ] Existing single-fault `2d_damagebreakage_case1/dynamic_solve.i`
      (which sets `nonlocal_eqstrain_blocks = '100 200'`) still runs
      identically — no diff in the first 100 timesteps' Exodus output.
- [ ] A new minimal `.i` with `use_nonlocal_eqstrain = true` and NO
      `nonlocal_eqstrain_blocks` parameter parses + runs without error and
      prints a console line containing `EVERY block`.
- [ ] On a 45°-fault test mesh (Phase 1.5 below), the computed T1_o equals
      the analytic stress-tensor decomposition within 1 kPa.
- [ ] `unit/run_tests --gtest_filter='*'` is still green.

### Dependencies
- Depends on: nothing.
- Required by: Phase 1, Phase 1.5, Phase 2, Phase 3, Phase 4.

---

## Phase 1: Smoke test — case1 with `nonlocal_eqstrain_blocks` removed

### Goal
Smoke-test the Phase-0a patch on the existing single-fault case1 input by
removing ONLY the `nonlocal_eqstrain_blocks` parameter from the stress
material. Nonlocal averaging itself stays — only the per-block list is
omitted, exercising the new "empty list ⇒ apply everywhere" code path. The
per-block `ElkNonlocalEqstrainUpdated` materials, `ElkRadialAverageUpdated`
UOs, and the elastic-block fallback `ParsedMaterial` from case1 are LEFT
UNTOUCHED so this phase tests one thing only: that the unified CDBM stress
class accepts the empty-blocks configuration and runs to completion without
error. **No claim of numerical agreement with case1 — explicitly out of
scope.**

### Files to Create
- `applications/dynamiccdbm_f_app/2d_damagebreakage_case1_emptyblocks/dynamic_solve.i`

### Files to Modify
- None.

### Detailed Requirements

Starting from a verbatim copy of
`applications/dynamiccdbm_f_app/2d_damagebreakage_case1/dynamic_solve.i`,
apply the following minimal diff:

1. In the `[stress_medium_nonlocal]` material declaration (case1 lines
   422–434), delete EXACTLY the line:
   ```
   nonlocal_eqstrain_blocks = ${nonlocal_eqstrain_blocks}
   ```
   Leave `use_nonlocal_eqstrain = true` and every other parameter unchanged.

2. Make NO other source changes. Specifically, do NOT:
   - delete or merge the per-block `ElkNonlocalEqstrainUpdated` materials.
   - delete or merge the per-block `ElkRadialAverageUpdated` UOs.
   - delete the elastic-block fallback `ParsedMaterial`.
   - touch the `nonlocal_eqstrain_blocks*` or `local_eqstrain_blocks` rows in
     the parameter header (the per-block declarations still reference them).
   - touch `[Mesh]`, `[BCs]`, `[Executioner]`, or `[Outputs]`.

3. Optional one-line header comment at the top:
   ```
   # Phase-1 smoke test: nonlocal_eqstrain_blocks parameter omitted from
   # stress_medium_nonlocal. Tests Phase-0a patch.
   ```

### Edge Cases to Handle
- `eqstrain_nonlocal` is still declared on every block via the existing
  per-block mechanisms — no missing-property errors expected.

### Acceptance Criteria
- [ ] `farmsquakeworx-opt --check-input -i dynamic_solve.i` parses cleanly.
- [ ] `farmsquakeworx-opt -i dynamic_solve.i` runs without `mooseError` for
      at least the first 100 timesteps.
- [ ] Console output contains the Phase-0a `mooseInfo` line about
      "EVERY block".
- [ ] Exodus output is non-empty and contains the same variables as case1
      (`disp_slipweakening_x`, `vel_slipweakening_x`, `alpha_damagedvar_aux`,
      `B_aux`, `eqstrain_nonlocal_aux`, `jump_x_aux`, `traction_x_aux`).
- [ ] No NaN at the 100th timestep.
- **NOT a criterion**: numerical agreement with case1.

### Dependencies
- Depends on: Phase 0a.
- Required by: Phase 2.

---

## Phase 1.5: Rotation regression test for the CZM friction patch  *[NEW per R-001]*

### Goal
Verify that the Phase-0b stress-tensor rotation produces correct
fault-local tractions on a non-horizontal fault. The single-fault case1
mesh is horizontal and cannot exercise the rotation. This phase introduces
a minimal 45°-fault test that compares the computed T1_o against an
analytic decomposition.

### Files to Create
- `test/tests/materials/slip_weakening_czm_2d_cdbm_rotated/test_sw_czm_2d_cdbm_rotated.i`
- `test/tests/materials/slip_weakening_czm_2d_cdbm_rotated/tests`
- `test/tests/materials/slip_weakening_czm_2d_cdbm_rotated/gold/test_sw_czm_2d_cdbm_rotated_out.csv`

### Files to Modify
- None.

### Detailed Requirements

1. **Mesh**: 2-element TRI3 mesh in 2D, with the interface oriented at 45°
   to the global x-axis. Build directly via `GeneratedMeshGenerator`
   followed by `MeshDiagonal` (or load a small handcrafted `.msh`).

2. **Background stress tensor**:
   ```
   sigma_xx = -100e6,  sigma_yy = -120e6,  sigma_xy = 20e6
   ```
   (matches the elastic-app multifault example; ensures non-trivial rotation
   results.)

3. **Analytic targets**: For a 45° fault tangent `(1,1)/√2` and normal
   `(-1,1)/√2`, the local traction is:
   ```
   T1_o (shear)   = (sigma_yy - sigma_xx)/2 + sigma_xy * cos(2θ)
                  = -10e6 + 20e6 * cos(90°)
                  = -10e6                         (Pa)
   T2_o (normal,
         compression-positive) per CZM convention:
                  = -(sigma_xx + sigma_yy)/2 + sigma_xy * sin(2θ)
                  = +110e6 + 20e6 * 1
                  = +130e6                        (Pa)
   ```
   *(Re-derive both signs against `SlipWeakeningFrictionczm2dParametricStudy`
   conventions before locking the gold; the value matters less than the
   convention being identical to the sibling class.)*

4. **Probe**: Use a `SideValueSampler` on the CZM boundary at t = 0
   (initial state, no slip yet). Record `traction_strike` and
   `traction_normal` to CSV.

5. **`tests` spec**:
   ```
   [Tests]
     [test_sw_czm_2d_cdbm_rotated]
       type = CSVDiff
       input = test_sw_czm_2d_cdbm_rotated.i
       csvdiff = test_sw_czm_2d_cdbm_rotated_out.csv
       abs_zero = 1.0e3   # 1 kPa absolute tolerance
       rel_err = 1.0e-3
     []
   []
   ```

### Acceptance Criteria
- [ ] On the 45° mesh, `traction_strike` at t=0 is within 1 kPa of the
      analytic T1_o value.
- [ ] `traction_normal` at t=0 is within 1 kPa of the analytic T2_o value.
- [ ] Repeating the same test with the Phase-0b patch reverted (i.e., the
      old direct-global extraction) FAILS the CSV diff. (Confirms the test
      actually exercises the rotation code path.)

### Dependencies
- Depends on: Phase 0b.
- Required by: Phase 2 (template's CZM material reads the rotated tractions;
  Phase 2 acceptance assumes Phase 1.5 is green).

---

## Phase 2: Multifault CDBM 2D template

### Goal
Author a MOOSE input template
`applications/dynamiccdbm_f_app/templates/multifault_2d_cdbm.i.template`
that the generator (Phase 3) fills in. The template uses ONE global
nonlocal averaging UO + material, mirroring the smoke-test wiring.

### Files to Create
- `applications/dynamiccdbm_f_app/templates/multifault_2d_cdbm.i.template`

### Files to Modify
- None.

### Detailed Requirements

Marker tokens (must each appear in the template; some may appear multiple
times):
`__PARAM_BLOCK__`, `__MESH_FILE__`, `__ELEMENT_IDS__`, `__SUBDOMAIN_IDS__`,
`__BLOCK_PAIRS__`, `__BOUNDARY_LIST__`, `__FUNCTIONS_BLOCK__`,
`__VECTORPOSTPROCESSORS__`.

Required blocks (in order):

1. **`[Mesh]`** — identical to elastic-app multifault
   (`FileMeshGenerator → SubdomainPerElementGenerator →
   BreakMeshByBlockGenerator → SideSetsFromNormalsGenerator`).

2. **`[GlobalParams]`** — every parameter consumed by the unified CDBM
   stress class:
   ```
   displacements = 'disp_x disp_y'
   q = ${q}
   Dc = ${Dc}
   mu_s = ${mu_s}
   mu_d = ${mu_d}
   len = ${len}
   lambda_o = ${lambda_o}
   shear_modulus_o = ${shear_modulus_o}
   xi_0 = ${xi_0}
   xi_d = ${xi_d}
   xi_max = ${xi_max}
   xi_min = ${xi_min}
   Cd_constant = ${Cd_constant}
   CdCb_multiplier = ${CdCb_multiplier}
   CBH_constant = ${CBH_constant}
   C_1 = ${C_1}
   C_2 = ${C_2}
   beta_width = ${beta_width}
   C_g = ${C_g}
   m1 = ${m1}
   m2 = ${m2}
   chi = ${chi}
   ```

3. **`[AuxVariables]`** *[corrected per R-003]* — declare exactly:

   LAGRANGE / FIRST:
   - `resid_x`, `resid_y`
   - `resid_slipweakening_x`, `resid_slipweakening_y`
   - `disp_slipweakening_x`, `disp_slipweakening_y`
   - `vel_slipweakening_x`, `vel_slipweakening_y`

   MONOMIAL / FIRST:
   - `alpha_damagedvar_aux`, `B_aux`, `xi_aux`,
     `eqstrain_nonlocal_aux`, `deviatoric_strain_rate_aux`
   - `jump_strike_aux`, `jump_normal_aux`
   - `jump_strike_rate_aux`, `jump_normal_rate_aux`
   - `traction_strike_aux`, `traction_normal_aux`

   Drop the elastic-app-specific `local_*`, `normal_*`, `tangent_*`,
   `mu_s`, `ini_shear_stress`, `ini_normal_stress` AuxVariables — they have
   no CDBM-side AuxKernel writing them.

4. **`[Physics/SolidMechanics/CohesiveZone]`** — boundary
   `'__BOUNDARY_LIST__'`, `strain = SMALL`,
   `generate_output = 'traction_x traction_y jump_x jump_y'`. Identical to
   elastic-app template lines 132–138.

5. **`[Physics] [SolidMechanics] [QuasiStatic] [all]`** —
   `planar_formulation = PLANE_STRAIN`, `add_variables = true`,
   `generate_output = 'stress_xx stress_yy stress_xy'`,
   `extra_vector_tags = 'restore_tag'`.

6. **`[Problem]`** — `extra_tag_vectors = 'restore_tag'`.

7. **`__FUNCTIONS_BLOCK__`** — replaced by Phase 3 with **four**
   `ConstantFunction`s *[corrected per R-005]*:
   `func_initial_stress_xx`, `func_initial_stress_xy`,
   `func_initial_stress_yy`, `func_zero`.

8. **`[AuxKernels]`** — keep `Displacment_x/y`, `Vel_x/y`,
   `Residual_x/y`, `restore_x/y` (identical to elastic-app template lines
   161–207). Add CDBM diagnostics (each entry MUST spell out `variable =
   <name>`):

   - `[get_alpha_damagedvar]` `type = MaterialRealAux`,
     `property = alpha_damagedvar`, `variable = alpha_damagedvar_aux`,
     `execute_on = 'TIMESTEP_END'`.
   - `[get_B]` `type = MaterialRealAux`, `property = B`,
     `variable = B_aux`, `execute_on = 'TIMESTEP_END'`.
   - `[get_xi]` `type = MaterialRealAux`, `property = xi`,
     `variable = xi_aux`, `execute_on = 'TIMESTEP_END'`.
   - `[get_eqstrain_nonlocal]` `type = MaterialRealAux`,
     `property = eqstrain_nonlocal`, `variable = eqstrain_nonlocal_aux`,
     `execute_on = 'TIMESTEP_END'`.
   - `[get_deviatoric_strain_rate]` `type = MaterialRealAux`,
     `property = deviatoric_strain_rate`,
     `variable = deviatoric_strain_rate_aux`,
     `execute_on = 'TIMESTEP_END'`.

   Per-boundary (each with `boundary = '__BOUNDARY_LIST__'` and
   `execute_on = 'TIMESTEP_END'`):
   - `[get_jump_strike]` `property = displacement_jump_strike`,
     `variable = jump_strike_aux`.
   - `[get_jump_normal]` `property = displacement_jump_normal`,
     `variable = jump_normal_aux`.
   - `[get_jump_strike_rate]` `property = displacement_jump_rate_strike`,
     `variable = jump_strike_rate_aux`.
   - `[get_jump_normal_rate]` `property = displacement_jump_rate_normal`,
     `variable = jump_normal_rate_aux`.
   - `[get_traction_strike]` `property = traction_strike`,
     `variable = traction_strike_aux`.
   - `[get_traction_normal]` `property = traction_normal`,
     `variable = traction_normal_aux`.

9. **`[Kernels]`** — `inertia_x/y` (`InertialForce`), `Reactionx/y`
   (`StiffPropDamping`).

10. **`[Materials]`** — declare:

    - `[stress_medium]`:
      ```
      type = ComputeDamageBreakageStress3DSlipWeakening
      output_properties = 'B alpha_damagedvar xi I1 I2 deviatoric_strain_rate'
      use_nonlocal_eqstrain = true
      # nonlocal_eqstrain_blocks intentionally omitted (Phase 0a) ->
      # applies on every block.
      static_solve_flag = false
      use_strain_rate_dependent_Cd = ${use_strain_rate_dependent_Cd}
      m_exponent = ${m_exponent}
      strain_rate_hat = ${strain_rate_hat}
      cd_hat = ${cd_hat}
      zero_Cd_below_threshold = true
      outputs = exodus
      ```
      No `block = ...`.

    - `[dummy_material]` *[corrected per R-002]*: `GenericConstantMaterial`,
      ```
      prop_names = 'eqstrain_nonlocal_initial initial_damage initial_breakage damage_perturbation density'
      prop_values = '-0.92 0 0 0 ${density}'
      ```
      Note: the `eqstrain_nonlocal` (without `_initial`) property is
      declared by `ElkNonlocalEqstrainUpdated` in item 10f below — that is
      the canonical declarer. Do NOT add `eqstrain_nonlocal` to
      `dummy_material` (would conflict with the Elk material's
      declaration).

    - `[czm_mat]`:
      ```
      type = SlipWeakeningFrictionczm2dCDBM
      boundary = '__BOUNDARY_LIST__'
      disp_slipweakening_x     = disp_slipweakening_x
      disp_slipweakening_y     = disp_slipweakening_y
      reaction_slipweakening_x = resid_slipweakening_x
      reaction_slipweakening_y = resid_slipweakening_y
      peak_shear_stress = ${peak_shear_stress}
      nucl_center = '${nucl_center_x} ${nucl_center_y}'
      nucl_radius = ${nucl_radius}
      ```
      `nucl_center` is length-2 for 2D. **The Phase-0b rotation patch is a
      prerequisite for this to work on rotated faults.**

    - `[static_initial_strain_tensor]`: `GenericFunctionRankTwoTensor`,
      `tensor_name = static_initial_strain_tensor`, all-zero (3×3 of
      `func_zero`). Declared because the unified class's constructor takes
      a `getMaterialProperty<RankTwoTensor>` reference.

    - `[static_initial_stress_tensor]` *[corrected per R-006]*:
      `GenericFunctionRankTwoTensor`,
      `tensor_name = static_initial_stress_tensor`,
      ```
      tensor_functions = 'func_initial_stress_xx func_initial_stress_xy func_zero
                          func_initial_stress_xy func_initial_stress_yy func_zero
                          func_zero               func_zero               func_zero'
      ```
      Row-major: entry (2,2) = `func_zero` (σ_zz = 0), to match
      `2d_damagebreakage_case1` and the project's plane-strain assumption.
      No `boundary = ...` — declared on every block so the friction
      material can read the property on each fault interface.

    - `[nonlocal_eqstrain_global]` (single global instance):
      ```
      type = ElkNonlocalEqstrainUpdated
      average_UO = eqstrain_averaging_global
      # no block= -> applies to every subdomain
      ```

11. **`[UserObjects]`** — declare:
    - `recompute_residual_tag` (`ResidualEvaluationUserObject`).
    - `[eqstrain_averaging_global]` (single global instance):
      ```
      type = ElkRadialAverageUpdated
      length_scale = ${nonlocal_averaging_length_scale}
      prop_name = xi
      radius = ${nonlocal_averaging_radius}
      weights = BAZANT
      execute_on = TIMESTEP_END
      # no block= -> averages over the entire domain
      ```

12. **`[Executioner]`** — `Transient`, `dt = ${dt}`, `end_time = ${end_time}`,
    `[TimeIntegrator]` `CentralDifference`, `solve_type = lumped`,
    `use_constant_mass = true`.

13. **`[Outputs]`** — Exodus + CSV + Checkpoint (intervals from params).

14. **`[BCs]`** — eight `NonReflectDashpotBC` (one per face × dof) using
    `${p_wave_speed}`/`${shear_wave_speed}`.

15. **`__VECTORPOSTPROCESSORS__`** — replaced by Phase 3.

### Edge Cases to Handle
- Per-fault `peak_shear_stress` is OUT OF SCOPE — single global patch
  inside the single `czm_mat` instance.
- 3D inputs are out of scope.

### Acceptance Criteria
- [ ] Template file exists at the path above and contains every marker
      token at least once.
- [ ] Hand-substituting markers with the elastic-app multifault example
      values + case1 CDBM physics produces a `.i` file that parses with
      `farmsquakeworx-opt --check-input -i <file>`.
- [ ] `grep "block ="` on the Materials and UserObjects portions of the
      rendered output returns 0 (no per-block restrictions baked in).
- [ ] `grep "ElkNonlocalEqstrainUpdated\|ElkRadialAverageUpdated"` returns
      exactly two matches in the template (one material + one UO).
- [ ] **[R-003]** Every name appearing in any AuxKernel `variable = ...`
      field or any VectorPostprocessor `variable = '...'` field is also
      declared in the `[AuxVariables]` block.
- [ ] **[R-005]** Every `func_*` declared in `[Functions]` is referenced
      at least once outside its own declaration site.
- [ ] **[R-006]** Row-major entry (2,2) of `static_initial_stress_tensor`
      is `func_zero`.

### Dependencies
- Depends on: Phase 0, Phase 1, Phase 1.5.
- Required by: Phase 3.

---

## Phase 3: Multifault generator for CDBM

### Goal
Create `applications/dynamiccdbm_f_app/generate_multifault.py` that consumes
a JSON config (CDBM-extended schema), calls into the elastic-app's existing
geometry/mesh helpers, and renders the Phase-2 template into a runnable `.i`.

### Files to Create
- `applications/dynamiccdbm_f_app/generate_multifault.py`

### Files to Modify
- None — the elastic-app `generate_multifault.py` is consumed read-only via
  sibling-app import.

### Detailed Requirements

1. **CLI** — identical to elastic-app:
   ```
   python generate_multifault.py config.json [--dry-run] [--output-dir DIR]
   ```
   Default output dir = `<this_script>/2d_damagebreakage_multifault`.

2. **Module imports** — at the top:
   ```python
   import os, sys
   sys.path.insert(0, os.path.abspath(
       os.path.join(os.path.dirname(__file__), "..", "dynamicelastic_app")))
   from generate_multifault import (
       validate_config, evaluate_fault_initial_stress,
       generate_geo, run_gmsh,
       extract_fault_elements, sort_fault_elements,
       build_mesh_data,
   )
   ```
   Document the import in a header comment.

3. **Config schema** — required `physics` keys: `q`, `Dc`, `mu_s`, `mu_d`,
   `density`, `lambda_o`, `shear_modulus_o`, plus all 14 CDBM-required keys
   (`xi_0`, `xi_d`, `xi_max`, `xi_min`, `chi`, `C_g`, `m1`, `m2`,
   `Cd_constant`, `C_1`, `C_2`, `beta_width`, `CdCb_multiplier`,
   `CBH_constant`).
   New optional `nonlocal` block (defaults match case1):
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
   No `blocks` key — averaging is global.

4. **`build_param_block_cdbm(config)`** — emits all parameters needed by
   the template. Float format `.10g`. Compute
   `p_wave_speed = sqrt((lambda_o + 2 mu)/rho)` and
   `shear_wave_speed = sqrt(mu/rho)`.

   From `physics`: `C_1`, `C_2`, `C_g`, `CBH_constant`, `Cd_constant`,
   `CdCb_multiplier`, `Dc`, `beta_width`, `chi`, `density`, `lambda_o`,
   `len` (= `domain.element_size`), `m1`, `m2`, `mu_d`, `mu_s`, `q`,
   `shear_modulus_o`, `xi_0`, `xi_d`, `xi_max`, `xi_min`.

   From `nonlocal`: `nonlocal_averaging_length_scale`,
   `nonlocal_averaging_radius`, `use_strain_rate_dependent_Cd`,
   `m_exponent`, `strain_rate_hat`, `cd_hat`.

   Derived: `p_wave_speed`, `shear_wave_speed`.

   From `execution`: `dt`, `end_time`.

   From `nucleation` *[corrected per R-007]*:
   - **If the entire `nucleation` block is missing**, defaults are
     `nucl_radius = 0`, `peak_shear_stress = 0`, `nucl_center = [0, 0]`.
     The CZM patch test never fires; rupture is initiated by background
     stress alone.
   - **If the block is present but a key is missing**, use case1 values
     (`nucl_radius = 1500`, `peak_shear_stress = 81.6e6`, center
     `[0, 0]`).

   From `output`: `exodus_interval` (default 40),
   `csv_interval` (default = `exodus_interval`),
   `checkpoint_interval` (default 200), `checkpoint_num_files` (default 2).

5. **`validate_cdbm_physics(config)`** — checks every required CDBM key is
   present in `config["physics"]`; raises
   `ValueError("Missing required CDBM physics key '<key>'. The unified
   ComputeDamageBreakageStress3DSlipWeakening material requires this
   parameter.")` on each absence. Then enforce numeric ranges
   *[corrected per R-008]*:
   - `xi_0`, `xi_d` ∈ `[xi_min, xi_max]` (xi_min/xi_max are required keys
     per the previous step, so they are always defined here).
   - `Cd_constant >= 0`, `CdCb_multiplier >= 0`, `chi ∈ (0, 1]`.

6. **`build_functions_block_cdbm(config)`** *[corrected per R-005]* —
   emits `[Functions]` with **four** `ConstantFunction`s only:
   - `func_initial_stress_xx` = `config.initial_stress_tensor.stress_xx`
   - `func_initial_stress_xy` = `config.initial_stress_tensor.stress_xy`
   - `func_initial_stress_yy` = `config.initial_stress_tensor.stress_yy`
   - `func_zero` = `0`

   No friction-coefficient function (CDBM CZM uses scalar from
   GlobalParams). No nucleation-patch function. No
   `func_initial_strain_zero` (the strain tensor uses `func_zero`).

7. **`build_vectorpostprocessors_cdbm(faults)`** — N `SideValueSampler`s,
   one per fault:
   ```
   variable = 'jump_strike_aux jump_normal_aux
               jump_strike_rate_aux jump_normal_rate_aux
               traction_strike_aux traction_normal_aux
               alpha_damagedvar_aux B_aux'
   ```
   Boundary derived from per-fault subdomain pair via the elastic-app
   helper. `sort_by` = `x` if `|dx| ≥ |dy|` else `y`.

8. **`render_input_file_cdbm(template_path, config, mesh_data, msh_path)`**
   — reads the Phase-2 template, calls the three `build_*` functions,
   substitutes marker tokens, returns the rendered string. Does NOT write
   to disk.

9. **`run_pipeline(config_path, output_dir, dry_run)`** — six-step
   pipeline analogous to elastic-app lines 944–1058, with the validation
   stack: `validate_config(config)` + `validate_cdbm_physics(config)` +
   `evaluate_fault_initial_stress(config)`.

10. **Public function for backend integration**:
    ```python
    def generate(config_path: str,
                 output_dir: Optional[str] = None,
                 dry_run: bool = False) -> Tuple[str, str]
    ```
    returns `(output_i_path, rendered_string)`.

11. `__main__` entry mirrors elastic-app lines 1061–1080.

### Edge Cases to Handle
- Single-fault config (1 entry in `faults`) — one CZM boundary
  `Block100_Block200`. Regression case for Phase 1.
- `mesh_file` provided in config → skip gmsh, use the supplied `.msh`.
- Config missing `nonlocal` block entirely → fall back to defaults
  (length_scale 200, radius 400, no rate-dependent Cd).
- Config missing `nucleation` block → see item 4 (zero patch, no
  spurious overstress).
- `nonlocal.averaging_radius < element_size` — emit warning that
  averaging will mostly degenerate to local values.
- `nonlocal.averaging_radius / element_size > 5` — emit warning about
  potential O(N²) cost.

### Acceptance Criteria
- [ ] `python generate_multifault.py example_config_multifault_cdbm.json
      --dry-run` runs without error and prints a non-empty `.i` to stdout.
- [ ] On a CDBM-extended single-fault config, the rendered `.i` is
      structurally equivalent (modulo whitespace) to the Phase-1 smoke-test
      file. **[R-006]** Row-major entry (2,2) of
      `static_initial_stress_tensor` is `func_zero` — `diff -w` flags zero
      lines on this row.
- [ ] `validate_cdbm_physics` raises `ValueError` with the documented
      message when each of the 14 required CDBM keys is removed from a
      working config.
- [ ] When `mesh_file` is supplied, `subprocess.run` is not called for
      `gmsh` (mock-based unit test).
- [ ] **[R-007]** With `nucleation` block omitted entirely, rendered
      `nucl_radius` and `peak_shear_stress` are both `0`.

### Dependencies
- Depends on: Phase 0, Phase 2, elastic-app generator.
- Required by: Phase 4.

---

## Phase 4: Example config, rendered output, integration test

### Goal
Provide a reference JSON config exercising the full CDBM-multifault pipeline
end-to-end, render the output into
`applications/dynamiccdbm_f_app/2d_damagebreakage_multifault/`, and add a
TestHarness `tests` spec.

### Files to Create
- `applications/dynamiccdbm_f_app/config/example_config_multifault_cdbm.json`
- `applications/dynamiccdbm_f_app/2d_damagebreakage_multifault/multifault_2d_cdbm.i`
- `applications/dynamiccdbm_f_app/2d_damagebreakage_multifault/output.geo`
- `applications/dynamiccdbm_f_app/2d_damagebreakage_multifault/output.msh`
- `applications/dynamiccdbm_f_app/2d_damagebreakage_multifault/README.md`
- `test/tests/applications/multifault_cdbm_2d/tests`
- `test/tests/applications/multifault_cdbm_2d/multifault_cdbm_2d_short.i`

### Files to Modify
- `applications/dynamiccdbm_f_app/README.md` — add a "Multi-fault pipeline"
  section.

### Detailed Requirements

1. **`example_config_multifault_cdbm.json`** — copy
   `dynamicelastic_app/config/example_config_multifault.json` (5 faults).
   Add the case1-derived `physics` block and a `nonlocal` block as listed
   in Phase 3 §3.
   `execution`: `dt = 0.00125`, `end_time = 4.5`.
   `output`: `exodus_interval = 40`, `csv_interval = 40`,
   `checkpoint_interval = 400`, `checkpoint_num_files = 2`.

2. **Render**:
   ```bash
   python applications/dynamiccdbm_f_app/generate_multifault.py \
       applications/dynamiccdbm_f_app/config/example_config_multifault_cdbm.json
   ```
   Commit `.i`, `.geo`, `.msh`.

3. **`multifault_cdbm_2d_short.i`** — copy of the rendered file with
   `end_time = 0.0125` (10 timesteps), CSV/Checkpoint outputs disabled.

4. **`tests` spec** *[corrected per R-009]*:
   ```
   [Tests]
     [multifault_cdbm_2d_short]
       type = RunApp
       input = multifault_cdbm_2d_short.i
       expect_out = 'Finished Executing'
       max_parallel = 4
       min_parallel = 1
     []
   []
   ```
   `'Finished Executing'` is the standard MOOSE completion banner — robust
   to format changes in the per-step lines.

5. **`2d_damagebreakage_multifault/README.md`** — short doc:
   - Quick-start command.
   - Schema deltas vs. elastic-app config (`physics` + `nonlocal`).
   - Note the global-nonlocal trade-off: averaging may cross fault
     boundaries; this is intentional for multifault simplicity.
   - Note that **[R-001]** the CZM rotation patch (Phase 0b) is required
     for correctness on non-horizontal faults; the example config has 4/5
     non-horizontal faults and exercises the patch.

6. **`applications/dynamiccdbm_f_app/README.md`** — append a "Multi-fault
   pipeline (generate_multifault.py)" section.

### Acceptance Criteria
- [ ] `python generate_multifault.py example_config_multifault_cdbm.json`
      writes `.geo`, `.msh`, `.i` without error.
- [ ] Rendered `.i` parses with `farmsquakeworx-opt --check-input`.
- [ ] `./run_tests --re multifault_cdbm_2d_short` passes.
- [ ] Exodus from short test contains `disp_slipweakening_x`,
      `alpha_damagedvar_aux`, `B_aux`, `eqstrain_nonlocal_aux`, and at
      least one non-zero `traction_strike_aux` value at t = end.

### Dependencies
- Depends on: Phases 0–3 (and Phase 1.5 for rotation correctness).
- Required by: nothing.

---

## Testing Strategy

| Phase | Test type | What it validates |
|---|---|---|
| 0a | Existing case1 + a tiny "empty list" `.i` | Constructor patch is back-compatible. |
| 0b | Phase 1.5 rotated-fault gold | Stress-tensor rotation produces correct fault-local tractions. |
| 1 | Manual smoke run | Empty-blocks code path in unified stress class executes. |
| 1.5 | TestHarness `CSVDiff` on 45° fault | T1_o/T2_o match analytic decomposition within 1 kPa. |
| 2 | `farmsquakeworx-opt --check-input` on hand-substituted version | Template syntax is valid MOOSE. |
| 3 | Pytest in `applications/dynamiccdbm_f_app/tests/test_generate_multifault.py` | Schema validation, helper outputs, marker substitution, missing-`nucleation` defaults, undeclared-AuxVariable detection (R-003), no-dead-Function check (R-005), σ_zz=0 check (R-006), rendered (2,2) entry (R-006). Mock `subprocess.run` for gmsh. |
| 4 | TestHarness integration test | End-to-end multi-fault pipeline runs to the `Finished Executing` banner. |

## Risk Assessment

1. **[CLOSED — was R-001]** Cross-fault averaging artefacts. With one
   global `ElkRadialAverageUpdated` (radius 400 m, length scale 200 m),
   elements near a fault's negative side will pull in `xi` samples from
   the positive side, smearing damage across the fault. Documented in
   README; tunable via the `nonlocal` config block.

2. **[CLOSED — was R-002]** `eqstrain_nonlocal` is now declared by the
   single global `ElkNonlocalEqstrainUpdated` material (Phase 2 item 10f),
   so the unconditional constructor read in
   `ComputeDamageBreakageStress3DSlipWeakening` finds a declarer. The
   earlier (incorrect) plan that dropped nonlocal entirely is no longer
   in effect.

3. **`mooseInfo` may not exist in the project's MOOSE version.** Fallback
   to `_console << "..." << std::endl;` (always available on a `Material`
   subclass).

4. **`Physics/SolidMechanics/CohesiveZone` syntax** must coexist with
   `Physics/SolidMechanics/QuasiStatic`; both `case2/case4` 3D inputs use
   this exact pattern and run, so this is considered safe.

5. **`SubdomainPerElementGenerator` element-id ordering** depends on gmsh
   internals. *Mitigation*: commit the rendered `.msh` so the regression
   test does not depend on the user's local gmsh version.

6. **Nucleation overstress with multiple faults**: the
   `SlipWeakeningFrictionczm2dCDBM` `nucl_center` patch is global to the
   one material instance; if the patch is placed away from any fault, no
   rupture nucleates. *Mitigation*: add a Phase-3 sanity check
   `validate_nucleation_inside_a_fault(config)` that warns (not errors)
   if the patch center is more than `nucl_radius` from any fault segment.

7. **CZM rotation convention parity**: Phase 0b's rotation must match
   `SlipWeakeningFrictionczm2dParametricStudy` byte-for-byte (sign on
   T2_o, choice of `local_normal` direction). If conventions differ, the
   rendered multifault input will produce results inconsistent with the
   elastic baseline. *Mitigation*: review the sibling implementation
   directly during the Phase-0b code change; the Phase-1.5 gold acts as
   the lock.

## Compatibility Notes (Review Findings Closed)

| Finding | Severity | Where addressed |
|---|---|---|
| **R-001** CZM has no rotation; non-horizontal faults silently wrong | CRITICAL | Phase 0b + Phase 1.5 |
| **R-002** `eqstrain_nonlocal` never declared if nonlocal dropped | CRITICAL | Approach changed: nonlocal is RETAINED (one global instance). Phase 2 item 10f declares the property. Risk #2 closed. |
| **R-003** AuxVariable names inconsistent; VPP refs undeclared vars | CRITICAL | Phase 2 item 3 enumerates AuxVariables explicitly; Phase 2 item 8 spells `variable = ...` for every kernel; Phase 2 acceptance criterion checks consistency. |
| **R-004** Phase 1 leaves dangling `xi_aux` in `show` list | MODERATE | Obsolete: Phase 1 is now a smoke test that does NOT delete `xi_aux` (it leaves case1 untouched except for the single-line removal). |
| **R-005** "six functions" but only five listed; dead `func_initial_strain_zero` | MODERATE | Phase 2 item 7 and Phase 3 item 6 both say **four** ConstantFunctions; `func_initial_strain_zero` removed; acceptance criterion enforces no-dead-Function. |
| **R-006** σ_zz = σ_yy in stress tensor breaks case1 parity | MODERATE | Phase 2 item 10 corrects (2,2) → `func_zero`; Phase 2 + Phase 3 acceptance criteria verify. |
| **R-007** Contradictory `nucleation`-missing defaults | MODERATE | Phase 3 item 4 unifies on the safe default (zero patch). |
| **R-008** `xi_min`/`xi_max` "default if not given" contradicts required | LOW | Phase 3 item 5 drops the "if not given" clause. |
| **R-009** Fragile `expect_out` time-step string | LOW | Phase 4 item 4 uses `'Finished Executing'`. |

# Regression Tests Design for ALL farmsquakeworx Source Files

Created by Chunhui Zhao, Mar 6th, 2026

## Goal

Create tests for **every** custom MOOSE object so that any future source code change is detected. Two test approaches:

1. **Unit tests** (`unit/src/`) — GoogleTest C++ for Functions and standalone math
2. **Integration tests** (`test/tests/`) — MOOSE TestHarness with `.i` files + gold file comparison for Materials, AuxKernels, BCs, Kernels, InterfaceKernels, UserObjects

---

## Complete Source File Inventory (37 classes)

### Functions (7) — Unit tests
| # | Class | File |
|---|-------|------|
| 1 | `InitialShearStressTPV2053d` | `src/functions/slipweakeningczm/` |
| 2 | `InitialCohesionCDBMv2` | `src/functions/slipweakeningczm/` |
| 3 | `ForcedRuptureTimeCDBMv2` | `src/functions/slipweakeningczm/` |
| 4 | `InitialStressStrainTPV26` | `src/functions/slipweakeningczm/` |
| 5 | `InitialStaticFrictionCoeff` | `src/functions/cdbm/` |
| 6 | `InitialStrikeShearStressPerturbRSF2D` | `src/functions/ratestate/` |
| 7 | `InitialStrikeShearStressPerturbRSF3D` | `src/functions/ratestate/` |

### Materials (18) — Integration tests
| # | Class | File |
|---|-------|------|
| 8 | `SlipWeakeningFrictionczm2d` | `src/materials/slipweakeningczm/` |
| 9 | `SlipWeakeningFrictionczm3d` | `src/materials/slipweakeningczm/` |
| 10 | `SlipWeakeningFrictionczm2dParametricStudy` | `src/materials/slipweakeningczm/` |
| 11 | `SlipWeakeningFrictionczm3dCDBM` | `src/materials/slipweakeningczm/` |
| 12 | `ComputeGeneralDamageBreakageStressBase3D` | `src/materials/cdbm3dbase/` |
| 13 | `ComputeDamageBreakageStressBase3D` | `src/materials/cdbm3dbase/` |
| 14 | `ComputeDamageBreakageStress3DSlipWeakening` | `src/materials/cdbm3d/` |
| 15 | `ComputeDamageBreakageStress3DSlipWeakeningNonlocal` | `src/materials/cdbm3d/` |
| 16 | `ComputeDamageBreakageStress3DStatic` | `src/materials/cdbm3d/` |
| 17 | `ComputeXi` | `src/materials/helper/` |
| 18 | `ElkNonlocalEqstrainUpdated` | `src/materials/nonlocaldamage/` |
| 19 | `CZMComputeLocalTractionBaseRSF2D` | `src/materials/ratestate/` |
| 20 | `CZMComputeLocalTractionTotalBaseRSF2D` | `src/materials/ratestate/` |
| 21 | `RateStateFrictionLaw2D` | `src/materials/ratestate/` |
| 22 | `CZMComputeLocalTractionBaseRSF3D` | `src/materials/ratestate/` |
| 23 | `CZMComputeLocalTractionTotalBaseRSF3D` | `src/materials/ratestate/` |
| 24 | `RateStateFrictionLaw3D` | `src/materials/ratestate/` |

### AuxKernels (4) — Integration tests
| # | Class | File |
|---|-------|------|
| 25 | `FarmsMaterialRealAux` | `src/auxkernels/core/` |
| 26 | `FDCompVarRate` | `src/auxkernels/core/` |
| 27 | `CompVarRate` | `src/auxkernels/helper/` |
| 28 | `ScaleVarAux` | `src/auxkernels/ratestate/` |

### BCs (2) — Integration tests
| # | Class | File |
|---|-------|------|
| 29 | `NonReflectDashpotBC` | `src/bcs/core/` |
| 30 | `NonReflectDashpotBC3d` | `src/bcs/core/` |

### Kernels (1) — Integration tests
| # | Class | File |
|---|-------|------|
| 31 | `StiffPropDamping` | `src/kernels/core/` |

### InterfaceKernels (3) — Integration tests
| # | Class | File |
|---|-------|------|
| 32 | `RateStateInterfaceKernelGlobalx` | `src/interfacekernels/ratestate/` |
| 33 | `RateStateInterfaceKernelGlobaly` | `src/interfacekernels/ratestate/` |
| 34 | `RateStateInterfaceKernelGlobalz` | `src/interfacekernels/ratestate/` |

### UserObjects (2) — Integration tests
| # | Class | File |
|---|-------|------|
| 35 | `ResidualEvaluationUserObject` | `src/userobjects/core/` |
| 36 | `ElkRadialAverageUpdated` | `src/userobjects/nonlocaldamage/` |
| 37 | `ThreadedElkRadialAverageLoopUpdated` | (helper, tested via #36) |

### Standalone Math (4) — Unit tests
| # | Topic | Tests |
|---|-------|-------|
| 38 | Coordinate rotation (FarmsMaterialRealAux math) | `unit/src/CoordinateRotationTest.C` |
| 39 | Xi computation (ComputeXi math) | `unit/src/XiComputationTest.C` |
| 40 | Slip weakening friction (SW law math) | `unit/src/SlipWeakeningFrictionLawTest.C` |
| 41 | Damage-breakage mechanics (CDBM math) | `unit/src/DamageBreakageMathTest.C` |

---

## Phase 1: Unit Tests (`unit/src/`)

### 1.1 `unit/src/InitialShearStressTPV2053dTest.C`

Tests for `InitialShearStressTPV2053d` — spatial stress patches for TPV205 3D benchmark.

Uses `MooseObjectUnitTest` fixture:
```cpp
class InitialShearStressTPV2053dTest : public MooseObjectUnitTest {
  InitialShearStressTPV2053dTest() : MooseObjectUnitTest("farmsquakeworxApp") {}
};
```

| Test | Point (x, y, z) | Expected Value |
|------|-----------------|----------------|
| `CenterPatch` | (0, 0, -7500) | 81.6e6 |
| `LeftPatch` | (-7500, 0, -7500) | 78.0e6 |
| `RightPatch` | (7500, 0, -7500) | 62.0e6 |
| `Background` | (0, 0, 0) | 70.0e6 |
| `PatchBoundaryInside` | (1500, 0, -6000) | 81.6e6 |
| `PatchBoundaryOutside` | (1501, 0, -6000) | 70.0e6 |
| `TimeIndependent` | same point at t=0 and t=100 | same value |

### 1.2 `unit/src/InitialCohesionCDBMv2Test.C`

Tests for `InitialCohesionCDBMv2` — piecewise linear cohesion vs. depth.

Params: `depth=1000, slope=5.0, min_cohesion=2.0`

| Test | z-coordinate | Expected Value |
|------|-------------|----------------|
| `AtSurface` | 0 | min_cohesion*1e6 + slope*1e6*depth = 7.0e6 |
| `AtMaxDepth` | -1000 | min_cohesion*1e6 = 2.0e6 |
| `BelowMaxDepth` | -2000 | 2.0e6 (clamped) |
| `MidDepth` | -500 | 4.5e6 |
| `NegativeZ` | -500 | same as abs(z)=500 |

### 1.3 `unit/src/ForcedRuptureTimeCDBMv2Test.C`

Tests for `ForcedRuptureTimeCDBMv2` — Gaussian rupture time function.

Params: `loc_x=0, loc_y=0, loc_z=-7500, r_crit=3000, Vs=3464`

| Test | Point | Expected |
|------|-------|----------|
| `AtHypocenter` | (0, 0, -7500) | 0 |
| `OutsideCritical` | (5000, 0, -7500) | 1e9 |
| `AtCritical` | (3000, 0, -7500) | 1e9 |
| `Monotonicity` | r1 < r2 < r_crit | T(r1) < T(r2) |
| `Symmetry` | (1000,0,-7500) vs (-1000,0,-7500) | equal |

### 1.4 `unit/src/InitialStressStrainTPV26Test.C`

Tests for `InitialStressStrainTPV26` — complex stress/strain initialization with tapering and overpressure.

**Error validation tests** (EXPECT_THROW):
| Test | Config | Expected Error |
|------|--------|---------------|
| `ErrorBothStressAndStrain` | stress=true, strain=true | mooseError |
| `ErrorFluidPressureWithStress` | fluid=true, stress=true | mooseError |
| `ErrorTaperingBadDepths` | tapering=true, A>=B | mooseError |
| `ErrorOverpressureBadDepths` | overpressure=true, A>=B | mooseError |
| `ErrorLowEffNoOverpressure` | loweff=true, overpressure=false | mooseError |
| `ErrorLambdaPPRange` | lambda_pp=1.5 | mooseError |

**Value tests** (fixed params: lambda_o=32.04e9, mu=32.04e9, rho_rock=2670, rho_fluid=1000, g=9.8, bxx=0.6, byy=1.0, bxy=0.4):
| Test | z | Mode | Verify |
|------|---|------|--------|
| `StressZZ` | -5000 | stress(3,3) | -rho_rock*g*|z| + Pf |
| `FluidPressure` | -5000 | fluid_pressure | rho_fluid*g*|z| |
| `StrainXX` | -5000 | strain(1,1) | Hooke's law inversion |
| `TaperingAboveA` | -100 | stress | Omega=1 (full deviatoric) |
| `TaperingBelowB` | -20000 | stress | Omega=0 (pure lithostatic) |
| `OverpressureHydrostatic` | -100 | fluid_pressure | rho_fluid*g*|z| |
| `OverpressureBelowB` | -20000 | fluid_pressure | rho_rock*g*|z| |
| `LowEffBelowB` | -20000 | fluid_pressure | lambda_pp*rho*g*|z| |

### 1.5 `unit/src/InitialStaticFrictionCoeffTest.C`

Tests for `InitialStaticFrictionCoeff` — spatial friction patches.

Default params: patch [-15e3, 15e3] x [-15e3, 0], mu_s_patch=0.677, mu_s_outside=10000

| Test | Point | Expected |
|------|-------|----------|
| `InsidePatch` | (0, -7500, 0) | 0.677 |
| `OutsidePatch` | (0, 5000, 0) | 10000 |
| `PatchBoundary` | boundary point | verify correct <= behavior |
| `CustomParams` | custom patch coords | custom mu_s |

### 1.6 `unit/src/InitialStrikeShearStressPerturbRSF2DTest.C`

Tests for `InitialStrikeShearStressPerturbRSF2D` — spatial-temporal perturbation.

Hardcoded params: T1_perturb=25e6, R=3000, T=1.0

| Test | (t, x, z) | Expected |
|------|-----------|----------|
| `ZeroAtTimeZero` | t=0, r=0 | 0 (G(0)=0) |
| `ZeroOutsideR` | t=10, r=4000 | 0 (F=0) |
| `SteadyAfterT` | t=5.0, r=0 | 25e6 * F(0,3000) |
| `Monotonic` | t=5.0, r=500 vs r=1000 | val(500) > val(1000) |

### 1.7 `unit/src/InitialStrikeShearStressPerturbRSF3DTest.C`

Same pattern as 2D but verify 3D distance calculation (x, z coords).

### 1.8 `unit/src/CoordinateRotationTest.C`

Standalone `TEST()` (no fixture needed) testing the FarmsMaterialRealAux rotation math.

The AuxKernel applies: `normal = -_normals[qp]`, `tangent = (normal_y, -normal_x)`, then projects global quantities to local via dot products.

| Test | Interface Normal | Verify |
|------|-----------------|--------|
| `HorizontalFault` | (0,1) | tangent=(-1,0) after sign flip |
| `VerticalFault` | (1,0) | tangent=(0,1) after sign flip |
| `Angle45` | (s,s) where s=1/sqrt(2) | shear/normal projections of known jump |
| `Orthogonality` | 12 angles | dot(n,t)=0 for all |
| `UnitLength` | 12 angles | |n|=1, |t|=1 |
| `FullRotation` | any angle | local_shear^2+local_normal^2 = global^2 |
| `TractionRotation` | 45 deg | local traction from known global traction |

### 1.9 `unit/src/XiComputationTest.C`

Standalone `TEST()` testing ComputeXi strain invariant ratio formulas.

Formula: xi = I1 / sqrt(I2) where I1 = trace(eps), I2 = eps:eps

| Test | Strain State | Expected xi |
|------|-------------|------------|
| `PureVolumetric` | diag(a,a,a) | sqrt(3) |
| `PureShear` | diag(a,-a,0) | 0 |
| `UniaxialCompression` | diag(-a,0,0) | -1 |
| `InitialValue` | zero strain | -sqrt(3) (default) |
| `WithOffDiagonal` | known eps_ij | hand-computed xi |
| `I1Computation` | diag(1e-3, 2e-3, 3e-3) | 6e-3 |
| `I2Computation` | diag(1e-3, 2e-3, 3e-3) | 14e-6 |

### 1.10 `unit/src/SlipWeakeningFrictionLawTest.C`

Standalone `TEST()` testing slip weakening friction law math extracted from all 4 CZM materials.

| Test | Inputs | Verify |
|------|--------|--------|
| `FrictionAtZeroSlip` | slip=0 | mu = mu_s |
| `FrictionAtDc` | slip=Dc | mu = mu_d |
| `FrictionLinear` | slip=Dc/2 | mu = (mu_s+mu_d)/2 |
| `FrictionBeyondDc` | slip=2*Dc | mu = mu_d (clamped) |
| `OpenFault` | T2>=0 | tau_f = 0 |
| `SignConvention` | T1>0, slip>Dc | T1 = +tau_f (positive) |
| `SignConventionNeg` | T1<0, slip>Dc | T1 = -tau_f (negative) |
| `StuckCondition` | |T1| < tau_f | T1 unchanged |
| `3DSlipMagnitude` | t,d components | slip_total = sqrt(t^2+d^2) |
| `3DTractionProjection` | |T|>tau_f | rescaled to tau_f, preserving direction |

### 1.11 `unit/src/DamageBreakageMathTest.C`

Standalone `TEST()` testing CDBM math formulas from ComputeDamageBreakageStress3DSlipWeakening.

| Test | Formula | Verify |
|------|---------|--------|
| `GammaR` | computegammar() with known xi_0, lambda, mu | expected gamma_r value |
| `AlphaCritical` | alphacr_root1/root2() | known inputs -> expected alpha_cr |
| `DamageEvolution` | dalpha/dt = (1-B)*Cd*I2*(xi-xi_0) | sign, magnitude for xi>xi_0 and xi<xi_0 |
| `DamageThreshold` | alpha clamped to [0, 1] | verify clamping |
| `BreakageEvolution` | dB/dt with logistic probability | threshold at xi_d |
| `StressBlend` | sigma = (1-B)*sigma_s + B*sigma_b | B=0 -> solid only, B=1 -> granular only |
| `StrainRateCd` | Cd(eps_dot) formula | below threshold -> Cd_constant, above -> power law |
| `NodeMassTRI3` | rho*sqrt(3)/4*L^2/3 | known rho=2670, L=100 |
| `NodeMassQUAD4` | rho*L^2/4*2 | known rho=2670, L=100 |
| `NodeMassTET4` | rho*sqrt(2)*L^3/12/4*6 | known rho=2670, L=100 |
| `NodeMassHEX8` | rho*L^3/8*4 | known rho=2670, L=100 |
| `AreaTET4` | sqrt(3)*L^2/4/3*6 | known L=100 |
| `AreaHEX8` | L^2/4*4 | known L=100 |
| `Coefficients` | a0,a1,a2,a3 from computecoefficients() | known gamma_r |

---

## Phase 2: Integration Tests (`test/tests/`)

Each test uses a small mesh, few timesteps, and produces gold files (Exodus `.e` or CSV `.csv`).
Any source code change that alters numerical output will cause the gold-file diff to fail.

### Directory Structure

```
test/tests/
├── auxkernels/
│   ├── farms_material_real_aux/
│   │   ├── tests
│   │   ├── test_farms_material_real_aux.i
│   │   └── gold/
│   ├── fd_comp_var_rate/
│   │   ├── tests
│   │   ├── test_fd_comp_var_rate.i
│   │   └── gold/
│   ├── comp_var_rate/
│   │   ├── tests
│   │   ├── test_comp_var_rate.i
│   │   └── gold/
│   └── scale_var_aux/
│       ├── tests
│       ├── test_scale_var_aux.i
│       └── gold/
├── bcs/
│   ├── non_reflect_dashpot_2d/
│   │   ├── tests
│   │   ├── test_dashpot_2d.i
│   │   └── gold/
│   └── non_reflect_dashpot_3d/
│       ├── tests
│       ├── test_dashpot_3d.i
│       └── gold/
├── kernels/
│   └── stiff_prop_damping/
│       ├── tests
│       ├── test_stiff_prop_damping.i
│       └── gold/
├── materials/
│   ├── slip_weakening_czm_2d/
│   │   ├── tests
│   │   ├── test_sw_czm_2d.i
│   │   └── gold/
│   ├── slip_weakening_czm_3d/
│   │   ├── tests
│   │   ├── test_sw_czm_3d.i
│   │   └── gold/
│   ├── slip_weakening_czm_2d_parametric/
│   │   ├── tests
│   │   ├── test_sw_czm_2d_param.i
│   │   └── gold/
│   ├── slip_weakening_czm_3d_cdbm/
│   │   ├── tests
│   │   ├── test_sw_czm_3d_cdbm.i
│   │   └── gold/
│   ├── compute_xi/
│   │   ├── tests
│   │   ├── test_compute_xi.i
│   │   └── gold/
│   ├── cdbm_3d_slip_weakening/
│   │   ├── tests
│   │   ├── test_cdbm_3d_sw.i
│   │   └── gold/
│   ├── cdbm_3d_static/
│   │   ├── tests
│   │   ├── test_cdbm_3d_static.i
│   │   └── gold/
│   ├── cdbm_3d_nonlocal/
│   │   ├── tests
│   │   ├── test_cdbm_3d_nonlocal.i
│   │   └── gold/
│   ├── rate_state_2d/
│   │   ├── tests
│   │   ├── test_rsf_2d.i
│   │   └── gold/
│   ├── rate_state_3d/
│   │   ├── tests
│   │   ├── test_rsf_3d.i
│   │   └── gold/
│   └── nonlocal_eqstrain/
│       ├── tests
│       ├── test_nonlocal_eqstrain.i
│       └── gold/
├── interfacekernels/
│   └── rate_state_interface/
│       ├── tests
│       ├── test_rsf_interface_2d.i
│       ├── test_rsf_interface_3d.i
│       └── gold/
└── userobjects/
    ├── residual_evaluation/
    │   ├── tests
    │   ├── test_residual_eval.i
    │   └── gold/
    └── radial_average/
        ├── tests
        ├── test_radial_average.i
        └── gold/
```

### 2.1 AuxKernel Integration Tests

#### `test/tests/auxkernels/farms_material_real_aux/`

**test_farms_material_real_aux.i** — 2-element CZM mesh, apply known displacement, verify all 10 local quantities.

```
[Mesh]
  2x1 QUAD4, BreakMeshByBlock, horizontal interface
[Variables]
  disp_x, disp_y
[AuxVariables]
  local_shear_jump, local_normal_jump, local_shear_jump_rate, local_normal_jump_rate
  local_shear_traction, local_normal_traction, normal_x, normal_y, tangent_x, tangent_y
  resid_x, resid_y, disp_slipweakening_x/y, vel_slipweakening_x/y
  resid_slipweakening_x/y, mu_s, ini_shear_stress, ini_normal_stress
[Materials]
  ComputeIsotropicElasticityTensor + ComputeLinearElasticStress + density
  SlipWeakeningFrictionczm2dParametricStudy (declares total_shear_traction)
[AuxKernels]
  10 FarmsMaterialRealAux blocks (one per local quantity)
  ProjectionAux, CompVarRate, TagVectorAux, FunctionAux
[BCs]
  Prescribed displacement to create known jump
[Executioner]
  Transient, CentralDifference lumped, 2 timesteps, dt=0.001
[Outputs]
  CSV with VectorPostprocessor (SideValueSampler on interface)
```

**tests file:**
```
[Tests]
  [horizontal_fault]
    type = CSVDiff
    input = test_farms_material_real_aux.i
    csvdiff = 'test_farms_material_real_aux_out_fault_0001.csv'
    recover = false
    mesh_mode = 'REPLICATED'
    requirement = "FarmsMaterialRealAux shall correctly rotate global CZM quantities to local fault-aligned coordinates."
  []
[]
```

#### `test/tests/auxkernels/fd_comp_var_rate/`

**test_fd_comp_var_rate.i** — Verify finite-difference rate computation = (val - val_older) / dt

```
[Mesh] GeneratedMesh 2x2
[Variables] u (prescribed via FunctionDirichletBC, linear in time)
[AuxVariables] rate_fd (CONSTANT MONOMIAL)
[AuxKernels] FDCompVarRate coupled=u
[Postprocessors] ElementAverageValue of rate_fd
[Executioner] Transient, 3 steps, dt=0.1
[Outputs] CSV
```

**tests file:**
```
[Tests]
  [fd_rate]
    type = CSVDiff
    input = test_fd_comp_var_rate.i
    csvdiff = 'test_fd_comp_var_rate_out.csv'
    requirement = "FDCompVarRate shall compute time derivative via finite difference (val - val_older) / dt."
  []
[]
```

#### `test/tests/auxkernels/comp_var_rate/`

**test_comp_var_rate.i** — Verify coupledDot rate computation. Same structure as FDCompVarRate.

#### `test/tests/auxkernels/scale_var_aux/`

**test_scale_var_aux.i** — Verify scaling: result = coupled / scale

```
[Variables] u (primary), s (scale factor)
[AuxKernels] ScaleVarAux coupled=u scale=s
[Postprocessors] ElementAverageValue of scaled output
```

### 2.2 BC Integration Tests

#### `test/tests/bcs/non_reflect_dashpot_2d/`

**test_dashpot_2d.i** — 2D elastic wave propagation with absorbing (Lysmer) boundaries.

```
[Mesh] GeneratedMesh dim=2, nx=10, ny=10
[Variables] disp_x, disp_y
[Kernels]
  InertialForce (x,y)
  SolidMechanics QuasiStatic (SMALL strain, PLANE_STRAIN)
[Materials]
  ComputeIsotropicElasticityTensor (lambda, shear_modulus)
  ComputeLinearElasticStress
  GenericConstantMaterial (density)
[BCs]
  NonReflectDashpotBC on all 4 boundaries (component=0,1)
  + InitialCondition or FunctionDirichletBC for velocity perturbation
[Executioner] Transient, CentralDifference lumped, dt=small, 10 steps
[Outputs] Exodus
```

Verifies: wave exits domain without spurious reflections. Gold file captures displacement field.

**tests file:**
```
[Tests]
  [dashpot_2d]
    type = Exodiff
    input = test_dashpot_2d.i
    exodiff = 'test_dashpot_2d_out.e'
    recover = false
    requirement = "NonReflectDashpotBC shall absorb outgoing P and S waves at 2D boundaries."
  []
[]
```

#### `test/tests/bcs/non_reflect_dashpot_3d/`

Same but 3D (3x3x3 mesh, NonReflectDashpotBC3d on all 6 faces, 3 displacement components).

### 2.3 Kernel Integration Tests

#### `test/tests/kernels/stiff_prop_damping/`

**test_stiff_prop_damping.i** — Verify stiffness-proportional Rayleigh damping.

```
[Mesh] GeneratedMesh dim=2, nx=4, ny=4
[Variables] disp_x, disp_y
[Kernels]
  InertialForce (x,y)
  SolidMechanics QuasiStatic
  StiffPropDamping (q=0.1, component=0,1)
[Materials] Elasticity + density
[BCs] Fixed bottom + initial velocity on top
[Executioner] Transient, CentralDifference, 5 steps
[Postprocessors] NodalMaxValue of disp_y (should decay with damping)
[Outputs] CSV + Exodus
```

Gold file captures: damped displacement field (amplitude should decrease over time).

### 2.4 Material Integration Tests

#### `test/tests/materials/slip_weakening_czm_2d/`

**test_sw_czm_2d.i** — Full 2D slip weakening CZM on explicit time integration.

```
[Mesh] 2x1 QUAD4, BreakMeshByBlock creates horizontal interface
[GlobalParams] Dc=0.4, T2_o=120e6, mu_d=0.525, len=elementsize, q=0.1
[Variables] disp_x, disp_y
[AuxVariables]
  resid_x, resid_y, resid_slipweakening_x/y, disp_slipweakening_x/y
  vel_slipweakening_x/y, mu_s, ini_shear_stress
[Physics/SolidMechanics/CohesiveZone] czm on interface (SMALL strain)
[Physics/SolidMechanics/QuasiStatic] SMALL strain, PLANE_STRAIN
[Materials]
  ComputeIsotropicElasticityTensor
  ComputeLinearElasticStress
  GenericConstantMaterial(density=2670)
  SlipWeakeningFrictionczm2d
[Kernels] InertialForce + StiffPropDamping
[AuxKernels] ProjectionAux, CompVarRate, TagVectorAux, FunctionAux
[Executioner] Transient, CentralDifference lumped, dt=0.001, 5 steps
[Outputs] Exodus + CSV (VectorPostprocessor on interface)
```

Gold file captures: interface traction and displacement jump evolution over 5 timesteps.

#### `test/tests/materials/slip_weakening_czm_3d/`

Same pattern but 3D:
- 2x1x1 HEX8 mesh, SlipWeakeningFrictionczm3d
- 3 displacement components, TET4 or HEX8 element types
- Additional dip direction variables

#### `test/tests/materials/slip_weakening_czm_2d_parametric/`

Tests `SlipWeakeningFrictionczm2dParametricStudy` with multiple sub-tests:

```
[Tests]
  [default_mode]
    type = CSVDiff
    input = test_sw_czm_2d_param.i
    csvdiff = 'test_sw_czm_2d_param_out.csv'
    requirement = "SlipWeakeningFrictionczm2dParametricStudy default mode matches SlipWeakeningFrictionczm2d."
  []
  [fractal_mode]
    type = CSVDiff
    input = test_sw_czm_2d_param.i
    cli_args = "Materials/czm_mat/use_fractal_shear_stress=true"
    csvdiff = 'test_sw_czm_2d_param_fractal_out.csv'
    prereq = default_mode
    requirement = "Fractal shear stress mode activates different initial stress pattern."
  []
  [nucleation_patch]
    type = CSVDiff
    input = test_sw_czm_2d_param.i
    cli_args = "Materials/czm_mat/use_fractal_shear_stress=true Materials/czm_mat/nucl_center='0 0 0' Materials/czm_mat/nucl_radius=1000 Materials/czm_mat/peak_shear_stress=85e6"
    csvdiff = 'test_sw_czm_2d_param_nucl_out.csv'
    prereq = default_mode
    requirement = "Nucleation patch overrides shear stress within specified radius."
  []
[]
```

#### `test/tests/materials/slip_weakening_czm_3d_cdbm/`

Tests `SlipWeakeningFrictionczm3dCDBM` with:
- Overstress nucleation mode (default, `use_forced_rupture=false`)
- Forced rupture mode (`use_forced_rupture=true`)
- Cohesion + fluid pressure coupling via AuxVariables

#### `test/tests/materials/compute_xi/`

**test_compute_xi.i** — Verify strain invariant ratio xi under known strain state.

```
[Mesh] GeneratedMesh dim=3, nx=2, ny=2, nz=2
[Variables] disp_x, disp_y, disp_z
[Materials]
  ComputeIsotropicElasticityTensor
  ComputeSmallStrain
  ComputeLinearElasticStress
  ComputeXi
[BCs]
  Prescribed displacement BCs to create known strain state
  (e.g., uniform compression: disp_z = -epsilon * z on top face)
[Postprocessors]
  ElementAverageValue of strain_invariant_ratio
  ElementAverageValue of I1_initial
  ElementAverageValue of I2_initial
[Executioner] Steady
[Outputs] CSV
```

#### `test/tests/materials/cdbm_3d_slip_weakening/`

**test_cdbm_3d_sw.i** — CDBM damage-breakage material under dynamic loading.

```
[Mesh] GeneratedMesh dim=3, nx=2, ny=2, nz=2
[Variables] disp_x, disp_y, disp_z
[Materials]
  ComputeDamageBreakageStress3DSlipWeakening
  (all 19+ parameters: lambda_o, shear_modulus_o, xi_0, xi_d, xi_min, xi_max,
   chi, C_g, m1, m2, Cd_constant, C_1, C_2, beta_width, CdCb_multiplier, CBH_constant)
[BCs]
  Prescribed compression + shear loading to trigger damage
[Postprocessors]
  ElementAverageValue of: alpha_damagedvar, breakage_B, stress_xx, stress_yy, stress_zz, xi
[Executioner] Transient, dt=small, 5 steps
[Outputs] CSV
```

Gold captures: damage (alpha) and breakage (B) evolution, stress-strain response.

#### `test/tests/materials/cdbm_3d_static/`

Same structure but using `ComputeDamageBreakageStress3DStatic` for quasi-static solver.

#### `test/tests/materials/cdbm_3d_nonlocal/`

Tests `ComputeDamageBreakageStress3DSlipWeakeningNonlocal` with nonlocal averaging:

```
[Mesh] GeneratedMesh dim=3, nx=4, ny=4, nz=4 (enough elements for spatial averaging)
[UserObjects]
  ElkRadialAverageUpdated (prop_name=epsilon_eq, radius=R, weights=constant)
[Materials]
  ComputeDamageBreakageStress3DSlipWeakeningNonlocal (use_nonlocal_eqstrain=true)
  ElkNonlocalEqstrainUpdated (average_UO=radial_avg)
[Postprocessors]
  ElementAverageValue of local vs. nonlocal equivalent strain
[Outputs] CSV
```

#### `test/tests/materials/rate_state_2d/`

**test_rsf_2d.i** — Rate-state friction 2D with custom interface kernels.

```
[Mesh] 2x1 QUAD4 with interface (BreakMeshByBlock)
[Variables] disp_x, disp_y
[InterfaceKernels]
  RateStateInterfaceKernelGlobalx (boundary=interface)
  RateStateInterfaceKernelGlobaly (boundary=interface)
[Materials]
  ComputeIsotropicElasticityTensor + ComputeLinearElasticStress + density
  RateStateFrictionLaw2D (f_o=0.6, rsf_a=0.008, rsf_b=0.012, rsf_L=0.02, etc.)
[BCs]
  Dirichlet on outer boundaries + NonReflectDashpotBC
[Executioner] Transient, Newmark or implicit, dt=small, 5 steps
[Postprocessors]
  InterfaceAverageValue of slip_rate, state_variable, traction_strike, traction_normal
[Outputs] CSV
```

Gold captures: slip rate evolution, state variable evolution, traction history.

#### `test/tests/materials/rate_state_3d/`

Same but 3D with `RateStateFrictionLaw3D` + `RateStateInterfaceKernelGlobalz`.

#### `test/tests/materials/nonlocal_eqstrain/`

Tests `ElkNonlocalEqstrainUpdated` material property update from `ElkRadialAverageUpdated` UO.

### 2.5 InterfaceKernel Integration Tests

#### `test/tests/interfacekernels/rate_state_interface/`

**test_rsf_interface_2d.i** — Tests RateStateInterfaceKernelGlobalx + Globaly together.
**test_rsf_interface_3d.i** — Tests all 3 (x+y+z) interface kernels together.

These share setup with rate-state material tests but focus on verifying the interface kernel residual contributions. The gold file captures the displacement field on both sides of the interface.

### 2.6 UserObject Integration Tests

#### `test/tests/userobjects/residual_evaluation/`

**test_residual_eval.i** — Verify ResidualEvaluationUserObject recomputes residual with restore_tag.

```
[Problem] extra_tag_vectors = 'restore_tag'
[Variables] disp_x, disp_y
[Kernels] SolidMechanics + InertialForce (extra_vector_tags = 'restore_tag')
[AuxVariables] resid_x, resid_y
[AuxKernels]
  TagVectorAux (vector_tag='restore_tag', v='disp_x', variable='resid_x')
  TagVectorAux (vector_tag='restore_tag', v='disp_y', variable='resid_y')
[UserObjects]
  ResidualEvaluationUserObject (vector_tag='restore_tag', force_preaux=true)
[Postprocessors] NodalMaxValue of resid_x, resid_y
[Executioner] Transient, CentralDifference, 3 steps
[Outputs] CSV
```

#### `test/tests/userobjects/radial_average/`

**test_radial_average.i** — Verify ElkRadialAverageUpdated spatial averaging with different weight types.

```
[Mesh] GeneratedMesh dim=3, nx=10, ny=10, nz=1
[Materials]
  GenericFunctionMaterial (prop_names=test_prop, prop_values='x+y') — spatially varying
[UserObjects]
  ElkRadialAverageUpdated (prop_name=test_prop, radius=0.2, weights=constant, length_scale=0.1)
[Materials]
  ElkNonlocalEqstrainUpdated (average_UO=radial_avg)
[Postprocessors]
  ElementAverageValue of local test_prop
  ElementAverageValue of nonlocal averaged version
[Executioner] Transient, 2 steps
[Outputs] CSV
```

Multiple sub-tests for each weight type:
```
[Tests]
  [constant_weights]
    type = CSVDiff
    input = test_radial_average.i
    csvdiff = 'test_radial_average_constant_out.csv'
    cli_args = "UserObjects/radial_avg/weights=constant"
  []
  [linear_weights]
    type = CSVDiff
    input = test_radial_average.i
    csvdiff = 'test_radial_average_linear_out.csv'
    cli_args = "UserObjects/radial_avg/weights=linear"
  []
  [cosine_weights]
    type = CSVDiff
    input = test_radial_average.i
    csvdiff = 'test_radial_average_cosine_out.csv'
    cli_args = "UserObjects/radial_avg/weights=cosine"
  []
[]
```

### 2.7 `tests` File Format

Each directory's `tests` file follows MOOSE TestHarness convention:

```
[Tests]
  [test_name]
    type = Exodiff              # or CSVDiff or RunException
    input = 'test_input.i'
    exodiff = 'test_input_out.e'  # or csvdiff = '...csv'
    recover = false
    mesh_mode = 'REPLICATED'    # required for CZM/BreakMeshByBlock tests
    requirement = "Description of what this test verifies"
  []
[]
```

For exception tests:
```
  [error_test]
    type = RunException
    input = 'test_input.i'
    cli_args = "Materials/mat/bad_param=true"
    expect_err = "expected error message pattern"
    requirement = "Object shall error when invalid parameters are provided."
  []
```

---

## Phase 3: Makefile Updates

### `unit/Makefile`

Enable SOLID_MECHANICS module (needed for CZM base classes):

```makefile
SOLID_MECHANICS := yes
```

Current Makefile has `TENSOR_MECHANICS := no` — change to `yes` (SOLID_MECHANICS is the new name in latest MOOSE, but `TENSOR_MECHANICS` still works).

No other changes needed — the build system auto-discovers new `.C` files in `unit/src/`.

---

## Implementation Order

### Priority 1: Unit tests (no gold files, fastest to implement and validate)
1. `CoordinateRotationTest.C`, `XiComputationTest.C` — standalone math, no MOOSE fixture
2. `SlipWeakeningFrictionLawTest.C`, `DamageBreakageMathTest.C` — formula regression tests
3. Function tests: `InitialCohesionCDBMv2Test.C` (simplest) -> `ForcedRuptureTimeCDBMv2Test.C` -> `InitialShearStressTPV2053dTest.C` -> `InitialStaticFrictionCoeffTest.C` -> `InitialStrikeShearStressPerturbRSF2DTest.C` / `RSF3DTest.C` -> `InitialStressStrainTPV26Test.C` (most complex)

### Priority 2: Simple integration tests (minimal mesh/timestep setup)
4. `fd_comp_var_rate`, `comp_var_rate`, `scale_var_aux` — simple AuxKernels
5. `compute_xi` — simple material with Steady executioner
6. `non_reflect_dashpot_2d` — simple BC
7. `stiff_prop_damping` — simple kernel
8. `residual_evaluation` — simple UO

### Priority 3: CZM integration tests (need BreakMeshByBlock + CZM setup)
9. `slip_weakening_czm_2d` -> `_3d` -> `_2d_parametric` -> `_3d_cdbm`
10. `farms_material_real_aux` (depends on CZM material)

### Priority 4: CDBM integration tests (most complex material setup)
11. `cdbm_3d_slip_weakening` -> `_static` -> `_nonlocal`
12. `radial_average` (ElkRadialAverageUpdated + ElkNonlocalEqstrainUpdated)

### Priority 5: Rate-state integration tests (need custom interface kernels)
13. `rate_state_2d` -> `_3d`
14. `rate_state_interface`

---

## Verification

```bash
# Build and run unit tests
cd /Users/chunhuizhao/projects/farmsquakeworx
make -j4 -C unit
./unit/farmsquakeworx-unit-opt

# Run integration tests
./run_tests -j4
```

All tests should pass. Future changes to any source file that affect numerical output will trigger test failures.

---

## Total Test Count

| Category | Files | Test Cases |
|----------|-------|-----------|
| Unit test files (C++) | 11 | ~80+ individual TEST/TEST_F |
| Integration test directories | 20 | ~30+ `.i` input files with gold comparisons |
| **Total coverage** | **37 custom MOOSE classes + 4 math topics** | **100% source file coverage** |

---

## Gold File Generation

After implementing each integration test `.i` file:

1. Run the test input: `./farmsquakeworx-opt -i test_input.i`
2. Verify output is correct (manual inspection or comparison with known solution)
3. Copy output to gold directory: `cp test_input_out.e gold/` or `cp test_input_out.csv gold/`
4. Run `./run_tests` to verify the test passes with the gold file

Gold files should be committed to the repository so CI/CD can detect regressions.

---

## Implementation Status (Completed March 6, 2026)

### Phase 1: Unit Tests — COMPLETE (109 tests, all passing)

| # | File | Test Count | Status |
|---|------|-----------|--------|
| 1 | `unit/src/CoordinateRotationTest.C` | 8 | PASS |
| 2 | `unit/src/XiComputationTest.C` | 11 | PASS |
| 3 | `unit/src/SlipWeakeningFrictionLawTest.C` | 16 | PASS |
| 4 | `unit/src/DamageBreakageMathTest.C` | 16 | PASS |
| 5 | `unit/src/InitialShearStressTPV2053dTest.C` | 8 | PASS |
| 6 | `unit/src/InitialCohesionCDBMv2Test.C` | 6 | PASS |
| 7 | `unit/src/ForcedRuptureTimeCDBMv2Test.C` | 7 | PASS |
| 8 | `unit/src/InitialStaticFrictionCoeffTest.C` | 7 | PASS |
| 9 | `unit/src/InitialStressStrainTPV26Test.C` | 14 | PASS |
| 10 | `unit/src/InitialStrikeShearStressPerturbRSF2DTest.C` | 8 | PASS |
| 11 | `unit/src/InitialStrikeShearStressPerturbRSF3DTest.C` | 7 | PASS |

Build and run: `make -j4 -C unit && ./unit/farmsquakeworx-unit-opt`

### Phase 2: Integration Tests — COMPLETE (19 tests, all passing)

| # | Test Directory | Input File | Classes Exercised | Status |
|---|---------------|-----------|-------------------|--------|
| 1 | `auxkernels/fd_comp_var_rate/` | `test_fd_comp_var_rate.i` | FDCompVarRate | PASS |
| 2 | `auxkernels/comp_var_rate/` | `test_comp_var_rate.i` | CompVarRate | PASS |
| 3 | `auxkernels/scale_var_aux/` | `test_scale_var_aux.i` | ScaleVarAux | PASS |
| 4 | `auxkernels/farms_material_real_aux/` | `test_farms_material_real_aux.i` | FarmsMaterialRealAux, SlipWeakeningFrictionczm2dParametricStudy | PASS |
| 5 | `bcs/non_reflect_dashpot_2d/` | `test_dashpot_2d.i` | NonReflectDashpotBC | PASS |
| 6 | `bcs/non_reflect_dashpot_3d/` | `test_dashpot_3d.i` | NonReflectDashpotBC3d | PASS |
| 7 | `kernels/stiff_prop_damping/` | `test_stiff_prop_damping.i` | StiffPropDamping | PASS |
| 8 | `materials/compute_xi/` | `test_compute_xi.i` | ComputeXi | PASS |
| 9 | `materials/slip_weakening_czm_2d/` | `test_sw_czm_2d.i` | SlipWeakeningFrictionczm2d, CompVarRate, StiffPropDamping, NonReflectDashpotBC, ResidualEvaluationUserObject | PASS |
| 10 | `materials/slip_weakening_czm_3d/` | `test_sw_czm_3d.i` | SlipWeakeningFrictionczm3d, NonReflectDashpotBC3d | PASS |
| 11 | `materials/slip_weakening_czm_2d_parametric/` | `test_sw_czm_2d_param.i` | SlipWeakeningFrictionczm2dParametricStudy | PASS |
| 12 | `materials/slip_weakening_czm_3d_cdbm/` | `test_sw_czm_3d_cdbm.i` | SlipWeakeningFrictionczm3dCDBM (with forced rupture, cohesion, fluid pressure) | PASS |
| 13 | `materials/cdbm_3d_slip_weakening/` | `test_cdbm_3d_sw.i` | ComputeDamageBreakageStress3DSlipWeakening, ComputeDamageBreakageStressBase3D, ComputeGeneralDamageBreakageStressBase3D | PASS |
| 14 | `materials/cdbm_3d_static/` | `test_cdbm_3d_static.i` | ComputeDamageBreakageStress3DStatic | PASS |
| 15 | `materials/cdbm_3d_nonlocal/` | `test_cdbm_3d_nonlocal.i` | ComputeDamageBreakageStress3DSlipWeakeningNonlocal, ElkRadialAverageUpdated, ElkNonlocalEqstrainUpdated | PASS |
| 16 | `materials/rate_state_2d/` | `test_rsf_2d.i` | RateStateFrictionLaw2D, CZMComputeLocalTractionBaseRSF2D, CZMComputeLocalTractionTotalBaseRSF2D, RateStateInterfaceKernelGlobalx, RateStateInterfaceKernelGlobaly, ScaleVarAux | PASS |
| 17 | `materials/rate_state_3d/` | `test_rsf_3d.i` | RateStateFrictionLaw3D, CZMComputeLocalTractionBaseRSF3D, CZMComputeLocalTractionTotalBaseRSF3D, RateStateInterfaceKernelGlobalx/y/z | PASS |
| 18 | `userobjects/residual_evaluation/` | `test_residual_eval.i` | ResidualEvaluationUserObject | PASS |
| 19 | `userobjects/radial_average/` | `test_radial_average.i` | ElkRadialAverageUpdated, ElkNonlocalEqstrainUpdated, ThreadedElkRadialAverageLoopUpdated | PASS |

Build and run: `conda activate moose && python run_tests -j4`

### Phase 3: Makefile Updates — COMPLETE

- `unit/Makefile`: `SOLID_MECHANICS := yes`, `CONTACT := yes`
- `Makefile` (main): `SOLID_MECHANICS := yes`

### Implementation Notes

1. **InterfaceKernels tested within rate-state tests**: RateStateInterfaceKernelGlobal(x/y/z) are tested as part of the rate_state_2d and rate_state_3d tests rather than in a separate directory, since they require the full rate-state material chain.

2. **CDBM base classes tested via derived classes**: ComputeGeneralDamageBreakageStressBase3D and ComputeDamageBreakageStressBase3D are exercised through their derived classes (cdbm_3d_slip_weakening, cdbm_3d_static, cdbm_3d_nonlocal).

3. **FarmsMaterialRealAux requires `total_shear_traction`**: This property is only declared by `SlipWeakeningFrictionczm2dParametricStudy`, not by `SlipWeakeningFrictionczm2d`. The test uses the parametric study material.

4. **ElkNonlocalEqstrainUpdated requires `eqstrain_nonlocal_initial`**: This is provided via `GenericConstantMaterial` in tests (in production, it comes from `CoupledVariableValueMaterial` + `SolutionUserObject`).

5. **CDBM tests require `static_initial_strain_tensor` and `static_initial_stress_tensor`**: These are provided via `GenericFunctionRankTwoTensor` with constant functions for simplicity.

6. **`allow_warnings = true` for FarmsMaterialRealAux test**: MOOSE's CZMRealVectorCartesianComponent generates a warning about stateful properties not having initQpStatefulProperties overridden. This is a framework issue, not our code.

### Coverage Summary

| Source Category | Classes | Tested By |
|----------------|---------|-----------|
| Functions (7) | All 7 | Unit tests (MooseObjectUnitTest fixture) |
| Materials — SW CZM (4) | All 4 | Integration tests (sw_czm_2d, _3d, _2d_param, _3d_cdbm) |
| Materials — CDBM (5) | All 5 | Integration tests (cdbm_3d_sw, _static, _nonlocal) |
| Materials — Rate-State (6) | All 6 | Integration tests (rsf_2d, rsf_3d) |
| Materials — Helper (2) | Both | Integration tests (compute_xi, radial_average) |
| AuxKernels (4) | All 4 | Integration tests (fd_comp_var_rate, comp_var_rate, scale_var_aux, farms_material_real_aux) |
| BCs (2) | Both | Integration tests (dashpot_2d, dashpot_3d) |
| Kernels (1) | 1 | Integration test (stiff_prop_damping) |
| InterfaceKernels (3) | All 3 | Integration tests (rsf_2d, rsf_3d) |
| UserObjects (3) | All 3 | Integration tests (residual_eval, radial_average) |
| Standalone Math (4) | All 4 | Unit tests (standalone TEST macros) |
| **TOTAL** | **41** | **109 unit + 19 integration = 128 tests, 100% source coverage** |

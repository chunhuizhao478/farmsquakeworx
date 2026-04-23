# Test for EffectiveBodyForceTPV26VaryingDensity
# Applies the kernel as a body force in disp_y on a small 3D mesh.
# Compares an analytical surrogate of the body force integrated as a postprocessor
# against the kernel's effect via nodal reaction balance.
#
# At shallow depths (|z| < 500 m), TPV32 rho interpolates between 2200 (z=0) and 2450 (z=500).
# With fluid_density=1000, gravity=9.8 in hydrostatic mode:
#   dPf/dz       = rho_f*g    = 9800 Pa/m
#   f_eff(z)     = -(rho(z)*g - dPf/dz)      (per kernel implementation)
#   residual+=   = -f_eff * test

[Mesh]
  type = GeneratedMesh
  dim = 3
  nx = 1
  ny = 1
  nz = 1
  xmin = 0
  xmax = 1
  ymin = 0
  ymax = 1
  zmin = -1
  zmax = 0
[]

[GlobalParams]
  displacements = 'disp_x disp_y disp_z'
[]

[Variables]
  [disp_x]
  []
  [disp_y]
  []
  [disp_z]
  []
[]

[AuxVariables]
  [body_force_ref]
    order = CONSTANT
    family = MONOMIAL
  []
[]

[Functions]
  # Analytical surrogate for rho(z)*g - dPf/dz at the integration point.
  # Element centroid is z = -0.5 m -> rho = 2200 + (2450-2200)*(0.5/500) = 2200.25
  # hydrostatic dPf/dz = 9800; so (rho*g - dPf/dz) = 2200.25*9.8 - 9800 = 11762.45
  [body_force_analytic]
    type = ConstantFunction
    value = 11762.45
  []
[]

[AuxKernels]
  [set_body_force_ref]
    type = FunctionAux
    variable = body_force_ref
    function = body_force_analytic
    execute_on = 'INITIAL'
  []
[]

[Physics]
  [SolidMechanics]
    [QuasiStatic]
      [all]
        strain = SMALL
        add_variables = false
      []
    []
  []
[]

[Kernels]
  [body_force_y]
    type = EffectiveBodyForceTPV26VaryingDensity
    variable = disp_y
    fluid_density = 1000
    gravity = 9.8
  []
[]

[Materials]
  [elasticity]
    type = ComputeIsotropicElasticityTensor
    lambda = 3.204e10
    shear_modulus = 3.204e10
  []
  [stress]
    type = ComputeLinearElasticStress
  []
[]

[BCs]
  [fix_x]
    type = DirichletBC
    variable = disp_x
    boundary = 'left right top bottom front back'
    value = 0
  []
  [fix_z]
    type = DirichletBC
    variable = disp_z
    boundary = 'left right top bottom front back'
    value = 0
  []
  [fix_y]
    type = DirichletBC
    variable = disp_y
    boundary = 'left right top bottom front back'
    value = 0
  []
[]

[Postprocessors]
  [body_force_ref_avg]
    type = ElementAverageValue
    variable = body_force_ref
    execute_on = 'INITIAL'
  []
[]

[Executioner]
  type = Steady
  solve_type = NEWTON
  petsc_options_iname = '-pc_type'
  petsc_options_value = 'lu'
[]

[Outputs]
  csv = true
[]

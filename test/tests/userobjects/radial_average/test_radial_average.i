# Integration test for ElkRadialAverageUpdated + ElkNonlocalEqstrainUpdated
# Tests nonlocal spatial averaging of a material property
# Uses a known spatially-varying property to verify averaging

[Mesh]
  type = GeneratedMesh
  dim = 3
  nx = 4
  ny = 4
  nz = 2
  xmin = -2000
  xmax = 2000
  ymin = -2000
  ymax = 2000
  zmin = -500
  zmax = 500
[]

[GlobalParams]
  displacements = 'disp_x disp_y disp_z'
  lambda_o = 3.204e10
  shear_modulus_o = 3.204e10
  xi_0 = -0.8
  xi_d = -0.8
  xi_max = 1.8
  xi_min = -1.8
  Cd_constant = 1e5
  CdCb_multiplier = 100
  CBH_constant = 0
  C_1 = 0
  C_2 = 0.05
  beta_width = 0.05
  C_g = 1e-12
  m1 = 10
  m2 = 1
  chi = 0.8
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
  [eqstrain_nonlocal_aux]
    order = FIRST
    family = MONOMIAL
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

[Functions]
  [func_zero]
    type = ConstantFunction
    value = 0
  []
[]

[AuxKernels]
  [get_eqstrain_nonlocal_aux]
    type = MaterialRealAux
    variable = eqstrain_nonlocal_aux
    property = eqstrain_nonlocal
    execute_on = 'TIMESTEP_END'
  []
[]

[Kernels]
  [inertia_x]
    type = InertialForce
    use_displaced_mesh = false
    variable = disp_x
  []
  [inertia_y]
    type = InertialForce
    use_displaced_mesh = false
    variable = disp_y
  []
  [inertia_z]
    type = InertialForce
    use_displaced_mesh = false
    variable = disp_z
  []
[]

[Materials]
  [stress_medium]
    type = ComputeDamageBreakageStress3DStatic
  []
  [dummy_material]
    type = GenericConstantMaterial
    prop_names = 'initial_damage initial_breakage damage_perturbation density eqstrain_nonlocal_initial'
    prop_values = '0 0 0 2670 -1.732'
  []
  [static_initial_stress_tensor]
    type = GenericFunctionRankTwoTensor
    tensor_name = static_initial_stress_tensor
    tensor_functions = 'func_zero func_zero func_zero
                        func_zero func_zero func_zero
                        func_zero func_zero func_zero'
  []
  [static_initial_strain_tensor]
    type = GenericFunctionRankTwoTensor
    tensor_name = static_initial_strain_tensor
    tensor_functions = 'func_zero func_zero func_zero
                        func_zero func_zero func_zero
                        func_zero func_zero func_zero'
  []
  [nonlocal_eqstrain]
    type = ElkNonlocalEqstrainUpdated
    average_UO = eqstrain_averaging
  []
[]

[UserObjects]
  [eqstrain_averaging]
    type = ElkRadialAverageUpdated
    length_scale = 400
    prop_name = xi
    radius = 600
    weights = CONSTANT
    execute_on = TIMESTEP_END
  []
[]

[BCs]
  [fix_x_left]
    type = DirichletBC
    variable = disp_x
    boundary = left
    value = 0
  []
  [fix_y_bottom]
    type = DirichletBC
    variable = disp_y
    boundary = bottom
    value = 0
  []
  [fix_z_back]
    type = DirichletBC
    variable = disp_z
    boundary = back
    value = 0
  []
  [compress_y_top]
    type = FunctionDirichletBC
    variable = disp_y
    boundary = top
    function = '-1e-4*t'
  []
[]

[Executioner]
  type = Transient
  dt = 0.01
  num_steps = 3
  [TimeIntegrator]
    type = CentralDifference
    solve_type = lumped
  []
[]

[Postprocessors]
  [avg_eqstrain_nonlocal]
    type = ElementAverageValue
    variable = eqstrain_nonlocal_aux
  []
  [max_disp_y]
    type = NodalExtremeValue
    variable = disp_y
    value_type = max
  []
[]

[Outputs]
  csv = true
[]

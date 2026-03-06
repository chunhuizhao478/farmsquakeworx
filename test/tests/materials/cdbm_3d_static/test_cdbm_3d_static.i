# Integration test for ComputeDamageBreakageStress3DStatic
# 3D CDBM static material under compression loading
# No fault interface - just bulk material response

lambda_o = 3.204e10
shear_modulus_o = 3.204e10
density = 2670

[Mesh]
  type = GeneratedMesh
  dim = 3
  nx = 2
  ny = 2
  nz = 2
  xmin = -500
  xmax = 500
  ymin = -500
  ymax = 500
  zmin = -500
  zmax = 500
[]

[GlobalParams]
  displacements = 'disp_x disp_y disp_z'
  lambda_o = ${lambda_o}
  shear_modulus_o = ${shear_modulus_o}
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

[Functions]
  [func_zero]
    type = ConstantFunction
    value = 0
  []
[]

[Materials]
  [stress_medium]
    type = ComputeDamageBreakageStress3DStatic
  []
  [dummy_material]
    type = GenericConstantMaterial
    prop_names = 'initial_damage initial_breakage damage_perturbation density'
    prop_values = '0 0 0 ${density}'
  []
  [static_initial_strain_tensor]
    type = GenericFunctionRankTwoTensor
    tensor_name = static_initial_strain_tensor
    tensor_functions = 'func_zero func_zero func_zero
                        func_zero func_zero func_zero
                        func_zero func_zero func_zero'
  []
  [static_initial_stress_tensor]
    type = GenericFunctionRankTwoTensor
    tensor_name = static_initial_stress_tensor
    tensor_functions = 'func_zero func_zero func_zero
                        func_zero func_zero func_zero
                        func_zero func_zero func_zero'
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
  num_steps = 5
  [TimeIntegrator]
    type = CentralDifference
    solve_type = lumped
  []
[]

[Postprocessors]
  [max_disp_y]
    type = NodalExtremeValue
    variable = disp_y
    value_type = max
  []
  [min_disp_y]
    type = NodalExtremeValue
    variable = disp_y
    value_type = min
  []
[]

[Outputs]
  csv = true
[]

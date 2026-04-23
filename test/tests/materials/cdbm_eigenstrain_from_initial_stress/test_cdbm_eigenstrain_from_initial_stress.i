# Test for ComputeDamageBreakageEigenstrainFromInitialStress
# With initial_damage = 0, gamma = 0; the computed eigenstrain reduces to the
# negative of the inverse-Hooke compliance on the initial stress tensor.
#
# For isotropic initial stress sigma_xx = sigma_yy = sigma_zz = -1e6 Pa,
# lambda = mu = 3.204e10 Pa:
#   A            = 1/(2 mu)                                        = 1.56054931e-11
#   B            = -lambda / (2 mu * (3 lambda + 2 mu))            = -3.12109862e-12
#   eps_ii       = A*sigma_ii + B*tr(sigma)                        = -6.24219723e-6
#   eigenstrain  = -eps_ii                                         =  6.24219723e-6

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
  zmin = 0
  zmax = 1
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
  [eigenstrain_xx_aux]
    order = CONSTANT
    family = MONOMIAL
  []
  [eigenstrain_yy_aux]
    order = CONSTANT
    family = MONOMIAL
  []
  [eigenstrain_zz_aux]
    order = CONSTANT
    family = MONOMIAL
  []
  [eigenstrain_xy_aux]
    order = CONSTANT
    family = MONOMIAL
  []
[]

[Functions]
  [func_sigma_diag]
    type = ConstantFunction
    value = -1e6
  []
  [func_zero]
    type = ConstantFunction
    value = 0
  []
[]

[AuxKernels]
  [get_eigenstrain_xx]
    type = RankTwoAux
    rank_two_tensor = ini_eigenstrain
    variable = eigenstrain_xx_aux
    index_i = 0
    index_j = 0
    execute_on = 'TIMESTEP_END'
  []
  [get_eigenstrain_yy]
    type = RankTwoAux
    rank_two_tensor = ini_eigenstrain
    variable = eigenstrain_yy_aux
    index_i = 1
    index_j = 1
    execute_on = 'TIMESTEP_END'
  []
  [get_eigenstrain_zz]
    type = RankTwoAux
    rank_two_tensor = ini_eigenstrain
    variable = eigenstrain_zz_aux
    index_i = 2
    index_j = 2
    execute_on = 'TIMESTEP_END'
  []
  [get_eigenstrain_xy]
    type = RankTwoAux
    rank_two_tensor = ini_eigenstrain
    variable = eigenstrain_xy_aux
    index_i = 0
    index_j = 1
    execute_on = 'TIMESTEP_END'
  []
[]

[Physics]
  [SolidMechanics]
    [QuasiStatic]
      [all]
        strain = SMALL
        add_variables = false
        eigenstrain_names = 'ini_eigenstrain'
      []
    []
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
  [initial_damage]
    type = GenericConstantMaterial
    prop_names = 'initial_damage'
    prop_values = '0'
  []
  [initial_stress_eigenstrain]
    type = ComputeDamageBreakageEigenstrainFromInitialStress
    eigenstrain_name = ini_eigenstrain
    initial_stress = 'func_sigma_diag func_zero        func_zero
                      func_zero        func_sigma_diag func_zero
                      func_zero        func_zero        func_sigma_diag'
    lambda_o = 3.204e10
    shear_modulus_o = 3.204e10
    xi_o = -0.8
  []
[]

[BCs]
  [fix_x]
    type = DirichletBC
    variable = disp_x
    boundary = 'left right top bottom front back'
    value = 0
  []
  [fix_y]
    type = DirichletBC
    variable = disp_y
    boundary = 'left right top bottom front back'
    value = 0
  []
  [fix_z]
    type = DirichletBC
    variable = disp_z
    boundary = 'left right top bottom front back'
    value = 0
  []
[]

[Postprocessors]
  [eigenstrain_xx_avg]
    type = ElementAverageValue
    variable = eigenstrain_xx_aux
  []
  [eigenstrain_yy_avg]
    type = ElementAverageValue
    variable = eigenstrain_yy_aux
  []
  [eigenstrain_zz_avg]
    type = ElementAverageValue
    variable = eigenstrain_zz_aux
  []
  [eigenstrain_xy_avg]
    type = ElementAverageValue
    variable = eigenstrain_xy_aux
  []
[]

[Executioner]
  type = Transient
  dt = 1
  num_steps = 1
  solve_type = NEWTON
  petsc_options_iname = '-pc_type'
  petsc_options_value = 'lu'
[]

[Outputs]
  csv = true
[]

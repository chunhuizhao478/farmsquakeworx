# Test for FarmsComputeIsotropicElasticityTensor
# With initial_damage = 0, mu_eff = mu_0 and lambda = lambda_0; the material
# reduces to a standard isotropic elasticity tensor with (lambda, mu).
#
# Apply uniaxial strain eps_xx = 1e-6 (all other strains = 0) on a single unit cube.
# Expected stresses (lambda = mu = 3.204e10 Pa):
#   sigma_xx = (lambda + 2*mu) * eps = 9.612e10 * 1e-6 = 9.612e4 Pa = 96120 Pa
#   sigma_yy = sigma_zz = lambda * eps = 3.204e10 * 1e-6 = 32040 Pa

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
  [stress_xx]
    order = CONSTANT
    family = MONOMIAL
  []
  [stress_yy]
    order = CONSTANT
    family = MONOMIAL
  []
  [stress_zz]
    order = CONSTANT
    family = MONOMIAL
  []
[]

[AuxKernels]
  [get_stress_xx]
    type = RankTwoAux
    rank_two_tensor = stress
    variable = stress_xx
    index_i = 0
    index_j = 0
    execute_on = 'TIMESTEP_END'
  []
  [get_stress_yy]
    type = RankTwoAux
    rank_two_tensor = stress
    variable = stress_yy
    index_i = 1
    index_j = 1
    execute_on = 'TIMESTEP_END'
  []
  [get_stress_zz]
    type = RankTwoAux
    rank_two_tensor = stress
    variable = stress_zz
    index_i = 2
    index_j = 2
    execute_on = 'TIMESTEP_END'
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

[Materials]
  [elasticity]
    type = FarmsComputeIsotropicElasticityTensor
    lambda = 3.204e10
    shear_modulus = 3.204e10
    xi_o = -0.8
    initial_damage_property = initial_damage
  []
  [initial_damage]
    type = GenericConstantMaterial
    prop_names = 'initial_damage'
    prop_values = '0'
  []
  [stress]
    type = ComputeLinearElasticStress
  []
[]

[BCs]
  # Uniaxial strain: constrain y and z on all faces and impose eps_xx via disp_x on left/right.
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
  [fix_x_left]
    type = DirichletBC
    variable = disp_x
    boundary = left
    value = 0
  []
  [pull_x_right]
    type = DirichletBC
    variable = disp_x
    boundary = right
    value = 1e-6
  []
[]

[Postprocessors]
  [sigma_xx_avg]
    type = ElementAverageValue
    variable = stress_xx
  []
  [sigma_yy_avg]
    type = ElementAverageValue
    variable = stress_yy
  []
  [sigma_zz_avg]
    type = ElementAverageValue
    variable = stress_zz
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

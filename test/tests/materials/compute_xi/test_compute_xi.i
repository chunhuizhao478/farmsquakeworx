# Test for ComputeXi Material
# Verifies strain invariant ratio xi = I1 / sqrt(I2)
# Under uniform compression (disp_z = -epsilon*z), xi should be -1

[Mesh]
  type = GeneratedMesh
  dim = 3
  nx = 2
  ny = 2
  nz = 2
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

[Functions]
  [compress_z]
    type = ParsedFunction
    expression = '-1e-4*z'
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
    type = ComputeIsotropicElasticityTensor
    lambda = 32.04e9
    shear_modulus = 32.04e9
  []
  [stress]
    type = ComputeLinearElasticStress
  []
  [xi_mat]
    type = ComputeXi
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
  [compress_z_bc]
    type = FunctionDirichletBC
    variable = disp_z
    boundary = 'left right top bottom front back'
    function = compress_z
  []
[]

[Postprocessors]
  [xi_avg]
    type = ElementAverageValue
    variable = strain_invariant_ratio
  []
  [I1_avg]
    type = ElementAverageValue
    variable = I1_initial
  []
  [I2_avg]
    type = ElementAverageValue
    variable = I2_initial
  []
[]

[AuxVariables]
  [strain_invariant_ratio]
    order = CONSTANT
    family = MONOMIAL
  []
  [I1_initial]
    order = CONSTANT
    family = MONOMIAL
  []
  [I2_initial]
    order = CONSTANT
    family = MONOMIAL
  []
[]

[AuxKernels]
  [xi_aux]
    type = MaterialRealAux
    variable = strain_invariant_ratio
    property = strain_invariant_ratio
    execute_on = 'TIMESTEP_END'
  []
  [I1_aux]
    type = MaterialRealAux
    variable = I1_initial
    property = I1_initial
    execute_on = 'TIMESTEP_END'
  []
  [I2_aux]
    type = MaterialRealAux
    variable = I2_initial
    property = I2_initial
    execute_on = 'TIMESTEP_END'
  []
[]

[Executioner]
  type = Steady
  solve_type = NEWTON
[]

[Outputs]
  csv = true
[]

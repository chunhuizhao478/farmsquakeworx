# Integration test for ResidualEvaluationUserObject
# Verifies that residual is recomputed with latest solution via tagged vectors
# Uses a simple 2D elastic problem with explicit time integration

[Mesh]
  type = GeneratedMesh
  dim = 2
  nx = 4
  ny = 4
  xmin = -500
  xmax = 500
  ymin = -500
  ymax = 500
[]

[GlobalParams]
  displacements = 'disp_x disp_y'
[]

[Variables]
  [disp_x]
  []
  [disp_y]
  []
[]

[AuxVariables]
  [resid_x]
    order = FIRST
    family = LAGRANGE
  []
  [resid_y]
    order = FIRST
    family = LAGRANGE
  []
[]

[Functions]
  [ic_vel]
    type = ParsedFunction
    expression = '1e-4*exp(-(x*x+y*y)/1e5)'
  []
[]

[ICs]
  [disp_x_ic]
    type = FunctionIC
    variable = disp_x
    function = ic_vel
  []
[]

[Physics]
  [SolidMechanics]
    [QuasiStatic]
      [all]
        strain = SMALL
        add_variables = false
        planar_formulation = PLANE_STRAIN
        extra_vector_tags = 'restore_tag'
      []
    []
  []
[]

[Problem]
  extra_tag_vectors = 'restore_tag'
[]

[Kernels]
  [inertia_x]
    type = InertialForce
    variable = disp_x
    use_displaced_mesh = false
  []
  [inertia_y]
    type = InertialForce
    variable = disp_y
    use_displaced_mesh = false
  []
[]

[AuxKernels]
  [restore_x]
    type = TagVectorAux
    vector_tag = 'restore_tag'
    v = 'disp_x'
    variable = 'resid_x'
  []
  [restore_y]
    type = TagVectorAux
    vector_tag = 'restore_tag'
    v = 'disp_y'
    variable = 'resid_y'
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
  [density]
    type = GenericConstantMaterial
    prop_names = density
    prop_values = 2670
  []
[]

[UserObjects]
  [recompute_residual_tag]
    type = ResidualEvaluationUserObject
    vector_tag = 'restore_tag'
    force_preaux = true
    execute_on = 'TIMESTEP_END'
  []
[]

[BCs]
  [fix_all_x]
    type = DirichletBC
    variable = disp_x
    boundary = 'left right top bottom'
    value = 0
  []
  [fix_all_y]
    type = DirichletBC
    variable = disp_y
    boundary = 'left right top bottom'
    value = 0
  []
[]

[Postprocessors]
  [max_resid_x]
    type = NodalExtremeValue
    variable = resid_x
    value_type = max
  []
  [max_resid_y]
    type = NodalExtremeValue
    variable = resid_y
    value_type = max
  []
[]

[Executioner]
  type = Transient
  dt = 0.001
  num_steps = 3
  [TimeIntegrator]
    type = CentralDifference
    solve_type = lumped
  []
[]

[Outputs]
  csv = true
[]

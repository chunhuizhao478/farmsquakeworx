# Test for StiffPropDamping Kernel
# Stiffness-proportional Rayleigh damping with q=0.1
# A small elastic domain with initial displacement, damping should reduce oscillations

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
  q = 0.1
[]

[Variables]
  [disp_x]
  []
  [disp_y]
  []
[]

[Functions]
  [ic_disp_y]
    type = ParsedFunction
    expression = '1e-4*exp(-(x*x+y*y)/1e5)'
  []
[]

[ICs]
  [disp_y_ic]
    type = FunctionIC
    variable = disp_y
    function = ic_disp_y
  []
[]

[Physics]
  [SolidMechanics]
    [QuasiStatic]
      [all]
        strain = SMALL
        add_variables = false
        planar_formulation = PLANE_STRAIN
      []
    []
  []
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
  [damping_x]
    type = StiffPropDamping
    variable = disp_x
    component = 0
  []
  [damping_y]
    type = StiffPropDamping
    variable = disp_y
    component = 1
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

[BCs]
  [fix_x_left]
    type = DirichletBC
    variable = disp_x
    boundary = 'left right top bottom'
    value = 0
  []
  [fix_y_left]
    type = DirichletBC
    variable = disp_y
    boundary = 'left right top bottom'
    value = 0
  []
[]

[Postprocessors]
  [max_disp_y]
    type = NodalExtremeValue
    variable = disp_y
    value_type = max
  []
[]

[Executioner]
  type = Transient
  dt = 0.001
  num_steps = 5
  [TimeIntegrator]
    type = CentralDifference
    solve_type = lumped
  []
[]

[Outputs]
  csv = true
[]

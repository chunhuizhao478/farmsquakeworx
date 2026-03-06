# Test for NonReflectDashpotBC (2D Lysmer absorbing boundary)
# Small 2D elastic domain with absorbing boundaries
# Initial velocity perturbation should exit domain without reflection

[Mesh]
  type = GeneratedMesh
  dim = 2
  nx = 10
  ny = 10
  xmin = -5000
  xmax = 5000
  ymin = -5000
  ymax = 5000
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

[Functions]
  [ic_vel_x]
    type = ParsedFunction
    expression = 'if(x*x+y*y<1e6,0.1*exp(-(x*x+y*y)/5e5),0)'
  []
[]

[ICs]
  [vel_x_ic]
    type = FunctionIC
    variable = disp_x
    function = ic_vel_x
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
  [dashpot_top_x]
    type = NonReflectDashpotBC
    component = 0
    variable = disp_x
    disp_x = disp_x
    disp_y = disp_y
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = top
  []
  [dashpot_top_y]
    type = NonReflectDashpotBC
    component = 1
    variable = disp_y
    disp_x = disp_x
    disp_y = disp_y
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = top
  []
  [dashpot_bottom_x]
    type = NonReflectDashpotBC
    component = 0
    variable = disp_x
    disp_x = disp_x
    disp_y = disp_y
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = bottom
  []
  [dashpot_bottom_y]
    type = NonReflectDashpotBC
    component = 1
    variable = disp_y
    disp_x = disp_x
    disp_y = disp_y
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = bottom
  []
  [dashpot_left_x]
    type = NonReflectDashpotBC
    component = 0
    variable = disp_x
    disp_x = disp_x
    disp_y = disp_y
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = left
  []
  [dashpot_left_y]
    type = NonReflectDashpotBC
    component = 1
    variable = disp_y
    disp_x = disp_x
    disp_y = disp_y
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = left
  []
  [dashpot_right_x]
    type = NonReflectDashpotBC
    component = 0
    variable = disp_x
    disp_x = disp_x
    disp_y = disp_y
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = right
  []
  [dashpot_right_y]
    type = NonReflectDashpotBC
    component = 1
    variable = disp_y
    disp_x = disp_x
    disp_y = disp_y
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = right
  []
[]

[Postprocessors]
  [max_disp_x]
    type = NodalExtremeValue
    variable = disp_x
    value_type = max
  []
[]

[Executioner]
  type = Transient
  dt = 0.05
  num_steps = 5
  [TimeIntegrator]
    type = CentralDifference
    solve_type = lumped
  []
[]

[Outputs]
  csv = true
  exodus = true
[]

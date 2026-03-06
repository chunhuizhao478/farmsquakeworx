# Test for NonReflectDashpotBC3d (3D Lysmer absorbing boundary)
# Small 3D elastic domain with absorbing boundaries on all 6 faces

[Mesh]
  type = GeneratedMesh
  dim = 3
  nx = 4
  ny = 4
  nz = 4
  xmin = -2000
  xmax = 2000
  ymin = -2000
  ymax = 2000
  zmin = -2000
  zmax = 2000
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
  [ic_vel_x]
    type = ParsedFunction
    expression = 'if(x*x+y*y+z*z<1e6,0.1*exp(-(x*x+y*y+z*z)/5e5),0)'
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
  [inertia_z]
    type = InertialForce
    variable = disp_z
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
    type = NonReflectDashpotBC3d
    component = 0
    variable = disp_x
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = top
  []
  [dashpot_top_y]
    type = NonReflectDashpotBC3d
    component = 1
    variable = disp_y
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = top
  []
  [dashpot_top_z]
    type = NonReflectDashpotBC3d
    component = 2
    variable = disp_z
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = top
  []
  [dashpot_bottom_x]
    type = NonReflectDashpotBC3d
    component = 0
    variable = disp_x
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = bottom
  []
  [dashpot_bottom_y]
    type = NonReflectDashpotBC3d
    component = 1
    variable = disp_y
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = bottom
  []
  [dashpot_bottom_z]
    type = NonReflectDashpotBC3d
    component = 2
    variable = disp_z
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = bottom
  []
  [dashpot_left_x]
    type = NonReflectDashpotBC3d
    component = 0
    variable = disp_x
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = left
  []
  [dashpot_left_y]
    type = NonReflectDashpotBC3d
    component = 1
    variable = disp_y
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = left
  []
  [dashpot_left_z]
    type = NonReflectDashpotBC3d
    component = 2
    variable = disp_z
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = left
  []
  [dashpot_right_x]
    type = NonReflectDashpotBC3d
    component = 0
    variable = disp_x
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = right
  []
  [dashpot_right_y]
    type = NonReflectDashpotBC3d
    component = 1
    variable = disp_y
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = right
  []
  [dashpot_right_z]
    type = NonReflectDashpotBC3d
    component = 2
    variable = disp_z
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = right
  []
  [dashpot_front_x]
    type = NonReflectDashpotBC3d
    component = 0
    variable = disp_x
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = front
  []
  [dashpot_front_y]
    type = NonReflectDashpotBC3d
    component = 1
    variable = disp_y
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = front
  []
  [dashpot_front_z]
    type = NonReflectDashpotBC3d
    component = 2
    variable = disp_z
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = front
  []
  [dashpot_back_x]
    type = NonReflectDashpotBC3d
    component = 0
    variable = disp_x
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = back
  []
  [dashpot_back_y]
    type = NonReflectDashpotBC3d
    component = 1
    variable = disp_y
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = back
  []
  [dashpot_back_z]
    type = NonReflectDashpotBC3d
    component = 2
    variable = disp_z
    disp_x = disp_x
    disp_y = disp_y
    disp_z = disp_z
    p_wave_speed = 6000
    shear_wave_speed = 3464
    boundary = back
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
[]

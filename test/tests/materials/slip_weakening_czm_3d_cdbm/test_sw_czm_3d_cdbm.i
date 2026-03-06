# Integration test for SlipWeakeningFrictionczm3dCDBM
# 3D CZM with CDBM-coupled slip weakening friction
# Tests with forced rupture mode + cohesion + fluid pressure

Dc = 0.4
mu_s = 0.677
mu_d = 0.525
len = 500
q = 0.1

[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 3
    nx = 2
    ny = 2
    nz = 2
    xmin = -1000
    xmax = 1000
    ymin = -1000
    ymax = 1000
    zmin = -1000
    zmax = 1000
  []
  [block1]
    type = ParsedSubdomainMeshGenerator
    input = gen
    combinatorial_geometry = 'y>0'
    block_id = 100
  []
  [block2]
    type = ParsedSubdomainMeshGenerator
    input = block1
    combinatorial_geometry = 'y<0'
    block_id = 200
  []
  [split]
    type = BreakMeshByBlockGenerator
    input = block2
    split_interface = true
    block_pairs = '100 200'
  []
  [sidesets]
    input = split
    type = SideSetsFromNormalsGenerator
    normals = '-1 0 0
               1 0 0
               0 -1 0
               0 1 0
               0 0 -1
               0 0 1'
    new_boundary = 'left right bottom top back front'
  []
[]

[GlobalParams]
  displacements = 'disp_x disp_y disp_z'
  q = ${q}
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
  [resid_x]
    order = FIRST
    family = LAGRANGE
  []
  [resid_y]
    order = FIRST
    family = LAGRANGE
  []
  [resid_z]
    order = FIRST
    family = LAGRANGE
  []
  [resid_slipweakening_x]
    order = FIRST
    family = LAGRANGE
  []
  [resid_slipweakening_y]
    order = FIRST
    family = LAGRANGE
  []
  [resid_slipweakening_z]
    order = FIRST
    family = LAGRANGE
  []
  [disp_slipweakening_x]
    order = FIRST
    family = LAGRANGE
  []
  [disp_slipweakening_y]
    order = FIRST
    family = LAGRANGE
  []
  [disp_slipweakening_z]
    order = FIRST
    family = LAGRANGE
  []
  [vel_slipweakening_x]
    order = FIRST
    family = LAGRANGE
  []
  [vel_slipweakening_y]
    order = FIRST
    family = LAGRANGE
  []
  [vel_slipweakening_z]
    order = FIRST
    family = LAGRANGE
  []
  [cohesion_aux]
    order = FIRST
    family = LAGRANGE
  []
  [forced_rupture_aux]
    order = FIRST
    family = LAGRANGE
  []
  [fluid_pressure_aux]
    order = FIRST
    family = LAGRANGE
  []
[]

[Physics/SolidMechanics/CohesiveZone]
  [czm_ik]
    boundary = 'Block100_Block200'
    strain = SMALL
    generate_output = 'traction_x traction_y traction_z jump_x jump_y jump_z'
  []
[]

[Physics]
  [SolidMechanics]
    [QuasiStatic]
      [all]
        strain = SMALL
        add_variables = false
        extra_vector_tags = 'restore_tag'
      []
    []
  []
[]

[Problem]
  extra_tag_vectors = 'restore_tag'
[]

[Functions]
  [func_cohesion]
    type = ConstantFunction
    value = 2.0e6
  []
  [func_forced_rupture]
    type = ConstantFunction
    value = 1e9
  []
  [func_fluid_pressure]
    type = ConstantFunction
    value = 0
  []
  [func_initial_stress_xx]
    type = ConstantFunction
    value = -120e6
  []
  [func_initial_stress_yy]
    type = ConstantFunction
    value = -120e6
  []
  [func_initial_stress_xy]
    type = ConstantFunction
    value = 81.6e6
  []
  [func_zero]
    type = ConstantFunction
    value = 0
  []
[]

[AuxKernels]
  [Displacement_x]
    type = ProjectionAux
    variable = disp_slipweakening_x
    v = disp_x
    execute_on = 'TIMESTEP_BEGIN'
  []
  [Displacement_y]
    type = ProjectionAux
    variable = disp_slipweakening_y
    v = disp_y
    execute_on = 'TIMESTEP_BEGIN'
  []
  [Displacement_z]
    type = ProjectionAux
    variable = disp_slipweakening_z
    v = disp_z
    execute_on = 'TIMESTEP_BEGIN'
  []
  [Vel_x]
    type = CompVarRate
    variable = vel_slipweakening_x
    coupled = disp_x
    execute_on = 'TIMESTEP_END'
  []
  [Vel_y]
    type = CompVarRate
    variable = vel_slipweakening_y
    coupled = disp_y
    execute_on = 'TIMESTEP_END'
  []
  [Vel_z]
    type = CompVarRate
    variable = vel_slipweakening_z
    coupled = disp_z
    execute_on = 'TIMESTEP_END'
  []
  [Residual_x]
    type = ProjectionAux
    variable = resid_slipweakening_x
    v = resid_x
    execute_on = 'TIMESTEP_BEGIN'
  []
  [Residual_y]
    type = ProjectionAux
    variable = resid_slipweakening_y
    v = resid_y
    execute_on = 'TIMESTEP_BEGIN'
  []
  [Residual_z]
    type = ProjectionAux
    variable = resid_slipweakening_z
    v = resid_z
    execute_on = 'TIMESTEP_BEGIN'
  []
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
  [restore_z]
    type = TagVectorAux
    vector_tag = 'restore_tag'
    v = 'disp_z'
    variable = 'resid_z'
  []
  [get_cohesion_aux]
    type = FunctionAux
    variable = cohesion_aux
    function = func_cohesion
    execute_on = 'INITIAL TIMESTEP_BEGIN'
  []
  [get_forced_rupture_aux]
    type = FunctionAux
    variable = forced_rupture_aux
    function = func_forced_rupture
    execute_on = 'INITIAL TIMESTEP_BEGIN'
  []
  [get_fluid_pressure_aux]
    type = FunctionAux
    variable = fluid_pressure_aux
    function = func_fluid_pressure
    execute_on = 'INITIAL TIMESTEP_BEGIN'
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
  [damping_z]
    type = StiffPropDamping
    variable = disp_z
    component = 2
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
  [static_initial_stress_tensor]
    type = GenericFunctionRankTwoTensor
    tensor_name = static_initial_stress_tensor
    tensor_functions = 'func_initial_stress_xx func_initial_stress_xy func_zero
                        func_initial_stress_xy func_initial_stress_yy func_zero
                        func_zero              func_zero              func_initial_stress_yy'
  []
  [czm_mat]
    type = SlipWeakeningFrictionczm3dCDBM
    mu_s = ${mu_s}
    mu_d = ${mu_d}
    Dc = ${Dc}
    len = ${len}
    disp_slipweakening_x = disp_slipweakening_x
    disp_slipweakening_y = disp_slipweakening_y
    disp_slipweakening_z = disp_slipweakening_z
    vel_slipweakening_x = vel_slipweakening_x
    vel_slipweakening_y = vel_slipweakening_y
    vel_slipweakening_z = vel_slipweakening_z
    reaction_slipweakening_x = resid_slipweakening_x
    reaction_slipweakening_y = resid_slipweakening_y
    reaction_slipweakening_z = resid_slipweakening_z
    use_forced_rupture = true
    t0 = 0.1
    cohesion_aux = cohesion_aux
    forced_rupture_aux = forced_rupture_aux
    fluid_pressure_aux = fluid_pressure_aux
    boundary = 'Block100_Block200'
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

[Postprocessors]
  [max_disp_x]
    type = NodalExtremeValue
    variable = disp_x
    value_type = max
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

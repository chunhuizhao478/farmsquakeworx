# Integration test for SlipWeakeningFrictionczm2d
# 2D CZM with slip weakening friction on a horizontal fault
# Uses BreakMeshByBlock to create interface, explicit time integration

Dc = 0.4
T2_o = 120e6
mu_d = 0.525
len = 500
q = 0.1

[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 2
    nx = 4
    ny = 4
    xmin = -1000
    xmax = 1000
    ymin = -1000
    ymax = 1000
  []
  [block1]
    type = ParsedSubdomainMeshGenerator
    input = gen
    combinatorial_geometry = 'y>0'
    block_id = 1
  []
  [block2]
    type = ParsedSubdomainMeshGenerator
    input = block1
    combinatorial_geometry = 'y<0'
    block_id = 2
  []
  [split]
    type = BreakMeshByBlockGenerator
    input = block2
    split_interface = true
    block_pairs = '1 2'
  []
  [sidesets]
    input = split
    type = SideSetsFromNormalsGenerator
    normals = '-1 0 0
               1 0 0
               0 -1 0
               0 1 0'
    new_boundary = 'left right bottom top'
  []
[]

[GlobalParams]
  displacements = 'disp_x disp_y'
  q = ${q}
  Dc = ${Dc}
  T2_o = ${T2_o}
  mu_d = ${mu_d}
  len = ${len}
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
  [resid_slipweakening_x]
    order = FIRST
    family = LAGRANGE
  []
  [resid_slipweakening_y]
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
  [vel_slipweakening_x]
    order = FIRST
    family = LAGRANGE
  []
  [vel_slipweakening_y]
    order = FIRST
    family = LAGRANGE
  []
  [mu_s]
    order = CONSTANT
    family = MONOMIAL
  []
  [ini_shear_stress]
    order = CONSTANT
    family = MONOMIAL
  []
[]

[Modules/TensorMechanics/CohesiveZoneMaster]
  [czm_ik]
    boundary = 'Block1_Block2'
    strain = SMALL
    generate_output = 'traction_x traction_y jump_x jump_y'
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

[Functions]
  [func_mu_s]
    type = ConstantFunction
    value = 0.677
  []
  [func_shear_stress]
    type = ConstantFunction
    value = 81.6e6
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
  [StaticFricCoeff]
    type = FunctionAux
    variable = mu_s
    function = func_mu_s
    execute_on = 'LINEAR TIMESTEP_BEGIN'
  []
  [StrikeShearStress]
    type = FunctionAux
    variable = ini_shear_stress
    function = func_shear_stress
    execute_on = 'LINEAR TIMESTEP_BEGIN'
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
  [czm_mat]
    type = SlipWeakeningFrictionczm2d
    disp_slipweakening_x = disp_slipweakening_x
    disp_slipweakening_y = disp_slipweakening_y
    reaction_slipweakening_x = resid_slipweakening_x
    reaction_slipweakening_y = resid_slipweakening_y
    mu_s = mu_s
    ini_shear_sts = ini_shear_stress
    boundary = 'Block1_Block2'
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

[Executioner]
  type = Transient
  dt = 0.001
  num_steps = 5
  [TimeIntegrator]
    type = CentralDifference
    solve_type = lumped
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
  [max_disp_y]
    type = NodalExtremeValue
    variable = disp_y
    value_type = max
  []
[]

[Outputs]
  csv = true
  exodus = true
[]

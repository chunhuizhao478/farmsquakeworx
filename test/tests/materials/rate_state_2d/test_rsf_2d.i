# Integration test for RateStateFrictionLaw2D + RateStateInterfaceKernelGlobal(x,y)
# 2D rate-and-state friction on a horizontal fault
# Exercises CZMComputeLocalTractionBaseRSF2D, CZMComputeLocalTractionTotalBaseRSF2D,
# RateStateFrictionLaw2D, RateStateInterfaceKernelGlobalx, RateStateInterfaceKernelGlobaly

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
  [reaction_rsf_x]
    order = FIRST
    family = LAGRANGE
  []
  [reaction_rsf_y]
    order = FIRST
    family = LAGRANGE
  []
  [reaction_damp_x]
    order = FIRST
    family = LAGRANGE
  []
  [reaction_damp_y]
    order = FIRST
    family = LAGRANGE
  []
  [Ts_perturb]
    order = FIRST
    family = LAGRANGE
  []
  [vel_x]
    order = FIRST
    family = LAGRANGE
  []
  [vel_y]
    order = FIRST
    family = LAGRANGE
  []
  [scaled_vel_x]
    order = FIRST
    family = LAGRANGE
  []
  [scaled_vel_y]
    order = FIRST
    family = LAGRANGE
  []
[]

[Physics/SolidMechanics/CohesiveZone]
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
        extra_vector_tags = 'restore_tag rsf_tag'
      []
    []
  []
[]

[Problem]
  extra_tag_vectors = 'restore_tag rsf_tag damp_tag'
[]

[Functions]
  [func_Ts_perturb]
    type = ConstantFunction
    value = 0
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
  [rsf_tag_x]
    type = TagVectorAux
    vector_tag = 'rsf_tag'
    v = 'disp_x'
    variable = 'reaction_rsf_x'
  []
  [rsf_tag_y]
    type = TagVectorAux
    vector_tag = 'rsf_tag'
    v = 'disp_y'
    variable = 'reaction_rsf_y'
  []
  [damp_tag_x]
    type = TagVectorAux
    vector_tag = 'damp_tag'
    v = 'disp_x'
    variable = 'reaction_damp_x'
  []
  [damp_tag_y]
    type = TagVectorAux
    vector_tag = 'damp_tag'
    v = 'disp_y'
    variable = 'reaction_damp_y'
  []
  [get_Ts_perturb]
    type = FunctionAux
    variable = Ts_perturb
    function = func_Ts_perturb
    execute_on = 'INITIAL TIMESTEP_BEGIN'
  []
  [Vel_x]
    type = CompVarRate
    variable = vel_x
    coupled = disp_x
    execute_on = 'TIMESTEP_END'
  []
  [Vel_y]
    type = CompVarRate
    variable = vel_y
    coupled = disp_y
    execute_on = 'TIMESTEP_END'
  []
  [Scale_vel_x]
    type = ScaleVarAux
    variable = scaled_vel_x
    coupled = vel_x
    scale = 2.0
    execute_on = 'TIMESTEP_END'
  []
  [Scale_vel_y]
    type = ScaleVarAux
    variable = scaled_vel_y
    coupled = vel_y
    scale = 2.0
    execute_on = 'TIMESTEP_END'
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
    extra_vector_tags = 'damp_tag'
  []
  [damping_y]
    type = StiffPropDamping
    variable = disp_y
    component = 1
    extra_vector_tags = 'damp_tag'
  []
[]

[InterfaceKernels]
  [rsf_ik_x]
    type = RateStateInterfaceKernelGlobalx
    variable = disp_x
    neighbor_var = disp_x
    boundary = 'Block1_Block2'
  []
  [rsf_ik_y]
    type = RateStateInterfaceKernelGlobaly
    variable = disp_y
    neighbor_var = disp_y
    boundary = 'Block1_Block2'
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
  [rsf_mat]
    type = RateStateFrictionLaw2D
    Tn_o = 120e6
    Ts_o = 75e6
    Vini = 1e-12
    statevarini = 1.606238
    len = 500
    f_o = 0.6
    rsf_a = 0.008
    rsf_b = 0.012
    rsf_L = 0.02
    delta_o = 1e-6
    reaction_rsf_x = reaction_rsf_x
    reaction_rsf_y = reaction_rsf_y
    reaction_damp_x = reaction_damp_x
    reaction_damp_y = reaction_damp_y
    Ts_perturb = Ts_perturb
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

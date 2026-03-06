# Integration test for RateStateFrictionLaw3D + RateStateInterfaceKernelGlobal(x,y,z)
# 3D rate-and-state friction on a horizontal fault
# Exercises CZMComputeLocalTractionBaseRSF3D, CZMComputeLocalTractionTotalBaseRSF3D,
# RateStateFrictionLaw3D, RateStateInterfaceKernelGlobalx/y/z

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
  [reaction_rsf_x]
    order = FIRST
    family = LAGRANGE
  []
  [reaction_rsf_y]
    order = FIRST
    family = LAGRANGE
  []
  [reaction_rsf_z]
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
  [reaction_damp_z]
    order = FIRST
    family = LAGRANGE
  []
  [Ts_perturb]
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
  [restore_z]
    type = TagVectorAux
    vector_tag = 'restore_tag'
    v = 'disp_z'
    variable = 'resid_z'
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
  [rsf_tag_z]
    type = TagVectorAux
    vector_tag = 'rsf_tag'
    v = 'disp_z'
    variable = 'reaction_rsf_z'
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
  [damp_tag_z]
    type = TagVectorAux
    vector_tag = 'damp_tag'
    v = 'disp_z'
    variable = 'reaction_damp_z'
  []
  [get_Ts_perturb]
    type = FunctionAux
    variable = Ts_perturb
    function = func_Ts_perturb
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
    extra_vector_tags = 'damp_tag'
  []
  [damping_y]
    type = StiffPropDamping
    variable = disp_y
    component = 1
    extra_vector_tags = 'damp_tag'
  []
  [damping_z]
    type = StiffPropDamping
    variable = disp_z
    component = 2
    extra_vector_tags = 'damp_tag'
  []
[]

[InterfaceKernels]
  [rsf_ik_x]
    type = RateStateInterfaceKernelGlobalx
    variable = disp_x
    neighbor_var = disp_x
    boundary = 'Block100_Block200'
  []
  [rsf_ik_y]
    type = RateStateInterfaceKernelGlobaly
    variable = disp_y
    neighbor_var = disp_y
    boundary = 'Block100_Block200'
  []
  [rsf_ik_z]
    type = RateStateInterfaceKernelGlobalz
    variable = disp_z
    neighbor_var = disp_z
    boundary = 'Block100_Block200'
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
    type = RateStateFrictionLaw3D
    Tn_o = 120e6
    Ts_o = 75e6
    Td_o = 0
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
    reaction_rsf_z = reaction_rsf_z
    reaction_damp_x = reaction_damp_x
    reaction_damp_y = reaction_damp_y
    reaction_damp_z = reaction_damp_z
    Ts_perturb = Ts_perturb
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

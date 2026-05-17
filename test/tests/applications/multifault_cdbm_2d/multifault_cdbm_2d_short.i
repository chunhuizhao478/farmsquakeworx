#parameters (auto-generated from JSON config)

CBH_constant = 0
C_1 = 0
C_2 = 0.05
C_g = 1e-12
CdCb_multiplier = 100
Cd_constant = 100000000
Dc = 0.4
beta_width = 0.05
cd_hat = 10
checkpoint_interval = 100
checkpoint_num_files = 2
chi = 0.8
csv_interval = 5
density = 2670
dt = 0.00125
end_time = 0.00625
exodus_interval = 5
lambda_o = 3.204e+10
len = 200
m1 = 10
m2 = 1
m_exponent = 0.8
mu_d = 0.525
mu_s = 0.677
nonlocal_averaging_length_scale = 200
nonlocal_averaging_radius = 400
nucl_center_x = 0
nucl_center_y = 0
nucl_radius = 200
p_wave_speed = 6000
peak_shear_stress = 81600000
q = 0.2
shear_modulus_o = 3.204e+10
shear_wave_speed = 3464.101615
strain_rate_hat = 5e-09
use_strain_rate_dependent_Cd = false
xi_0 = -0.9
xi_d = -0.9
xi_max = 1.8
xi_min = -1.8


# Multi-Fault 2D Dynamic Rupture Simulation - CDBM (auto-generated)

[Mesh]
  [./msh]
    type = FileMeshGenerator
    file = 'output.msh'
  []
  [./subdomain_id]
    input = msh
    type = SubdomainPerElementGenerator
    element_ids = '
    47 175 204 205 206 207 208 209 211 228 245 8 9 10 11 12 13 20 21 22 23
    '
    subdomain_ids = '
    100 100 100 100 100 100 100 100 100 100 100 200 200 200 200 200 200 200 200 200 200
    '
  []
  [./split]
    type = BreakMeshByBlockGenerator
    input = subdomain_id
    split_interface = true
    block_pairs = '100 200'
  []
  [./sidesets]
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
  mu_s = ${mu_s}
  mu_d = ${mu_d}
  len = ${len}
  lambda_o = ${lambda_o}
  shear_modulus_o = ${shear_modulus_o}
  xi_0 = ${xi_0}
  xi_d = ${xi_d}
  xi_max = ${xi_max}
  xi_min = ${xi_min}
  Cd_constant = ${Cd_constant}
  CdCb_multiplier = ${CdCb_multiplier}
  CBH_constant = ${CBH_constant}
  C_1 = ${C_1}
  C_2 = ${C_2}
  beta_width = ${beta_width}
  C_g = ${C_g}
  m1 = ${m1}
  m2 = ${m2}
  chi = ${chi}
[]

[AuxVariables]
  [./resid_x]
    order = FIRST
    family = LAGRANGE
  [../]
  [./resid_y]
    order = FIRST
    family = LAGRANGE
  []
  [./resid_slipweakening_x]
    order = FIRST
    family = LAGRANGE
  [../]
  [./resid_slipweakening_y]
    order = FIRST
    family = LAGRANGE
  [../]
  [./disp_slipweakening_x]
    order = FIRST
    family = LAGRANGE
  []
  [./disp_slipweakening_y]
    order = FIRST
    family = LAGRANGE
  []
  [./vel_slipweakening_x]
    order = FIRST
    family = LAGRANGE
  []
  [./vel_slipweakening_y]
    order = FIRST
    family = LAGRANGE
  []
  [./alpha_damagedvar_aux]
    order = FIRST
    family = MONOMIAL
  []
  [./B_aux]
    order = FIRST
    family = MONOMIAL
  []
  [./xi_aux]
    order = FIRST
    family = MONOMIAL
  []
  [./eqstrain_nonlocal_aux]
    order = FIRST
    family = MONOMIAL
  []
  [./deviatoric_strain_rate_aux]
    order = FIRST
    family = MONOMIAL
  []
  [./jump_strike_aux]
    order = FIRST
    family = MONOMIAL
  []
  [./jump_normal_aux]
    order = FIRST
    family = MONOMIAL
  []
  [./jump_strike_rate_aux]
    order = FIRST
    family = MONOMIAL
  []
  [./jump_normal_rate_aux]
    order = FIRST
    family = MONOMIAL
  []
  [./traction_strike_aux]
    order = FIRST
    family = MONOMIAL
  []
  [./traction_normal_aux]
    order = FIRST
    family = MONOMIAL
  []
[]

[Physics/SolidMechanics/CohesiveZone]
  [./czm_ik]
    boundary = 'Block100_Block200'
    strain = SMALL
    generate_output = 'traction_x traction_y jump_x jump_y'
  [../]
[]

[Physics]
  [SolidMechanics]
    [QuasiStatic]
      [all]
        strain = SMALL
        add_variables = true
        planar_formulation = PLANE_STRAIN
        generate_output = 'stress_xx stress_yy stress_xy'
        extra_vector_tags = 'restore_tag'
      []
    []
  []
[]

[Problem]
  extra_tag_vectors = 'restore_tag'
[]

[Functions]
  [func_initial_stress_xx]
    type = ConstantFunction
    value = -120000000
  []
  [func_initial_stress_xy]
    type = ConstantFunction
    value = 70000000
  []
  [func_initial_stress_yy]
    type = ConstantFunction
    value = -120000000
  []
  [func_zero]
    type = ConstantFunction
    value = 0.0
  []
[]

[AuxKernels]
  [Displacment_x]
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
  [get_alpha_damagedvar]
    type = MaterialRealAux
    property = alpha_damagedvar
    variable = alpha_damagedvar_aux
    execute_on = 'TIMESTEP_END'
  []
  [get_B]
    type = MaterialRealAux
    property = B
    variable = B_aux
    execute_on = 'TIMESTEP_END'
  []
  [get_xi]
    type = MaterialRealAux
    property = xi
    variable = xi_aux
    execute_on = 'TIMESTEP_END'
  []
  [get_eqstrain_nonlocal]
    type = MaterialRealAux
    property = eqstrain_nonlocal
    variable = eqstrain_nonlocal_aux
    execute_on = 'TIMESTEP_END'
  []
  [get_deviatoric_strain_rate]
    type = MaterialRealAux
    property = deviatoric_strain_rate
    variable = deviatoric_strain_rate_aux
    execute_on = 'TIMESTEP_END'
  []
  [get_jump_strike]
    type = MaterialRealAux
    property = displacement_jump_strike
    variable = jump_strike_aux
    boundary = 'Block100_Block200'
    execute_on = 'TIMESTEP_END'
  []
  [get_jump_normal]
    type = MaterialRealAux
    property = displacement_jump_normal
    variable = jump_normal_aux
    boundary = 'Block100_Block200'
    execute_on = 'TIMESTEP_END'
  []
  [get_jump_strike_rate]
    type = MaterialRealAux
    property = displacement_jump_rate_strike
    variable = jump_strike_rate_aux
    boundary = 'Block100_Block200'
    execute_on = 'TIMESTEP_END'
  []
  [get_jump_normal_rate]
    type = MaterialRealAux
    property = displacement_jump_rate_normal
    variable = jump_normal_rate_aux
    boundary = 'Block100_Block200'
    execute_on = 'TIMESTEP_END'
  []
  [get_traction_strike]
    type = MaterialRealAux
    property = traction_strike
    variable = traction_strike_aux
    boundary = 'Block100_Block200'
    execute_on = 'TIMESTEP_END'
  []
  [get_traction_normal]
    type = MaterialRealAux
    property = traction_normal
    variable = traction_normal_aux
    boundary = 'Block100_Block200'
    execute_on = 'TIMESTEP_END'
  []
[]

[Kernels]
  [./inertia_x]
    type = InertialForce
    use_displaced_mesh = false
    variable = disp_x
  []
  [./inertia_y]
    type = InertialForce
    use_displaced_mesh = false
    variable = disp_y
  []
  [./Reactionx]
    type = StiffPropDamping
    variable = 'disp_x'
    component = '0'
  []
  [./Reactiony]
    type = StiffPropDamping
    variable = 'disp_y'
    component = '1'
  []
[]

[Materials]
  [stress_medium]
    type = ComputeDamageBreakageStress3DSlipWeakening
    output_properties = 'B alpha_damagedvar xi I1 I2 deviatoric_strain_rate'
    use_nonlocal_eqstrain = true
    # nonlocal_eqstrain_blocks intentionally omitted (Phase 0a) ->
    # applies on every block.
    static_solve_flag = false
    use_strain_rate_dependent_Cd = ${use_strain_rate_dependent_Cd}
    m_exponent = ${m_exponent}
    strain_rate_hat = ${strain_rate_hat}
    cd_hat = ${cd_hat}
    zero_Cd_below_threshold = true
    outputs = exodus
  []
  [dummy_material]
    type = GenericConstantMaterial
    prop_names = 'eqstrain_nonlocal_initial initial_damage initial_breakage damage_perturbation density'
    prop_values = '-0.92 0 0 0 ${density}'
  []
  [./czm_mat]
    type = SlipWeakeningFrictionczm2dCDBM
    boundary = 'Block100_Block200'
    disp_slipweakening_x     = disp_slipweakening_x
    disp_slipweakening_y     = disp_slipweakening_y
    reaction_slipweakening_x = resid_slipweakening_x
    reaction_slipweakening_y = resid_slipweakening_y
    peak_shear_stress = ${peak_shear_stress}
    nucl_center = '${nucl_center_x} ${nucl_center_y}'
    nucl_radius = ${nucl_radius}
  [../]
  [./static_initial_strain_tensor]
    type = GenericFunctionRankTwoTensor
    tensor_name = static_initial_strain_tensor
    tensor_functions = 'func_zero func_zero func_zero
                        func_zero func_zero func_zero
                        func_zero func_zero func_zero'
  [../]
  [./static_initial_stress_tensor]
    type = GenericFunctionRankTwoTensor
    tensor_name = static_initial_stress_tensor
    tensor_functions = 'func_initial_stress_xx func_initial_stress_xy func_zero
                        func_initial_stress_xy func_initial_stress_yy func_zero
                        func_zero               func_zero               func_zero'
  [../]
  [nonlocal_eqstrain_global]
    type = ElkNonlocalEqstrainUpdated
    average_UO = eqstrain_averaging_global
  []
[]

[UserObjects]
  [recompute_residual_tag]
    type = ResidualEvaluationUserObject
    vector_tag = 'restore_tag'
    force_preaux = true
    execute_on = 'TIMESTEP_END'
  []
  [eqstrain_averaging_global]
    type = ElkRadialAverageUpdated
    length_scale = ${nonlocal_averaging_length_scale}
    prop_name = xi
    radius = ${nonlocal_averaging_radius}
    weights = BAZANT
    execute_on = TIMESTEP_END
  []
[]

[Executioner]
  type = Transient
  dt = ${dt}
  end_time = ${end_time}
  [TimeIntegrator]
    type = CentralDifference
    solve_type = lumped
    use_constant_mass = true
  []
[]

[Outputs]
  [exodus]
    type = Exodus
    execute_on = 'timestep_end'
    time_step_interval = ${exodus_interval}
  []
  [csv]
    type = CSV
    execute_on = 'timestep_end'
    time_step_interval = ${csv_interval}
  []
  [out]
    type = Checkpoint
    time_step_interval = ${checkpoint_interval}
    num_files = ${checkpoint_num_files}
  []
[]

[BCs]
  [./dashpot_top_x]
    type = NonReflectDashpotBC
    component = 0
    variable = disp_x
    disp_x = disp_x
    disp_y = disp_y
    p_wave_speed = ${p_wave_speed}
    shear_wave_speed = ${shear_wave_speed}
    boundary = top
  []
  [./dashpot_top_y]
    type = NonReflectDashpotBC
    component = 1
    variable = disp_y
    disp_x = disp_x
    disp_y = disp_y
    p_wave_speed = ${p_wave_speed}
    shear_wave_speed = ${shear_wave_speed}
    boundary = top
  []
  [./dashpot_bottom_x]
    type = NonReflectDashpotBC
    component = 0
    variable = disp_x
    disp_x = disp_x
    disp_y = disp_y
    p_wave_speed = ${p_wave_speed}
    shear_wave_speed = ${shear_wave_speed}
    boundary = bottom
  []
  [./dashpot_bottom_y]
    type = NonReflectDashpotBC
    component = 1
    variable = disp_y
    disp_x = disp_x
    disp_y = disp_y
    p_wave_speed = ${p_wave_speed}
    shear_wave_speed = ${shear_wave_speed}
    boundary = bottom
  []
  [./dashpot_left_x]
    type = NonReflectDashpotBC
    component = 0
    variable = disp_x
    disp_x = disp_x
    disp_y = disp_y
    p_wave_speed = ${p_wave_speed}
    shear_wave_speed = ${shear_wave_speed}
    boundary = left
  []
  [./dashpot_left_y]
    type = NonReflectDashpotBC
    component = 1
    variable = disp_y
    disp_x = disp_x
    disp_y = disp_y
    p_wave_speed = ${p_wave_speed}
    shear_wave_speed = ${shear_wave_speed}
    boundary = left
  []
  [./dashpot_right_x]
    type = NonReflectDashpotBC
    component = 0
    variable = disp_x
    disp_x = disp_x
    disp_y = disp_y
    p_wave_speed = ${p_wave_speed}
    shear_wave_speed = ${shear_wave_speed}
    boundary = right
  []
  [./dashpot_right_y]
    type = NonReflectDashpotBC
    component = 1
    variable = disp_y
    disp_x = disp_x
    disp_y = disp_y
    p_wave_speed = ${p_wave_speed}
    shear_wave_speed = ${shear_wave_speed}
    boundary = right
  []
[]

[VectorPostprocessors]
  [fault_1]
    type = SideValueSampler
    variable = 'jump_strike_aux jump_normal_aux jump_strike_rate_aux jump_normal_rate_aux traction_strike_aux traction_normal_aux alpha_damagedvar_aux B_aux'
    boundary = 'Block100_Block200'
    sort_by = x
  []
[]

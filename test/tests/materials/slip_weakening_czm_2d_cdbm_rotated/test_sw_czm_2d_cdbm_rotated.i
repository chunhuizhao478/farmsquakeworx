# Phase-1.5 rotation regression test for SlipWeakeningFrictionczm2dCDBM
#
# Verifies that the Phase-0b stress-tensor rotation produces correct
# fault-local tractions on a 45-degree fault.
#
# Mesh: 1x1 GeneratedMeshGenerator with TRI3, split along the y=x diagonal.
#   Block 1: y > x (upper-left triangle)
#   Block 2: y < x (lower-right triangle)
#   Interface: 'Block1_Block2', oriented at 45 deg to the global x-axis.
#
# Background stress (matches the elastic-app multifault example):
#   sigma_xx = -100e6, sigma_yy = -120e6, sigma_xy = 20e6
#
# Analytic decomposition for a 45-degree fault:
#   tangent t = (1, 1)/sqrt(2), normal n = (-1, 1)/sqrt(2)
#   Traction on fault plane T = sigma . n = (120e6/sqrt(2), -140e6/sqrt(2))
#   T . n  = -130e6  (compression-negative in this projection)
#   T . t  = -10e6
#
# Per the CZM convention used in SlipWeakeningFrictionczm2dCDBM (mirroring
# SlipWeakeningFrictionczm2dParametricStudy lines 165-178):
#   T1_o = traction_local(1)  (shear, local-tangential)            = -10e6 Pa
#   T2_o = -traction_local(0) (normal, compression-positive)       = +130e6 Pa
#
# At t = 0 (no slip yet, no inertia, no reactions) the material stores:
#   _traction_strike[_qp] = T1 = T1_o          = -10e6   Pa
#   _traction_normal[_qp] = T2 = -T2_o         = -130e6  Pa
#   (T2 stays negative because of the open-fault clamp `if (T2 >= 0) T2 = 0`).
#
# CSVDiff against gold/test_sw_czm_2d_cdbm_rotated_out.csv with abs_zero=1e3
# (1 kPa absolute tolerance).

[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 2
    nx = 1
    ny = 1
    xmin = -1.0
    xmax =  1.0
    ymin = -1.0
    ymax =  1.0
    elem_type = TRI3
  []
  [block1]
    type = ParsedSubdomainMeshGenerator
    input = gen
    combinatorial_geometry = 'y > x'
    block_id = 1
  []
  [block2]
    type = ParsedSubdomainMeshGenerator
    input = block1
    combinatorial_geometry = 'y < x'
    block_id = 2
  []
  [split]
    type = BreakMeshByBlockGenerator
    input = block2
    split_interface = true
    block_pairs = '1 2'
  []
  [sidesets]
    type = SideSetsFromNormalsGenerator
    input = split
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
  [traction_strike_aux]
    order = CONSTANT
    family = MONOMIAL
  []
  [traction_normal_aux]
    order = CONSTANT
    family = MONOMIAL
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
    value = -100e6
  []
  [func_initial_stress_xy]
    type = ConstantFunction
    value = 20e6
  []
  [func_initial_stress_yy]
    type = ConstantFunction
    value = -120e6
  []
  [func_zero]
    type = ConstantFunction
    value = 0.0
  []
[]

[AuxKernels]
  [Disp_x]
    type = ProjectionAux
    variable = disp_slipweakening_x
    v = disp_x
    execute_on = 'TIMESTEP_BEGIN'
  []
  [Disp_y]
    type = ProjectionAux
    variable = disp_slipweakening_y
    v = disp_y
    execute_on = 'TIMESTEP_BEGIN'
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
  [get_traction_strike]
    type = MaterialRealAux
    property = traction_strike
    variable = traction_strike_aux
    boundary = 'Block1_Block2'
    execute_on = 'TIMESTEP_END'
  []
  [get_traction_normal]
    type = MaterialRealAux
    property = traction_normal
    variable = traction_normal_aux
    boundary = 'Block1_Block2'
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
    q = 0.0
  []
  [damping_y]
    type = StiffPropDamping
    variable = disp_y
    component = 1
    q = 0.0
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
                        func_zero               func_zero               func_zero'
  []
  [czm_mat]
    type = SlipWeakeningFrictionczm2dCDBM
    boundary = 'Block1_Block2'
    disp_slipweakening_x     = disp_slipweakening_x
    disp_slipweakening_y     = disp_slipweakening_y
    reaction_slipweakening_x = resid_slipweakening_x
    reaction_slipweakening_y = resid_slipweakening_y
    mu_s = 0.677
    mu_d = 0.525
    Dc = 0.4
    len = 2.0
    peak_shear_stress = 0.0
    nucl_center = '0.0 0.0'
    nucl_radius = 0.0
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
  dt = 1.0e-6
  num_steps = 1
  [TimeIntegrator]
    type = CentralDifference
    solve_type = lumped
  []
[]

[VectorPostprocessors]
  [fault_traction]
    type = SideValueSampler
    variable = 'traction_strike_aux traction_normal_aux'
    boundary = 'Block1_Block2'
    sort_by = x
  []
[]

[Outputs]
  csv = true
[]

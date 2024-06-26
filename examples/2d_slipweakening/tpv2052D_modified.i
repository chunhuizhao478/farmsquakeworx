# Verification of Benchmark Problem TPV205-2D from the SCEC Dynamic Rupture Validation exercises #
# Reference: #
# Harris, R. M.-P.-A. (2009). The SCEC/USGS Dynamic Earthquake Rupture Code Verification Exercise. Seismological Research Letters, vol. 80, no. 1, pages 119-126. #
# [Note]: This serves as a test file, to run the full problem, please extend the domain size by modifying nx, ny, xmin, xmax, ymin, ymax

[Mesh]
    [./msh]
      type = GeneratedMeshGenerator
      dim = 2
      nx = 10
      ny = 10
      xmin = -1.0
      xmax = 1.0
      ymin = -1.0
      ymax = 1.0
    []
    [./new_block]
      type = ParsedSubdomainMeshGenerator
      input = msh
      combinatorial_geometry = 'y<0'
      block_id = 1
    []
    [./split]
      type = BreakMeshByBlockGenerator
      input = new_block
      split_interface = true
    []
  []

  [GlobalParams]
    #primary variables
    displacements = 'disp_x disp_y'
    #damping ratio
    q = 0.1
    #characteristic length (m)
    Dc = 0.8
    #initial normal stress (Pa)
    T2_o = 10000000.0
    #dynamic friction coefficient
    mu_d = 0.1
    #element edge length (m)
    len = 0.2
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
    [./mu_s]
        order = CONSTANT
        family = MONOMIAL
    []
    [./ini_shear_stress]
        order = CONSTANT
        family = MONOMIAL
    []
    [./tangent_jump_rate]
        order = CONSTANT
        family = MONOMIAL
    []
    [./tangent_jump]
        order = CONSTANT
        family = MONOMIAL
    []
  []

  [Modules/TensorMechanics/CohesiveZoneMaster]
    [./czm_ik]
      boundary = 'Block0_Block1'
      strain = SMALL
      generate_output='traction_x traction_y jump_x jump_y normal_traction tangent_traction normal_jump tangent_jump'
    [../]
  []


  [Modules]
    [./TensorMechanics]
      [./Master]
        [./all]
          strain = SMALL
          add_variables = true
          planar_formulation = PLANE_STRAIN
          generate_output = 'stress_xx stress_yy stress_xy'
          extra_vector_tags = 'restore_tag'
        [../]
      [../]
    [../]
  []

  [Problem]
    extra_tag_vectors = 'restore_tag'
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
    [tangent_jump_rate]
      type = TimeDerivativeAux
      variable = tangent_jump_rate
      functor = tangent_jump
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
      execute_on = 'TIMESTEP_END'
    []
    [restore_y]
      type = TagVectorAux
      vector_tag = 'restore_tag'
      v = 'disp_y'
      variable = 'resid_y'
      execute_on = 'TIMESTEP_END'
    []
    [StaticFricCoeff]
      type = FunctionAux
      variable = mu_s
      function = func_static_friction_coeff_mus
      execute_on = 'LINEAR TIMESTEP_BEGIN'
    []
    [StrikeShearStress]
      type = FunctionAux
      variable = ini_shear_stress
      function = func_initial_strike_shear_stress
      execute_on = 'LINEAR TIMESTEP_BEGIN'
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
    [elasticity]
        type = ComputeIsotropicElasticityTensor
        lambda = 10000000000.0
        shear_modulus = 10000000000.0
        use_displaced_mesh = false
    []
    [stress]
        type = ComputeLinearElasticStress
    []
    [density]
        type = GenericConstantMaterial
        prop_names = density
        prop_values = 2700.0
    []
    [./czm_mat]
        type = SlipWeakeningFriction2d
        disp_slipweakening_x     = disp_slipweakening_x
        disp_slipweakening_y     = disp_slipweakening_y
        reaction_slipweakening_x = resid_slipweakening_x
        reaction_slipweakening_y = resid_slipweakening_y
        mu_s = mu_s
        ini_shear_sts = ini_shear_stress
        boundary = 'Block0_Block1'
    [../]
  []

  [Functions]
    [func_static_friction_coeff_mus]
      type = PiecewiseConstant
      axis=x
      x = '-1000e3 -15e3 15e3'
      y = '10000 0.677 10000.0'
      direction = left
    []
    [func_initial_strike_shear_stress]
      type = PiecewiseConstant
      axis=x
      x = '-1000e3 -9.0e3 -6.0e3 -1.5e3  1.5e3  6.0e3  9.0e3'
      y = ' 70.0e6 78.0e6 70.0e6 81.6e6 70.0e6 62.0e6 70.0e6'
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
    dt = 0.1
    num_steps =1
    [TimeIntegrator]
      type = CentralDifference
      solve_type = lumped
    []
  []

  [Outputs]
    csv = true
    interval = 100
  []

  [Postprocessors]
    [./tangent_jump_elem300]
      type = ElementalVariableValue
      variable = tangent_jump
      elementid = 300
      outputs = csv
    []
    [./tangent_jump_elem290]
      type = ElementalVariableValue
      variable = tangent_jump
      elementid = 290
      outputs = csv
    []
    [./tangent_jump_elem310]
      type = ElementalVariableValue
      variable = tangent_jump
      elementid = 310
      outputs = csv
    []
  []

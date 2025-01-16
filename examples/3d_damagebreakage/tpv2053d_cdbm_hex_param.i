#--------------Parameter File----------------#
#Please refer to documentation for details
## Mesh and Geometry Parameters
#--------------------------------------------#
xmin = -15000 #minmum x value for domain
xmax = 15000 #maximum x value for domain
ymin = -20000 #minmum y value for domain
#assume ymax = 0 #maximum y value for domain
zmin = -10000 #minmum z value for domain
zmax = 10000 #maximum z value for domain
nx = 150 #number of elements in x direction
ny = 100 #number of elements in y direction
nz = 100 #number of elements in z direction
## Fault Plane Parameters
#--------------------------------------------#
fxmin = -15000 #minmum x value for fault plane
fxmax = 15000 #maximum x value for fault plane
fymin = -15000 #minmum y value for fault plane
#assume fymax = 0
## Material Properties
#--------------------------------------------#
q = 0.4 #damping ratio
Dc = 1.5 #characteristic length (m)
lambda_o = 32.04e9 #initial lambda value (first lame constant) [Pa]
shear_modulus_o = 32.04e9 #initial shear modulus value (second lame constant) [Pa]
pressure_wave_speed = 6000 #p wave speed [m/s]
shear_wave_speed = 3464 #s wave speed [m/s]
density = 2670 #density [kg/m^3]
xi_0 = -0.8 #strain invariants ratio: onset of damage evolution
xi_d = -0.8 #strain invariants ratio: onset of breakage healing
Cd_constant = 1e5 #coefficient gives positive damage evolution
CdCb_multiplier = 100 #The multiplier between Cd and Cb
CBH_constant = 1e4 #coefficient of healing for breakage evolution
C_1 = 0 #coefficient of healing for damage evolution
C_2 = 0.05 #coefficient of healing for damage evolution
beta_width = 0.03 #coefficient gives width of transitional region
C_g = 1e-10 #material parameter: compliance or fluidity of the fine grain granular material
m1 = 10 #coefficient of power law indexes
m2 = 1 #coefficient of power law indexes
chi = 0.8 #energy ratio
## Friction Coefficients
#inside the patch, mu_s is set for slip weakening
#outside the patch, mu_s is set for high value to prevent slip
#--------------------------------------------#
patch_xmin = -15000 #minmum x value for patch
patch_xmax = 15000 #maximum x value for patch
patch_ymin = -15000 #minmum y value for patch
patch_ymax = 0 #maximum y value for patch
mu_s_patch = 0.677 #static friction coefficient for slip weakening
mu_s_outside = 10000 #static friction coefficient for outside the patch
mu_d = 0.3 #dynamic friction coefficient
## Initial Stress Field
#--------------------------------------------#
sts_xx = -135e6 #initial stress field xx component
sts_yy = -127.5e6 #initial stress field yy component
sts_zz = -120e6 #initial stress field zz component
sts_xy = 0 #initial stress field xy component
sts_yz = 0 #initial stress field yz component
### Shear Stress
#inside the nucleation patch, shear stress is set for value higher than frictional strength mu_s * sts_
#outside the patch, shear stress is set for a smaller value
nucl_xmin = -1.5e3 #minmum x value for nucleation patch
nucl_xmax = 1.5e3 #maximum x value for nucleation patch
nucl_ymin = -9e3 #minmum y value for nucleation patch
nucl_ymax = -6e3 #maximum y value for nucleation patch
nucl_zmin = -200 #minmum z value for nucleation patch
nucl_zmax = 200 #maximum z value for nucleation patch
T1_o_nucl = 81.6e6 #shear stress value for nucleation patch
T1_o = 70.0e6 #shear stress value for rest of the domain
## Simulation Parameters
#--------------------------------------------#
elem_length = 200 #element length
dt = 0.0025 #time step
end_time = 0.025 #end time
time_step_interval = 1 #time step interval for output
#--------------------------------------------#

#-------------Main Input File----------------#
#Main code for running the simulation
#We don't recommend changing this file
#--------------------------------------------#
[Mesh]
  [msh]
    type = GeneratedMeshGenerator
    dim = 3
    xmin = ${xmin}
    xmax = ${xmax}
    ymin = ${ymin}
    ymax = 0
    zmin = ${zmin}
    zmax = ${zmax}
    nx = ${nx}
    ny = ${ny}
    nz = ${nz}
    subdomain_ids = 1
  []
  [./new_block_1]
    type = ParsedSubdomainMeshGenerator
    input = msh
    combinatorial_geometry = 'x >= ${fxmin} & x <= ${fxmax} & y > ${fymin} & z < 0'
    block_id = 2
  []
  [./new_block_2]
      type = ParsedSubdomainMeshGenerator
      input = new_block_1
      combinatorial_geometry = 'x > ${fxmin} & x < ${fxmax} & y > ${fymin} & z > 0'
      block_id = 3
  []      
    [./split_1]
        type = BreakMeshByBlockGenerator
        input = new_block_2
        split_interface = true
        block_pairs = '2 3'
    []      
    [./sidesets]
      input = split_1
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
    ##------------slip weakening------------##
    displacements = 'disp_x disp_y disp_z'
    
    #damping ratio
    q = ${q}
    
    #characteristic length (m) #this gives ~200m for resolve L_f
    Dc = ${Dc}
    
    ##----continuum damage breakage model----##
    #initial lambda value (first lame constant) [Pa]
    lambda_o = ${lambda_o}
        
    #initial shear modulus value (second lame constant) [Pa]
    shear_modulus_o = ${shear_modulus_o}
    
    #<strain invariants ratio: onset of damage evolution>: relate to internal friction angle, refer to "note_mar25"
    xi_0 = ${xi_0}
    
    #<strain invariants ratio: onset of breakage healing>: tunable param, see ggw183.pdf
    xi_d = ${xi_d}
    
    #<strain invariants ratio: maximum allowable value>: set boundary
    #Xu_etal_P15-2D
    #may need a bit space, use 1.5 as boundary
    xi_max = 1.8
    
    #<strain invariants ratio: minimum allowable value>: set boundary
    #Xu_etal_P15-2D
    xi_min = -1.8

    #if option 2, use Cd_constant
    Cd_constant = ${Cd_constant}

    #<coefficient gives positive breakage evolution >: refer to "Lyak_BZ_JMPS14_splitstrain" Table 1
    #The multiplier between Cd and Cb: Cb = CdCb_multiplier * Cd
    CdCb_multiplier = ${CdCb_multiplier}

    #<coefficient of healing for breakage evolution>: refer to "Lyakhovsky_Ben-Zion_P14" (10 * C_B)
    # CBCBH_multiplier = 0.0
    CBH_constant = ${CBH_constant}

    #<coefficient of healing for damage evolution>: refer to "ggw183.pdf"
    C_1 = ${C_1}

    #<coefficient of healing for damage evolution>: refer to "ggw183.pdf"
    C_2 = ${C_2}

    #<coefficient gives width of transitional region>: see P(alpha), refer to "Lyak_BZ_JMPS14_splitstrain" Table 1
    beta_width = ${beta_width} #1e-3
    
    #<material parameter: compliance or fluidity of the fine grain granular material>: refer to "Lyak_BZ_JMPS14_splitstrain" Table 1
    C_g = ${C_g}
    
    #<coefficient of power law indexes>: see flow rule (power law rheology): refer to "Lyak_BZ_JMPS14_splitstrain" Table 1
    m1 = ${m1}
    
    #<coefficient of power law indexes>: see flow rule (power law rheology): refer to "Lyak_BZ_JMPS14_splitstrain" Equation 18
    m2 = ${m2}
    
    # energy ratio
    chi = ${chi}

    # diffusion coefficient (assume 0)
    D = 0
    
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
      [./resid_z]
        order = FIRST
        family = LAGRANGE
      []
      #restoration force for damping (tag after solve)
      [./resid_damp_x]
        order = FIRST
        family = LAGRANGE
      [../]
      [./resid_damp_y]
          order = FIRST
          family = LAGRANGE
      [../] 
      [./resid_damp_z]
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
      [./disp_slipweakening_z]
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
      [./vel_slipweakening_z]
        order = FIRST
        family = LAGRANGE
      []
      [./accel_slipweakening_x]
        order = FIRST
        family = LAGRANGE
      []
      [./accel_slipweakening_y]
          order = FIRST
          family = LAGRANGE
      []
      [./accel_slipweakening_z]
        order = FIRST
        family = LAGRANGE
      []
      [./mu_s]
          order = CONSTANT
          family = MONOMIAL
      []
      [./mu_d]
          order = CONSTANT
          family = MONOMIAL
      []
      [./ini_shear_stress]
          order = FIRST
          family = LAGRANGE
      []
      #
      [./tangent_jump]
        order = CONSTANT
        family = MONOMIAL
      []
      [./tangent_jump_rate]
          order = CONSTANT
          family = MONOMIAL
      []
      #
      [./elem_length]
          order = CONSTANT
          family = MONOMIAL
      [../]
      #
      [./jump_x]
          order = CONSTANT
          family = MONOMIAL        
      []
      [./jump_y]
          order = CONSTANT
          family = MONOMIAL        
      []
      [./jump_z]
          order = CONSTANT
          family = MONOMIAL         
      []
      #
      [jump_rate_x]
          order = CONSTANT
          family = MONOMIAL
      []
      [jump_rate_y]
          order = CONSTANT
          family = MONOMIAL
      []
      [jump_rate_z]
          order = CONSTANT
          family = MONOMIAL
      []
      #
      [traction_x]
          order = CONSTANT
          family = MONOMIAL
      []
      [traction_y]
          order = CONSTANT
          family = MONOMIAL
      []
      [traction_z]
          order = CONSTANT
          family = MONOMIAL
      [] 
      [initial_damage_aux]
        order = CONSTANT
        family = MONOMIAL
      []
      [initial_breakage_aux]
          order = CONSTANT
          family = MONOMIAL
      []
      [initial_shear_stress_aux]
          order = CONSTANT
          family = MONOMIAL
      []
      #grad_alpha
      [./alpha_grad_x]
      []
      [./alpha_grad_y]
      []
      [./alpha_grad_z]
      []
      #
      [./check_function_initial_stress_xx]
        order = FIRST
        family = LAGRANGE      
      []
      [./check_function_initial_stress_xy]
        order = FIRST
        family = LAGRANGE      
      []
      [./check_function_initial_stress_xz]
        order = FIRST
        family = LAGRANGE      
      []
      [./check_function_initial_stress_yy]
        order = FIRST
        family = LAGRANGE      
      []
      [./check_function_initial_stress_yz]
        order = FIRST
        family = LAGRANGE      
      []
      [./check_function_initial_stress_zz]
        order = FIRST
        family = LAGRANGE      
      []
      #
      [cohesion_aux]
        order = FIRST
        family = LAGRANGE         
      []
      [forced_rupture_time_aux]
        order = FIRST
        family = LAGRANGE      
      []   
  []
  
  [Physics]
    [SolidMechanics]
      [QuasiStatic]
        [./all]
          strain = SMALL
          add_variables = true
          extra_vector_tags = 'restore_tag'
        [../]
      [../]
    [../]
  []
  
  [Problem]
      extra_tag_vectors = 'restore_tag restore_dampx_tag restore_dampy_tag restore_dampz_tag'
  []
  
  [AuxKernels]
      [Displacment_x]
        type = ProjectionAux
        variable = disp_slipweakening_x
        v = disp_x
        execute_on = 'TIMESTEP_END'
      []
      [Displacement_y]
        type = ProjectionAux
        variable = disp_slipweakening_y
        v = disp_y
        execute_on = 'TIMESTEP_END'
      []
      [Displacement_z]
        type = ProjectionAux
        variable = disp_slipweakening_z
        v = disp_z
        execute_on = 'TIMESTEP_END'
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
      #
      [XJump]
          type = MaterialRealVectorValueAux
          property = displacement_jump_global
          variable = jump_x
          component = 0
          execute_on = 'TIMESTEP_END'
          boundary = 'Block2_Block3'
      []
      [YJump]
          type = MaterialRealVectorValueAux
          property = displacement_jump_global
          variable = jump_y
          component = 1
          execute_on = 'TIMESTEP_END'
          boundary = 'Block2_Block3'
      []
      [ZJump]
          type = MaterialRealVectorValueAux
          property = displacement_jump_global
          variable = jump_z
          component = 2
          execute_on = 'TIMESTEP_END'
          boundary = 'Block2_Block3'
      []
      #
      [XJumpRate]
          type = MaterialRealVectorValueAux
          property = displacement_jump_rate_global
          variable = jump_rate_x
          component = 0
          execute_on = 'TIMESTEP_END'
          boundary = 'Block2_Block3'
      []
      [YJumpRate]
          type = MaterialRealVectorValueAux
          property = displacement_jump_rate_global
          variable = jump_rate_y
          component = 1
          execute_on = 'TIMESTEP_END'
          boundary = 'Block2_Block3'
      []
      [ZJumpRate]
          type = MaterialRealVectorValueAux
          property = displacement_jump_rate_global
          variable = jump_rate_z
          component = 2
          execute_on = 'TIMESTEP_END'
          boundary = 'Block2_Block3'
      []    
      #
      [TractionX]
          type = MaterialRealVectorValueAux
          property = traction_on_interface
          variable = traction_x
          component = 0
          execute_on = 'TIMESTEP_END'
          boundary = 'Block2_Block3'        
      []
      [TractionY]
          type = MaterialRealVectorValueAux
          property = traction_on_interface
          variable = traction_y
          component = 1
          execute_on = 'TIMESTEP_END'
          boundary = 'Block2_Block3'
      []
      [TractionZ]
          type = MaterialRealVectorValueAux
          property = traction_on_interface
          variable = traction_z
          component = 2
          execute_on = 'TIMESTEP_END'
          boundary = 'Block2_Block3'
      []        
      #
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
      [restore_z]
        type = TagVectorAux
        vector_tag = 'restore_tag'
        v = 'disp_z'
        variable = 'resid_z'
        execute_on = 'TIMESTEP_END'
      []
      #damping
      [restore_dampx]
        type = TagVectorAux
        vector_tag = 'restore_dampx_tag'
        v = 'disp_x'
        variable = 'resid_damp_x'
        execute_on = 'TIMESTEP_END'
      []
      [restore_dampy]
          type = TagVectorAux
          vector_tag = 'restore_dampy_tag'
          v = 'disp_y'
          variable = 'resid_damp_y'
          execute_on = 'TIMESTEP_END'
      []
      [restore_dampz]
          type = TagVectorAux
          vector_tag = 'restore_dampz_tag'
          v = 'disp_z'
          variable = 'resid_damp_z'
          execute_on = 'TIMESTEP_END'
      []
      [StaticFricCoeff]
        type = FunctionAux
        variable = mu_s
        function = func_static_friction_coeff_mus
        execute_on = 'INITIAL TIMESTEP_BEGIN'
      []
      [DynamicFricCoeff]
        type = FunctionAux
        variable = mu_d
        function = func_dynamic_friction_coeff_mud
        execute_on = 'INITIAL TIMESTEP_BEGIN'
      []
      [elem_length]
        type = ConstantAux
        variable = elem_length
        value = ${elem_length}
      []
      #
      [checkxx]
        type = FunctionAux
        variable = check_function_initial_stress_xx
        function = func_initial_stress_xx
        execute_on = 'INITIAL TIMESTEP_BEGIN'
      []
      [checkxy]
        type = FunctionAux
        variable = check_function_initial_stress_xy
        function = func_initial_stress_xy
        execute_on = 'INITIAL TIMESTEP_BEGIN'
      []
      [checkxz]
        type = FunctionAux
        variable = check_function_initial_stress_xz
        function = func_initial_stress_xz
        execute_on = 'INITIAL TIMESTEP_BEGIN'
      []
      [checkyy]
        type = FunctionAux
        variable = check_function_initial_stress_yy
        function = func_initial_stress_yy
        execute_on = 'INITIAL TIMESTEP_BEGIN'
      []
      [checkyz]
        type = FunctionAux
        variable = check_function_initial_stress_yz
        function = func_initial_stress_yz
        execute_on = 'INITIAL TIMESTEP_BEGIN'
      []
      [checkzz]
        type = FunctionAux
        variable = check_function_initial_stress_zz
        function = func_initial_stress_zz
        execute_on = 'INITIAL TIMESTEP_BEGIN'
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
      [./inertia_z]
        type = InertialForce
        use_displaced_mesh = false
        variable = disp_z
      []
      [./Reactionx]
        type = StiffPropDamping
        variable = 'disp_x'
        component = '0'
        extra_vector_tags = restore_dampx_tag
      []
      [./Reactiony]
        type = StiffPropDamping
        variable = 'disp_y'
        component = '1'
        extra_vector_tags = restore_dampy_tag
      []
      [./Reactionz]
        type = StiffPropDamping
        variable = 'disp_z'
        component = '2'
        extra_vector_tags = restore_dampz_tag
      []
  []
  
  [InterfaceKernels]
      [czm_interface_kernel_x]
          type = FarmsCZM
          variable = disp_x
          neighbor_var = disp_x
          boundary = 'Block2_Block3'
      []
      [czm_interface_kernel_y]
          type = FarmsCZM
          variable = disp_y
          neighbor_var = disp_y
          boundary = 'Block2_Block3'
      []
      [czm_interface_kernel_z]
          type = FarmsCZM
          variable = disp_z
          neighbor_var = disp_z
          boundary = 'Block2_Block3'
      []
  []
  
  [Materials]
      #damage breakage model
      [stress_medium]
        type = ComputeDamageBreakageStress3D
        alpha_grad_x = alpha_grad_x
        alpha_grad_y = alpha_grad_y
        alpha_grad_z = alpha_grad_z
        output_properties = 'B alpha_damagedvar xi stress'
        outputs = exodus
      [] 
      [density]
          type = GenericConstantMaterial
          prop_names = density
          prop_values = ${density}
      []
      [elasticity]
        type = ComputeIsotropicElasticityTensor
        shear_modulus = ${shear_modulus_o}
        lambda = ${lambda_o}
      []
      [./czm_mat]
          type = FarmsSlipWeakeningCZM
          disp_slipweakening_x     = disp_slipweakening_x
          disp_slipweakening_y     = disp_slipweakening_y
          disp_slipweakening_z     = disp_slipweakening_z
          vel_slipweakening_x      = vel_slipweakening_x
          vel_slipweakening_y      = vel_slipweakening_y
          vel_slipweakening_z      = vel_slipweakening_z
          reaction_slipweakening_x = resid_x
          reaction_slipweakening_y = resid_y
          reaction_slipweakening_z = resid_z
          reaction_damp_x = resid_damp_x
          reaction_damp_y = resid_damp_y
          reaction_damp_z = resid_damp_z
          elem_length = elem_length
          mu_d = mu_d
          mu_s = mu_s
          boundary = 'Block2_Block3'
      [../]
      [./static_initial_stress_tensor_slipweakening]
          type = GenericFunctionRankTwoTensor
          tensor_name = static_initial_stress_tensor_slipweakening
          tensor_functions = 'func_initial_stress_xx   func_initial_stress_xy      func_initial_stress_xz 
                              func_initial_stress_xy   func_initial_stress_yy      func_initial_stress_yz
                              func_initial_stress_xz   func_initial_stress_yz      func_initial_stress_zz'
      [../]
      [./static_initial_stress_tensor]
        type = GenericFunctionRankTwoTensor
        tensor_name = static_initial_stress_tensor
        tensor_functions = 'func_initial_stress_xx   func_initial_stress_xy      func_initial_stress_xz 
                            func_initial_stress_xy   func_initial_stress_yy      func_initial_stress_yz
                            func_initial_stress_xz   func_initial_stress_yz      func_initial_stress_zz'
      [../]
      #dummy material props
      [initial_damage]
        type = GenericConstantMaterial
        prop_names = initial_damage
        prop_values = 0
      []
      [initial_breakage]
        type = GenericConstantMaterial
        prop_names = initial_breakage
        prop_values = 0
      []
      [initial_shear_stress]
        type = GenericConstantMaterial
        prop_names = initial_shear_stress
        prop_values = 0
      []
      [damage_perturbation]
        type = GenericConstantMaterial
        prop_names = damage_perturbation
        prop_values = 0
      []
      [shear_stress_perturbation]
        type = GenericConstantMaterial
        prop_names = shear_stress_perturbation
        prop_values = 0
      []
  []
  
  [Functions]
      [func_static_friction_coeff_mus]
         type = InitialStaticFrictionCoeff
         patch_xmin = ${patch_xmin}
         patch_xmax = ${patch_xmax}
         patch_ymin = ${patch_ymin}
         patch_ymax = ${patch_ymax}
         mu_s_patch = ${mu_s_patch}
         mu_s_outside = ${mu_s_outside}
      []
      #mud constant value
      [func_dynamic_friction_coeff_mud]
          type = ConstantFunction
          value = ${mu_d}
      []
      #Note:restrict stress variation along the fault only
      #this function is used in czm only
      [./func_initial_stress_xx]
          type = ConstantFunction
          value = ${sts_xx}
      []
      [./func_initial_stress_xy]
          type = ConstantFunction
          value = ${sts_xy}
      []
      [./func_initial_stress_xz]
        type = InitialShearStressCDBM
        benchmark_type = tpv205
        nucl_xmin = ${nucl_xmin}
        nucl_xmax = ${nucl_xmax}
        nucl_ymin = ${nucl_ymin}
        nucl_ymax = ${nucl_ymax}
        nucl_zmin = ${nucl_zmin}
        nucl_zmax = ${nucl_zmax}
        T1_o_nucl = ${T1_o_nucl}
        T1_o = ${T1_o}
      []
      [./func_initial_stress_yy]
        type = ConstantFunction
        value = ${sts_yy}
      []
      [./func_initial_stress_yz]
        type = ConstantFunction
        value = ${sts_yz}
      []
      [./func_initial_stress_zz]
        type = ConstantFunction
        value = ${sts_zz}
      []
  []
  
  [UserObjects]
      [recompute_residual_tag]
          type = ResidualEvaluationUserObject
          vector_tag = 'restore_tag'
          force_preaux = true
          execute_on = 'TIMESTEP_END'
      []
      #damping
      [recompute_residual_tag_dampx]
        type = ResidualEvaluationUserObject
        vector_tag = 'restore_dampx_tag'
        force_preaux = true
        execute_on = 'TIMESTEP_END'
      []
      [recompute_residual_tag_dampy]
          type = ResidualEvaluationUserObject
          vector_tag = 'restore_dampy_tag'
          force_preaux = true
          execute_on = 'TIMESTEP_END'
      []
      [recompute_residual_tag_dampz]
          type = ResidualEvaluationUserObject
          vector_tag = 'restore_dampz_tag'
          force_preaux = true
          execute_on = 'TIMESTEP_END'
      []
  []
  
  [Executioner]
      type = Transient
      dt = ${dt}
      end_time = ${end_time}
      # num_steps = 1
      [TimeIntegrator]
          type = CentralDifference
          solve_type = lumped
          use_constant_mass = true
      []
  []
  
  [Outputs]
      exodus = true
      time_step_interval = ${time_step_interval}
      # show = 'vel_slipweakening_x vel_slipweakening_y vel_slipweakening_z disp_slipweakening_x disp_slipweakening_y disp_slipweakening_z B alpha_damagedvar xi stress_00 stress_11 stress_22 stress_01 stress_12 stress_02'
  []

  [BCs]
    ##non-reflecting bc
    #
    [./dashpot_bottom_x]
        type = NonReflectDashpotBC3d
        component = 0
        variable = disp_x
        disp_x = disp_x
        disp_y = disp_y
        disp_z = disp_z
        p_wave_speed = ${pressure_wave_speed}
        shear_wave_speed = ${shear_wave_speed}
        boundary = bottom
    []
    [./dashpot_bottom_y]
        type = NonReflectDashpotBC3d
        component = 1
        variable = disp_y
        disp_x = disp_x
        disp_y = disp_y
        disp_z = disp_z
        p_wave_speed = ${pressure_wave_speed}
        shear_wave_speed = ${shear_wave_speed}
        boundary = bottom
    []
    [./dashpot_bottom_z]
        type = NonReflectDashpotBC3d
        component = 2
        variable = disp_z
        disp_x = disp_x
        disp_y = disp_y
        disp_z = disp_z
        p_wave_speed = ${pressure_wave_speed}
        shear_wave_speed = ${shear_wave_speed}
        boundary = bottom
    []
    #
    [./dashpot_left_x]
        type = NonReflectDashpotBC3d
        component = 0
        variable = disp_x
        disp_x = disp_x
        disp_y = disp_y
        disp_z = disp_z
        p_wave_speed = ${pressure_wave_speed}
        shear_wave_speed = ${shear_wave_speed}
        boundary = left
    []
    [./dashpot_left_y]
        type = NonReflectDashpotBC3d
        component = 1
        variable = disp_y
        disp_x = disp_x
        disp_y = disp_y
        disp_z = disp_z
        p_wave_speed = ${pressure_wave_speed}
        shear_wave_speed = ${shear_wave_speed}
        boundary = left
    []
    [./dashpot_left_z]
        type = NonReflectDashpotBC3d
        component = 2
        variable = disp_z
        disp_x = disp_x
        disp_y = disp_y
        disp_z = disp_z
        p_wave_speed = ${pressure_wave_speed}
        shear_wave_speed = ${shear_wave_speed}
        boundary = left
    []
    #
    [./dashpot_right_x]
        type = NonReflectDashpotBC3d
        component = 0
        variable = disp_x
        disp_x = disp_x
        disp_y = disp_y
        disp_z = disp_z
        p_wave_speed = ${pressure_wave_speed}
        shear_wave_speed = ${shear_wave_speed}
        boundary = right
    []
    [./dashpot_right_y]
        type = NonReflectDashpotBC3d
        component = 1
        variable = disp_y
        disp_x = disp_x
        disp_y = disp_y
        disp_z = disp_z
        p_wave_speed = ${pressure_wave_speed}
        shear_wave_speed = ${shear_wave_speed}
        boundary = right
    []
    [./dashpot_right_z]
        type = NonReflectDashpotBC3d
        component = 2
        variable = disp_z
        disp_x = disp_x
        disp_y = disp_y
        disp_z = disp_z
        p_wave_speed = ${pressure_wave_speed}
        shear_wave_speed = ${shear_wave_speed}
        boundary = right
    []
    #
    [./dashpot_front_x]
      type = NonReflectDashpotBC3d
      component = 0
      variable = disp_x
      disp_x = disp_x
      disp_y = disp_y
      disp_z = disp_z
      p_wave_speed = ${pressure_wave_speed}
      shear_wave_speed = ${shear_wave_speed}
      boundary = front
    []
    [./dashpot_front_y]
      type = NonReflectDashpotBC3d
      component = 1
      variable = disp_y
      disp_x = disp_x
      disp_y = disp_y
      disp_z = disp_z
      p_wave_speed = ${pressure_wave_speed}
      shear_wave_speed = ${shear_wave_speed}
      boundary = front
    []
    [./dashpot_front_z]
        type = NonReflectDashpotBC3d
        component = 2
        variable = disp_z
        disp_x = disp_x
        disp_y = disp_y
        disp_z = disp_z
        p_wave_speed = ${pressure_wave_speed}
        shear_wave_speed = ${shear_wave_speed}
        boundary = front
    []
    #
    [./dashpot_back_x]
        type = NonReflectDashpotBC3d
        component = 0
        variable = disp_x
        disp_x = disp_x
        disp_y = disp_y
        disp_z = disp_z
        p_wave_speed = ${pressure_wave_speed}
        shear_wave_speed = ${shear_wave_speed}
        boundary = back
    []
    [./dashpot_back_y]
        type = NonReflectDashpotBC3d
        component = 1
        variable = disp_y
        disp_x = disp_x
        disp_y = disp_y
        disp_z = disp_z
        p_wave_speed = ${pressure_wave_speed}
        shear_wave_speed = ${shear_wave_speed}
        boundary = back
    []
    [./dashpot_back_z]
        type = NonReflectDashpotBC3d
        component = 2
        variable = disp_z
        disp_x = disp_x
        disp_y = disp_y
        disp_z = disp_z
        p_wave_speed = ${pressure_wave_speed}
        shear_wave_speed = ${shear_wave_speed}
        boundary = back
    []
  []
#--------------------------------------------#
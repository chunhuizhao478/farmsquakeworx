[Mesh]
    [./msh]
      type = GeneratedMeshGenerator
      dim = 2
      nx = 400
      ny = 400
      xmin = -2000
      xmax = 2000
      ymin = -2000
      ymax = 2000
      elem_type = TRI3
    []
    [./new_block_1]
        type = ParsedSubdomainMeshGenerator
        input = msh
        combinatorial_geometry = 'y<0'
        block_id = 1
    []
    [./split]
        type = BreakMeshByBlockGenerator
        input = new_block_1
        split_interface = true
        block_pairs = '0 1'
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
  
    ##----continuum damage breakage model----##
    #initial lambda value (first lame constant) [Pa]
    lambda_o = 3.204e10
      
    #initial shear modulus value (second lame constant) [Pa]
    shear_modulus_o = 3.204e10
  
    #<strain invariants ratio: onset of damage evolution>: relate to internal friction angle, refer to "note_mar25"
    xi_0 = -0.8
  
    #<strain invariants ratio: onset of breakage healing>: tunable param, see ggw183.pdf
    xi_d = -0.9
  
    #<strain invariants ratio: maximum allowable value>: set boundary
    #Xu_etal_P15-2D
    #may need a bit space, use 1.5 as boundary
    xi_max = 1.5
  
    #<strain invariants ratio: minimum allowable value>: set boundary
    #Xu_etal_P15-2D
    xi_min = -1.5
  
    #if option 2, use Cd_constant
    Cd_constant = 1e7
  
    #<coefficient gives positive breakage evolution >: refer to "Lyak_BZ_JMPS14_splitstrain" Table 1
    #The multiplier between Cd and Cb: Cb = CdCb_multiplier * Cd
    CdCb_multiplier = 10 
  
    #<coefficient of healing for breakage evolution>: refer to "Lyakhovsky_Ben-Zion_P14" (C_BH)
    CBH_constant = 1e4
  
    #<coefficient of healing for damage evolution>: refer to "ggw183.pdf"
    C_1 = 300
  
    #<coefficient of healing for damage evolution>: refer to "ggw183.pdf"
    C_2 = 0.05
  
    #<coefficient gives width of transitional region>: see P(alpha), refer to "Lyak_BZ_JMPS14_splitstrain" Table 1
    beta_width = 0.03 #1e-3
  
    #critical point of three phases (strain invariants ratio vs damage)
    xi_1 = 0.8248
  
    #--------------------------------------------------------------------------------#
    #Note: "computeAlphaCr" needs to change every time the related parameters changed
    #--------------------------------------------------------------------------------#
  
    #coefficients
    # chi = 0.75
    a0 = 7.4289e9
    a1 = -2.214e10
    a2 = 2.0929e10
    a3 = -6.0672e9
  
    #diffusion coefficient #for structural stress coupling
    D = 0
    
  []
  
  [Variables]
    #-high-order-dummy-#
    [alpha_sub_dummy]
      order = FIRST
      family = MONOMIAL
    []
    [B_sub_dummy]
      order = FIRST
      family = MONOMIAL
    []
  []
  
  [AuxVariables]
    [alpha_old]
      order = CONSTANT
      family = MONOMIAL
    []
    [B_old]
      order = CONSTANT
      family = MONOMIAL
    []
    #-high-order-dummy-#
    [alpha_old_dummy]
      order = FIRST
      family = MONOMIAL
    []
    [B_old_dummy]
      order = FIRST
      family = MONOMIAL
    []
    #
    [xi_old]
        order = CONSTANT
        family = MONOMIAL
    []
    [I2_old]
        order = CONSTANT
        family = MONOMIAL
    []
    [mu_old]
        order = CONSTANT
        family = MONOMIAL
    []
    [lambda_old]
        order = CONSTANT
        family = MONOMIAL
    []
    [gamma_old]
        order = CONSTANT
        family = MONOMIAL
    []
    #checked
    [alpha_checked]
      order = CONSTANT
      family = MONOMIAL
    []
    [B_checked]
      order = CONSTANT
      family = MONOMIAL
    []
    #high-order-dummy
    [alpha_checked_dummy]
      order = FIRST
      family = MONOMIAL
    []
    [B_checked_dummy]
      order = FIRST
      family = MONOMIAL
    []
    #grad_alpha
    [alpha_grad_x_sub]
      order = CONSTANT
      family = MONOMIAL
    []
    [alpha_grad_y_sub]
      order = CONSTANT
      family = MONOMIAL
    []
  []
  
  [Kernels]
    #-high-order-dummy-#
    [./timederivative_alpha_dummy]
      type = TimeDerivative
      variable = alpha_sub_dummy
    []
    [./alpha_forcing_func_dummy]
        type = DamageVarForcingFunc
        alpha_old = alpha_old
        B_old = B_old
        xi_old = xi_old
        I2_old = I2_old
        variable = alpha_sub_dummy
    []
    [./timederivative_B_dummy]
      type = TimeDerivative
      variable = B_sub_dummy
    []
    [./B_forcing_func_dummy]
        type = BreakageVarForcingFunc
        variable = B_sub_dummy
        alpha_old = alpha_old
        B_old = B_old
        xi_old = xi_old
        I2_old = I2_old
        mu_old = mu_old
        gamma_old = gamma_old
        lambda_old = lambda_old
    []
  []
  
  [AuxKernels]
    #-high-order-dummy-#
    [check_alpha_dummy]
      type = CheckAlphaB
      coupled = alpha_sub_dummy
      variable = alpha_checked_dummy
      execute_on = 'TIMESTEP_END'
    []
    [check_B_dummy]
      type = CheckAlphaB
      coupled = B_sub_dummy
      variable = B_checked_dummy
      execute_on = 'TIMESTEP_END'
    []
    #
    [alpha_grad_x_sub]
      type = VariableGradientComponent
      variable = alpha_grad_x_sub
      component = x
      gradient_variable = alpha_checked_dummy
      execute_on = 'TIMESTEP_END'
   []
   [alpha_grad_y_sub]
     type = VariableGradientComponent
     variable = alpha_grad_y_sub
     component = y
     gradient_variable = alpha_checked_dummy
     execute_on = 'TIMESTEP_END'
    []
  []
  
  #by default, subApp is using the same time step as mainApp
  [Executioner]
    type = Transient
    [TimeIntegrator]
      type = ExplicitSSPRungeKutta
      order = 3
    []
  []
# Test for TPV32DepthSeismicProperties
# Single 1 m element centered at z = -1300 m (depth d = 1300 m, inside segment [1000, 1600]).
# Within this segment the piecewise-linear profile gives:
#   rho(1300) = 2550 + 50*(300/600)   = 2575    kg/m^3
#   Vs(1300)  = 1950 + 550*(300/600)  = 2225    m/s
#   Vp(1300)  = 3600 + 800*(300/600)  = 4000    m/s
#   mu        = rho*Vs^2              = 1.274785938e10 Pa
#   lambda    = rho*Vp^2 - 2*mu       = 1.570428125e10 Pa
# Since rho, Vs, Vp vary linearly inside the segment, their element averages equal the
# centroid values. mu = rho*Vs^2 is quadratic; averaging error over a 1 m element
# is ~(h/segment)^2 ≈ O(1e-6), well below the CSVDiff tolerance.

[Mesh]
  type = GeneratedMesh
  dim = 3
  nx = 1
  ny = 1
  nz = 1
  xmin = -0.5
  xmax = 0.5
  ymin = -0.5
  ymax = 0.5
  zmin = -1300.5
  zmax = -1299.5
[]

[Problem]
  solve = false
  kernel_coverage_check = false
[]

[Variables]
  [dummy]
  []
[]

[AuxVariables]
  [Vs_aux]
    order = CONSTANT
    family = MONOMIAL
  []
  [Vp_aux]
    order = CONSTANT
    family = MONOMIAL
  []
  [rho_aux]
    order = CONSTANT
    family = MONOMIAL
  []
  [mu_aux]
    order = CONSTANT
    family = MONOMIAL
  []
  [lambda_aux]
    order = CONSTANT
    family = MONOMIAL
  []
[]

[AuxKernels]
  [get_Vs]
    type = MaterialRealAux
    variable = Vs_aux
    property = Vs
    execute_on = 'INITIAL'
  []
  [get_Vp]
    type = MaterialRealAux
    variable = Vp_aux
    property = Vp
    execute_on = 'INITIAL'
  []
  [get_rho]
    type = MaterialRealAux
    variable = rho_aux
    property = density_input
    execute_on = 'INITIAL'
  []
  [get_mu]
    type = MaterialRealAux
    variable = mu_aux
    property = shear_modulus_input
    execute_on = 'INITIAL'
  []
  [get_lambda]
    type = MaterialRealAux
    variable = lambda_aux
    property = lambda_input
    execute_on = 'INITIAL'
  []
[]

[Materials]
  [seismic_props]
    type = TPV32DepthSeismicProperties
    depth_axis = 'z'
    flip_sign = true
  []
[]

[Postprocessors]
  [Vs_avg]
    type = ElementAverageValue
    variable = Vs_aux
    execute_on = 'INITIAL'
  []
  [Vp_avg]
    type = ElementAverageValue
    variable = Vp_aux
    execute_on = 'INITIAL'
  []
  [rho_avg]
    type = ElementAverageValue
    variable = rho_aux
    execute_on = 'INITIAL'
  []
  [mu_avg]
    type = ElementAverageValue
    variable = mu_aux
    execute_on = 'INITIAL'
  []
  [lambda_avg]
    type = ElementAverageValue
    variable = lambda_aux
    execute_on = 'INITIAL'
  []
[]

[Executioner]
  type = Steady
[]

[Outputs]
  csv = true
  execute_on = 'INITIAL'
[]

# Test for InitialStressStrainTPV26VaryingDensity
# Samples fluid pressure and vertical total-stress component sigma_zz at known TPV32 depths.
# At depth d = 500 m (z = -500), TPV32 density knot rho(500)=2450 kg/m^3.
#
# Analytical expectations (SI units):
#   fluid_density = 1000, gravity = 9.8
#   Pf  = rho_f * g * |z| = 1000 * 9.8 * 500                    = 4.9e6 Pa
#   overburden(0->500) = 0.5*(2200+2450)*500                    = 1,162,500 kg/m^2
#   sigma_zz_raw = -g * overburden = -9.8 * 1,162,500           = -1.13925e7 Pa
#   sigma_zz (effective, after +Pf) with bxx=byy=1, bxy=0 path:
#       sigma_zz = sigma_zz_raw + Pf = -1.13925e7 + 4.9e6       = -6.4925e6 Pa

[Mesh]
  type = GeneratedMesh
  dim = 3
  nx = 1
  ny = 1
  nz = 1
  xmin = 0
  xmax = 1
  ymin = 0
  ymax = 1
  zmin = -1
  zmax = 0
[]

[Problem]
  solve = false
  kernel_coverage_check = false
[]

[Functions]
  [pf_varying]
    type = InitialStressStrainTPV26VaryingDensity
    i = 1
    j = 1
    lambda_o = 3.204e10
    shear_modulus_o = 3.204e10
    fluid_density = 1000
    gravity = 9.8
    bxx = 1
    byy = 1
    bxy = 0
    get_fluid_pressure = true
  []
  [sigma_zz_varying]
    type = InitialStressStrainTPV26VaryingDensity
    i = 3
    j = 3
    lambda_o = 3.204e10
    shear_modulus_o = 3.204e10
    fluid_density = 1000
    gravity = 9.8
    bxx = 1
    byy = 1
    bxy = 0
    get_initial_stress = true
  []
[]

[Postprocessors]
  [pf_at_500m]
    type = FunctionValuePostprocessor
    function = pf_varying
    point = '0 0 -500'
    execute_on = 'INITIAL'
  []
  [sigma_zz_at_500m]
    type = FunctionValuePostprocessor
    function = sigma_zz_varying
    point = '0 0 -500'
    execute_on = 'INITIAL'
  []
  [pf_at_surface]
    type = FunctionValuePostprocessor
    function = pf_varying
    point = '0 0 0'
    execute_on = 'INITIAL'
  []
  [sigma_zz_at_surface]
    type = FunctionValuePostprocessor
    function = sigma_zz_varying
    point = '0 0 0'
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

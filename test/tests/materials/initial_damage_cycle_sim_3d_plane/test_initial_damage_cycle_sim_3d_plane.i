# Test for InitialDamageCycleSim3DPlane
# Single 1 m^3 element centered at the nucleation point (0,0,0).
# The fault plane is y = 0 with large in-plane extent; sigma >> qp spread,
# so the exponential decay factor is essentially unity and the initial damage
# reduces to peak_val.
#
# Expected:
#   alpha_avg = peak_val * exp(-r^2 / sigma^2)  with r ~ 0  ->  peak_val = 0.5

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
  zmin = -0.5
  zmax = 0.5
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
  [initial_damage_aux]
    order = CONSTANT
    family = MONOMIAL
  []
[]

[AuxKernels]
  [get_initial_damage]
    type = MaterialRealAux
    variable = initial_damage_aux
    property = initial_damage
    execute_on = 'INITIAL'
  []
[]

[Materials]
  [initial_damage]
    type = InitialDamageCycleSim3DPlane
    len_of_fault_strike = 2000
    len_of_fault_dip = 2000
    sigma = 1000
    peak_val = 0.5
    nucl_center = '0 0 0'
  []
[]

[Postprocessors]
  [alpha_avg]
    type = ElementAverageValue
    variable = initial_damage_aux
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

# Test for ScaleVarAux AuxKernel
# Verifies scaling: result = coupled / scale
# u = 10.0 (constant), scale = 2.0 -> scaled = 5.0

[Mesh]
  type = GeneratedMesh
  dim = 2
  nx = 2
  ny = 2
  xmax = 1
  ymax = 1
[]

[Variables]
  [u]
    initial_condition = 10.0
  []
[]

[AuxVariables]
  [scale_var]
    initial_condition = 2.0
  []
  [scaled_result]
    order = FIRST
    family = LAGRANGE
  []
[]

[Kernels]
  [diff]
    type = Diffusion
    variable = u
  []
  [td]
    type = TimeDerivative
    variable = u
  []
[]

[AuxKernels]
  [scale_aux]
    type = ScaleVarAux
    variable = scaled_result
    coupled = u
    scale = scale_var
    execute_on = 'TIMESTEP_END'
  []
[]

[BCs]
  [all]
    type = DirichletBC
    variable = u
    boundary = 'left right top bottom'
    value = 10.0
  []
[]

[Postprocessors]
  [scaled_max]
    type = NodalExtremeValue
    variable = scaled_result
    value_type = max
  []
  [u_max]
    type = NodalExtremeValue
    variable = u
    value_type = max
  []
[]

[Executioner]
  type = Transient
  dt = 0.1
  num_steps = 2
  solve_type = LINEAR
[]

[Outputs]
  csv = true
[]

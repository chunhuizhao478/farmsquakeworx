# Test for FDCompVarRate AuxKernel
# Verifies finite-difference time derivative: rate = (val - val_old) / dt
# A linear-in-time displacement u = t produces rate = 1.0

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
  []
[]

[AuxVariables]
  [rate_fd]
    order = FIRST
    family = LAGRANGE
  []
[]

[Functions]
  [u_func]
    type = ParsedFunction
    expression = 't'
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
  [fd_rate]
    type = FDCompVarRate
    variable = rate_fd
    coupled = u
    execute_on = 'TIMESTEP_END'
  []
[]

[BCs]
  [all]
    type = FunctionDirichletBC
    variable = u
    boundary = 'left right top bottom'
    function = u_func
  []
[]

[Postprocessors]
  [rate_avg]
    type = NodalExtremeValue
    variable = rate_fd
    value_type = max
  []
  [u_avg]
    type = NodalExtremeValue
    variable = u
    value_type = max
  []
[]

[Executioner]
  type = Transient
  dt = 0.1
  num_steps = 3
  solve_type = LINEAR
[]

[Outputs]
  csv = true
[]

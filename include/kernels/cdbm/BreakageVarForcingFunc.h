/*
Update Breakage Variable Using Runge-Kutta own solver
*/

#pragma once

#include "Kernel.h"
#include "Material.h"

class BreakageVarForcingFunc : public Kernel
{
public:
  static InputParameters validParams();

  BreakageVarForcingFunc(const InputParameters & parameters);

protected:
  virtual Real computeQpResidual();
  virtual Real computeQpJacobian();

private:
    /// constant parameters
    /// multiplier between Cb and Cbh
    Real _a0;
    Real _a1;
    Real _a2;
    Real _a3;
    Real _xi_min;
    Real _xi_max;
    Real _xi_d;
    Real _xi_0;
    Real _xi_1;
    Real _beta_width;
    /// multiplier between Cd and Cb
    Real _CdCb_multiplier;
    Real _CBH_constant;
    /// variable parameters
    const VariableValue & _alpha_old;
    const VariableValue & _B_old; 
    const VariableValue & _xi_old; 
    const VariableValue & _I2_old;
    const VariableValue & _mu_old;
    const VariableValue & _lambda_old;
    const VariableValue & _gamma_old;
    Real _Cd_constant;

    Real computeAlphaCr(Real xi);
};
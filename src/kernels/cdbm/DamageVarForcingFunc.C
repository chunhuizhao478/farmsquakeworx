/*
Implementation of Damage Evolution Forcing Function (F) :

Strong Form: 

d alpha / dt = F
F = (1-B)[Cd I_2 (xi - xi_o) + D grad^2 alpha] if xi >= xi_o
F = (1-B)[C1 exp(alpha/C2) I2 (xi - xi_o) + D grad^2 alpha] if xi <= xi_o

Weak Form:

int( d(alpha)/dt * v ) - int( (1-B) (Cd I2 (xi - xi_o) * v + D d(alpha)/dx dv/dx ) = 0 if xi >= xi_o

int( d(alpha)/dt * v ) - int( (1-B) (C1 exp(alpha/C2) I2 (xi - xi_o) * v + D d(alpha)/dx dv/dx ) = 0 if xi <= xi_o
*/

#include "DamageVarForcingFunc.h"

registerMooseObject("farmsquakeworxApp", DamageVarForcingFunc);

InputParameters
DamageVarForcingFunc::validParams()
{
  InputParameters params = Kernel::validParams();

  //constant parameters
  params.addRequiredParam<Real>(     "D", "coefficient gives diffusion magnitude of damage evolution");
  params.addRequiredParam<Real>(   "C_1", "coefficient of healing for damage evolution");
  params.addRequiredParam<Real>(   "C_2", "coefficient of healing for damage evolution");
  params.addRequiredParam<Real>(  "xi_0", "strain invariants ratio: onset of damage evolution");
  params.addRequiredParam<Real>("xi_min", "strain invariant ratio at minimum value");
  params.addRequiredParam<Real>("xi_max", "strain invariant ratio at maximum value");

  //variable parameters
  params.addRequiredCoupledVar("alpha_old", "damage variable at previous time step");
  params.addRequiredCoupledVar(    "B_old", "breakage variable at previous time step");
  params.addRequiredCoupledVar(   "xi_old", "strain invariant ratio at previous time step");
  params.addRequiredCoupledVar(   "I2_old", "second strain invariant at previous time step");

  params.addParam<Real>( "Cd_constant", 0.0, "constant Cd value for option 2 only");

  //fix diffuison
  params.addRequiredParam<Real>("shear_modulus_o", "initial shear modulus");
  params.addRequiredParam<Real>("lambda_o", "initial lame constant");

  return params;
}

DamageVarForcingFunc::DamageVarForcingFunc(const InputParameters & parameters)
 : Kernel(parameters),
  _D(getParam<Real>("D")),
  _C1(getParam<Real>("C_1")),
  _C2(getParam<Real>("C_2")),
  _xi_0(getParam<Real>("xi_0")),
  _xi_min(getParam<Real>("xi_min")),
  _xi_max(getParam<Real>("xi_max")),
  _alpha_old(coupledValue("alpha_old")),
  _B_old(coupledValue("B_old")),
  _xi_old(coupledValue("xi_old")),
  _I2_old(coupledValue("I2_old")),
  _Cd_constant(getParam<Real>("Cd_constant")),
  _shear_modulus_o(getParam<Real>("shear_modulus_o")),
  _lambda_o(getParam<Real>("lambda_o"))
{
}

Real
DamageVarForcingFunc::computeQpResidual()
{ 
  
  //Power-law correction
  //Initialize Cd
  Real Cd = 0;

  Cd = _Cd_constant;

  //Compute Diffusion coefficient
  Real YoungE = _shear_modulus_o * ( 3 * _lambda_o + 2 * _shear_modulus_o ) / ( _lambda_o + _shear_modulus_o );
  Real Diffusion_Coeff = _D * Cd / YoungE;

  //weak form for damage variable evolution
  if ( _xi_old[_qp] >= _xi_0 && _xi_old[_qp] <= _xi_max ){
    return -1 * (1 - _B_old[_qp]) * ( Cd * _I2_old[_qp] * ( _xi_old[_qp] - _xi_0 ) * _test[_i][_qp] - Diffusion_Coeff * _grad_u[_qp] * _grad_test[_i][_qp] );
  }
  else if ( _xi_old[_qp] < _xi_0 && _xi_old[_qp] >= _xi_min ){

    return -1 * (1 - _B_old[_qp]) * ( _C1 * exp(_alpha_old[_qp]/_C2) * _I2_old[_qp] * ( _xi_old[_qp] - _xi_0 ) * _test[_i][_qp] - Diffusion_Coeff * _grad_u[_qp] * _grad_test[_i][_qp] );
  }
  else{
    mooseError("xi_old is OUT-OF-RANGE!.");
    return 0;
  }
}

Real
DamageVarForcingFunc::computeQpJacobian()
{
  return 0.0;
}
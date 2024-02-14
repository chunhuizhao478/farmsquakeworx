/*
Update Breakage Variable Using Runge-Kutta own solver
*/

#include "BreakageVarForcingFunc.h"

registerMooseObject("farmsquakeworxApp", BreakageVarForcingFunc);

InputParameters
BreakageVarForcingFunc::validParams()
{
  InputParameters params = Kernel::validParams();

  //constant parameters
  params.addRequiredParam<Real>(         "a0", "parameters in granular states");
  params.addRequiredParam<Real>(         "a1", "parameters in granular states");
  params.addRequiredParam<Real>(         "a2", "parameters in granular states");
  params.addRequiredParam<Real>(         "a3", "parameters in granular states");
  params.addRequiredParam<Real>(     "xi_min", "strain invariant ratio at minimum value");
  params.addRequiredParam<Real>(     "xi_max", "strain invariant ratio at maximum value");
  params.addRequiredParam<Real>(       "xi_d", "strain invariant ratio at maximum value");
  params.addRequiredParam<Real>(       "xi_0", "strain invariants ratio: onset of damage evolution");
  params.addRequiredParam<Real>(       "xi_1", "strain invariants ratio: onset of breakage healing");
  params.addRequiredParam<Real>( "beta_width", "coefficient gives width of transitional region");
  params.addRequiredParam<Real>("CdCb_multiplier", "multiplier between Cd and Cb");
  params.addRequiredParam<Real>("CBH_constant","constant CBH value");

  //variable parameters
  params.addRequiredCoupledVar(  "alpha_old", "damage variable at previous time step");
  params.addRequiredCoupledVar(      "B_old", "breakage variable at previous time step");
  params.addRequiredCoupledVar(     "xi_old", "strain invariant ratio at previous time step");
  params.addRequiredCoupledVar(     "I2_old", "second strain invariant at previous time step");
  params.addRequiredCoupledVar(     "mu_old", "shear modulus at previous time step");
  params.addRequiredCoupledVar( "lambda_old", "first lame constant at previous time step");
  params.addRequiredCoupledVar(  "gamma_old", "damage modulus at previous time step");

  //add options
  params.addParam<Real>( "Cd_constant", 0.0, "constant Cd value");

  return params;
}

BreakageVarForcingFunc::BreakageVarForcingFunc(const InputParameters & parameters)
 : Kernel(parameters),
  _a0(getParam<Real>("a0")),
  _a1(getParam<Real>("a1")),
  _a2(getParam<Real>("a2")),
  _a3(getParam<Real>("a3")),
  _xi_min(getParam<Real>("xi_min")),
  _xi_max(getParam<Real>("xi_max")),
  _xi_d(getParam<Real>("xi_d")),
  _xi_0(getParam<Real>("xi_0")),
  _xi_1(getParam<Real>("xi_1")),
  _CdCb_multiplier(getParam<Real>("CdCb_multiplier")),
  _CBH_constant(getParam<Real>("CBH_constant")),
  _alpha_old(coupledValue("alpha_old")),
  _B_old(coupledValue("B_old")),
  _xi_old(coupledValue("xi_old")),
  _I2_old(coupledValue("I2_old")),
  _mu_old(coupledValue("mu_old")),
  _lambda_old(coupledValue("lambda_old")),
  _gamma_old(coupledValue("gamma_old")),
  _Cd_constant(getParam<Real>("Cd_constant"))
{
}

Real
BreakageVarForcingFunc::computeQpResidual()
{ 
  
    //get parameters
    Real alpha = _alpha_old[_qp];
    Real B = _B_old[_qp];
    Real I2 = _I2_old[_qp];
    Real xi = _xi_old[_qp];

    //Use constant Cd values
    //Initialize Cd
    Real Cd = 0;

    Cd = _Cd_constant;

    //Compute C_B
    Real C_B = _CdCb_multiplier * Cd;

    //Compute C_BH //keep constant 
    Real C_BH = _CBH_constant;

    //
    Real Prob = 0;
    Real alphacr = computeAlphaCr(xi);
    Prob = 1.0 / ( exp( (alphacr - alpha) / _beta_width ) + 1.0 );

    //no healing //this formulation is used in the splitstrain article
    if ( xi >= _xi_0 && xi <= _xi_max ){
      return -1.0 * C_B * Prob * (1-B) * I2 * (xi - _xi_0) * _test[_i][_qp]; //could heal if xi < xi_0
    }
    else if ( xi < _xi_0 && xi >= _xi_min ){
      
      return -1.0 * C_BH * I2 * ( xi - _xi_0 ) * _test[_i][_qp];

    }
    else{
      return 0;
    }
}

Real
BreakageVarForcingFunc::computeQpJacobian()
{
  return 0.0;
}

/// Function: Compute alpha_cr based on the current xi
Real 
BreakageVarForcingFunc::computeAlphaCr(Real xi)
{
  Real alphacr;
  if ( xi < _xi_0 )
  {
    alphacr = 1.0;
  } 
  else if ( xi > _xi_0 && xi <= _xi_1 )
  {
    alphacr = ((xi*2.76e5-7.100521107637101e2*xi*7.5e2-7.100521107637101e2*1.4e3-7.100521107637101e+2*pow(xi,3)*1.25e2+pow(xi,3)*4.6e4+sqrt((7.100521107637101e2*3.68e2-3.19799e5)*(xi*(-1.44e3)-pow(xi,2)*2.1e3+pow(xi,3)*5.6e2+pow(xi,4)*3.0e2+pow(xi,6)*2.5e1+3.576e3)*(-3.590922148807814e-1))*5.9e1+5.152e5)*(-5.9e1/4.0))/(xi*3.837588e7-7.100521107637101e2*xi*4.416e4+7.100521107637101e2*4.048e3-7.100521107637101e2*pow(xi,2)*2.76e4+pow(xi,2)*2.3984925e7-3.517789e6);
  }
  else if ( xi > _xi_1 && xi <= _xi_max )
  {
    alphacr = 6.408e10/(7.100521107637101e2*1.737762711864407e8+xi*(7.100521107637101e2*1.086101694915254e8-3.996854237288136e10)-6.394966779661017e10);
  }
  else
  {
    std::cout<<"xi: "<<xi<<std::endl;
    mooseError("xi exceeds the maximum allowable range!");
  }
  return alphacr;

}
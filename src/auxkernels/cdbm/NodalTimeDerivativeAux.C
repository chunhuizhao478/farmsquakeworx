/*
AuxKernel of Passing Variable Time Derivative 
*/

#include "NodalTimeDerivativeAux.h"

registerMooseObject("farmsquakeworxApp", NodalTimeDerivativeAux);

InputParameters
NodalTimeDerivativeAux::validParams()
{
  InputParameters params = AuxKernel::validParams();

  params.addRequiredCoupledVar("coupled","Nonlinear Variable that needed to be taken time derivative of");

  return params;
}

NodalTimeDerivativeAux::NodalTimeDerivativeAux(const InputParameters & parameters)
  : AuxKernel(parameters),
  
  //Compute the time derivative of the given variable using "coupledDot"
  _coupled_val(coupledDot("coupled"))

{
}

Real
NodalTimeDerivativeAux::computeValue()
{
  return _coupled_val[_qp];
}
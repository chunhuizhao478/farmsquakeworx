/*
Define Function for Initial Static Friction Coefficient for benchmark
*/

#include "InitialStaticFrictionCoeff.h"

registerMooseObject("farmsquakeworxApp", InitialStaticFrictionCoeff);

InputParameters
InitialStaticFrictionCoeff::validParams()
{
  InputParameters params = Function::validParams();
  params.addParam<Real>("patch_xmin", -15e3, "minmum x value for slip weakening patch");
  params.addParam<Real>("patch_xmax", 15e3, "maximum x value for slip weakening patch");
  params.addParam<Real>("patch_ymin", -15e3, "minmum y value for slip weakening patch");
  params.addParam<Real>("patch_ymax", 0, "maximum y value for slip weakening patch");
  params.addParam<Real>("mu_s_patch", 0.677, "static friction coefficient value for slip weakening patch");
  params.addParam<Real>("mu_s_outside",10000, "static friction coefficient value for rest of the domain");
  return params;
}

InitialStaticFrictionCoeff::InitialStaticFrictionCoeff(const InputParameters & parameters)
  : Function(parameters),
  _patch_xmin(getParam<Real>("patch_xmin")),
  _patch_xmax(getParam<Real>("patch_xmax")),
  _patch_ymin(getParam<Real>("patch_ymin")),
  _patch_ymax(getParam<Real>("patch_ymax")),
  _mu_s_patch(getParam<Real>("mu_s_patch")),
  _mu_s_outside(getParam<Real>("mu_s_outside"))
{
}

Real
InitialStaticFrictionCoeff::value(Real /*t*/, const Point & p) const
{

  Real x_coord = p(0); //along the x direction
  Real y_coord = p(1); //along the y direction
  //Real z_coord = p(2); //along the z direction

  //TPV205-3D
  Real mu_s = 0.0;
  if ((x_coord<=(_patch_xmax))&&(x_coord>=(_patch_xmin)) && (y_coord<=(_patch_ymax))&&(y_coord>=(_patch_ymin)))
  {
	  mu_s = _mu_s_patch;
  }  
  else
  {
    mu_s = _mu_s_outside;
  }

  return mu_s;

}
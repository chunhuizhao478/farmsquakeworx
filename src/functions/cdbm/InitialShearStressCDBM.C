/*
Define Function for Initial Shear Stress for benchmark
*/

#include "InitialShearStressCDBM.h"

#include <string.h>

registerMooseObject("farmsquakeworxApp", InitialShearStressCDBM);

InputParameters
InitialShearStressCDBM::validParams()
{
  InputParameters params = Function::validParams();
  params.addRequiredParam<std::string>("benchmark_type", "type of benchmark: tpv205, tpv14, tpv24");
  params.addParam<Real>("nucl_xmin", -1.5e3, "minmum x value for nucleation patch");
  params.addParam<Real>("nucl_xmax", 1.5e3, "maximum x value for nucleation patch");
  params.addParam<Real>("nucl_ymin", -9e3, "minmum y value for nucleation patch");
  params.addParam<Real>("nucl_ymax", -6e3, "maximum y value for nucleation patch");
  params.addParam<Real>("nucl_zmin", -200, "minmum z value for nucleation patch");
  params.addParam<Real>("nucl_zmax", 200, "maximum z value for nucleation patch");
  params.addParam<Real>("T1_o_nucl", 81.6e6, "shear stress value for nucleation patch");
  params.addParam<Real>("T1_o", 60.0e6, "shear stress value for rest of the domain");
  return params;
}

InitialShearStressCDBM::InitialShearStressCDBM(const InputParameters & parameters)
  : Function(parameters),
  _benchmark(getParam<std::string>("benchmark_type")),
  _nucl_xmin(getParam<Real>("nucl_xmin")),
  _nucl_xmax(getParam<Real>("nucl_xmax")),
  _nucl_ymin(getParam<Real>("nucl_ymin")),
  _nucl_ymax(getParam<Real>("nucl_ymax")),
  _nucl_zmin(getParam<Real>("nucl_zmin")),
  _nucl_zmax(getParam<Real>("nucl_zmax")),
  _T1_o_nucl(getParam<Real>("T1_o_nucl")),
  _T1_o(getParam<Real>("T1_o"))
{
}

Real
InitialShearStressCDBM::value(Real /*t*/, const Point & p) const
{

  Real x_coord = p(0); //along the strike direction
  Real y_coord = p(1); //along the dip direction
  Real z_coord = p(2); //along the normal direction

  Real T1_o = 0.0;

  //define option strings
  std::string tpv205 = "tpv205";
  std::string tpv14 = "tpv14";
  std::string tpv24 = "tpv24";

  if ( _benchmark == tpv205 ){
    
    //tpv205
    if ((x_coord<=(_nucl_xmax))&&(x_coord>=(_nucl_xmin))&& (y_coord<=(_nucl_ymax))&&(y_coord>=(_nucl_ymin))&&(z_coord>=_nucl_zmin)&&(z_coord<=_nucl_zmax))
    {
        T1_o = _T1_o_nucl;
    }
    else
    {
        T1_o = _T1_o;
    }
  }
  else if ( _benchmark == tpv14 ){
    mooseError("Unmatched benchmark type");
  }
  else{
    mooseError("Unmatched benchmark type");
  }
  return T1_o;

}
/*
Define Function for Initial Static Friction Coefficient for benchmark
*/

#pragma once

#include "Function.h"

class InitialShearStressCDBM : public Function
{
public:
  InitialShearStressCDBM(const InputParameters & parameters);

  static InputParameters validParams();

  using Function::value;
  virtual Real value(Real t, const Point & p) const override;

  std::string _benchmark;
  const Real _nucl_xmin;
  const Real _nucl_xmax;
  const Real _nucl_ymin;
  const Real _nucl_ymax;
  const Real _nucl_zmin;
  const Real _nucl_zmax;
  const Real _T1_o_nucl;
  const Real _T1_o;

};
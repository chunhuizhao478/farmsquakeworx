/*
Define Function for Initial Static Friction Coefficient for benchmark
*/

#pragma once

#include "Function.h"

class InitialStaticFrictionCoeff : public Function
{
public:
  InitialStaticFrictionCoeff(const InputParameters & parameters);

  static InputParameters validParams();

  using Function::value;
  virtual Real value(Real t, const Point & p) const override;

  Real _patch_xmin;
  Real _patch_xmax;
  Real _patch_ymin;
  Real _patch_ymax;
  Real _mu_s_patch;
  Real _mu_s_outside;

};
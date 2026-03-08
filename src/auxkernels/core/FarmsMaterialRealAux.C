//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

#include "FarmsMaterialRealAux.h"
#include "Assembly.h"

registerMooseObject("farmsquakeworxApp", FarmsMaterialRealAux);

InputParameters
FarmsMaterialRealAux::validParams()
{
  InputParameters params = AuxKernel::validParams();
  params.addClassDescription("Postprocess interface material property to local (fault-aligned) coordinate system.");
  params.addRequiredParam<std::string>("material_property_name", "The name of the material property to be retrieved: local_shear_jump, local_normal_jump, local_shear_traction, local_normal_traction, local_shear_jump_rate, local_normal_jump_rate, normal_x, normal_y, tangent_x, tangent_y");
  params.addRequiredCoupledVar("ini_shear_sts", "initial shear stress");
  params.addRequiredCoupledVar("ini_normal_sts", "initial normal stress");
  params.addCoupledVar("local_jump_for_rate", "Local jump AuxVariable whose old value is used for rate computation");
  return params;
}

FarmsMaterialRealAux::FarmsMaterialRealAux(const InputParameters & parameters)
  : AuxKernel(parameters),
  _material_property_name(getParam<std::string>("material_property_name")),
  _displacement_jump_global_x(getMaterialPropertyByName<Real>("jump_x")),
  _displacement_jump_global_y(getMaterialPropertyByName<Real>("jump_y")),
  _traction_global_x(getMaterialPropertyByName<Real>("traction_x")),
  _traction_global_y(getMaterialPropertyByName<Real>("traction_y")),
  _total_shear_traction(getMaterialPropertyByName<Real>("total_shear_traction")),
  _ini_shear_sts(coupledValue("ini_shear_sts")),
  _ini_normal_sts(coupledValue("ini_normal_sts")),
  _has_local_jump_for_rate(isCoupled("local_jump_for_rate")),
  _local_jump_for_rate_old(_has_local_jump_for_rate ? &coupledValueOld("local_jump_for_rate") : nullptr),
  _normals(_assembly.normals())
{
  if ((_material_property_name == "local_shear_jump_rate" ||
       _material_property_name == "local_normal_jump_rate") &&
      !_has_local_jump_for_rate)
    paramError("local_jump_for_rate",
               "local_jump_for_rate must be coupled when computing jump rates");
}

Real
FarmsMaterialRealAux::computeValue()
{

  Real _value = 0;

  // Get all the global variables

  /*
  * The CZM model defines the jump and traction as: negative side - positive side
  * The global variables are defined as: positive side - negative side
  * Here we reverse the sign to get the correct value
  */

  Real jump_x = -1 * _displacement_jump_global_x[_qp];
  Real jump_y = -1 * _displacement_jump_global_y[_qp];

  /*
  * The traction has units: MPa (change, not total)
  */

  Real traction_x = -1 * _traction_global_x[_qp] / 1e6;
  Real traction_y = -1 * _traction_global_y[_qp] / 1e6;

  /*
  * The normal is defined pointing at the positive side
  */

  Real normal_x = -1 * _normals[_qp](0);
  Real normal_y = -1 * _normals[_qp](1);

  /*
  * The tangential direction is defined follows the direction of right-lateral motion
  */

  Real tangent_x = normal_y;
  Real tangent_y = -1 * normal_x;

  /*
  * We compute local jump, traction in the local coordinate system
  */

  Real local_jump_x = jump_x * tangent_x + jump_y * tangent_y;
  Real local_jump_y = jump_x * normal_x  + jump_y * normal_y;

  Real local_traction_x = traction_x * tangent_x + traction_y * tangent_y;
  Real local_traction_y = traction_x * normal_x  + traction_y * normal_y;

  local_traction_y += _ini_normal_sts[_qp] / 1e6;

  local_traction_x += _ini_shear_sts[_qp] / 1e6;

  // Get the material property name and set the value accordingly
  if (_material_property_name == "local_shear_jump")
  {
    _value = local_jump_x;
  }
  else if (_material_property_name == "local_normal_jump")
  {
    _value = local_jump_y;
  }
  else if (_material_property_name == "local_shear_jump_rate")
  {
    // Rate = (current_local_jump - old_local_jump) / dt
    // Old value comes from coupled AuxVariable (previous timestep)
    _value = (local_jump_x - (*_local_jump_for_rate_old)[_qp]) / _dt;
  }
  else if (_material_property_name == "local_normal_jump_rate")
  {
    _value = (local_jump_y - (*_local_jump_for_rate_old)[_qp]) / _dt;
  }
  else if (_material_property_name == "local_shear_traction")
  {
    _value = _total_shear_traction[_qp];
  }
  else if (_material_property_name == "local_normal_traction")
  {
    _value = local_traction_y;
  }
  else if (_material_property_name == "normal_x")
  {
    _value = normal_x;
  }
  else if (_material_property_name == "normal_y")
  {
    _value = normal_y;
  }
  else if (_material_property_name == "tangent_x")
  {
    _value = tangent_x;
  }
  else if (_material_property_name == "tangent_y")
  {
    _value = tangent_y;
  }
  else
  {
    mooseError("Invalid material property name: " + _material_property_name);
  }

  return _value;
}

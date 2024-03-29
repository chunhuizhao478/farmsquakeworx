//* This file is part of the MOOSE framework
//* https://www.mooseframework.org
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

/*
Material Description of Slip Weakening Friction 3d
*/

#include "SlipWeakeningFriction3d.h"
#include "InterfaceKernel.h"

registerMooseObject("farmsquakeworxApp", SlipWeakeningFriction3d);

InputParameters
SlipWeakeningFriction3d::validParams()
{
  InputParameters params = CZMComputeLocalTractionTotalBase::validParams();
  params.addClassDescription("linear slip weakening traction separation law.");
  params.addRequiredParam<Real>("T2_o", "background normal traction");
  params.addRequiredParam<Real>("T3_o", "background shear traction in dip dir");
  params.addRequiredParam<Real>("mu_d", "value of dynamic friction parameter");
  params.addRequiredParam<Real>("Dc", "value of characteristic length");
  params.addRequiredParam<Real>("len", "element edge length");
  params.addRequiredCoupledVar("disp_slipweakening_x", "displacement in x dir");
  params.addRequiredCoupledVar("disp_slipweakening_y", "displacement in y dir");
  params.addRequiredCoupledVar("disp_slipweakening_z", "displacement in z dir");
  params.addRequiredCoupledVar("reaction_slipweakening_x", "reaction in x dir");
  params.addRequiredCoupledVar("reaction_slipweakening_y", "reaction in y dir");
  params.addRequiredCoupledVar("reaction_slipweakening_z", "reaction in z dir");
  params.addRequiredCoupledVar("mu_s", "static friction coefficient spatial distribution");
  params.addRequiredCoupledVar("ini_shear_sts", "initial shear stress spatial distribution");
  return params;
}

SlipWeakeningFriction3d::SlipWeakeningFriction3d(const InputParameters & parameters)
  : CZMComputeLocalTractionTotalBase(parameters),
    _T2_o(getParam<Real>("T2_o")),
    _T3_o(getParam<Real>("T3_o")),
    _mu_d(getParam<Real>("mu_d")),
    _Dc(getParam<Real>("Dc")),
    _len(getParam<Real>("len")),
    _density(getMaterialPropertyByName<Real>(_base_name + "density")),
    _rot(getMaterialPropertyByName<RankTwoTensor>(_base_name + "czm_total_rotation")),
    _disp_slipweakening_x(coupledValue("disp_slipweakening_x")),
    _disp_slipweakening_neighbor_x(coupledNeighborValue("disp_slipweakening_x")),
    _disp_slipweakening_y(coupledValue("disp_slipweakening_y")),
    _disp_slipweakening_neighbor_y(coupledNeighborValue("disp_slipweakening_y")),
    _disp_slipweakening_z(coupledValue("disp_slipweakening_z")),
    _disp_slipweakening_neighbor_z(coupledNeighborValue("disp_slipweakening_z")),
    _reaction_slipweakening_x(coupledValue("reaction_slipweakening_x")),
    _reaction_slipweakening_neighbor_x(coupledNeighborValue("reaction_slipweakening_x")),
    _reaction_slipweakening_y(coupledValue("reaction_slipweakening_y")),
    _reaction_slipweakening_neighbor_y(coupledNeighborValue("reaction_slipweakening_y")),
    _reaction_slipweakening_z(coupledValue("reaction_slipweakening_z")),
    _reaction_slipweakening_neighbor_z(coupledNeighborValue("reaction_slipweakening_z")),
    _disp_slipweakening_x_old(coupledValueOld("disp_slipweakening_x")),
    _disp_slipweakening_neighbor_x_old(coupledNeighborValueOld("disp_slipweakening_x")),
    _disp_slipweakening_y_old(coupledValueOld("disp_slipweakening_y")),
    _disp_slipweakening_neighbor_y_old(coupledNeighborValueOld("disp_slipweakening_y")),
    _disp_slipweakening_z_old(coupledValueOld("disp_slipweakening_z")),
    _disp_slipweakening_neighbor_z_old(coupledNeighborValueOld("disp_slipweakening_z")),
    _mu_s(coupledValue("mu_s")),
    _ini_shear_sts(coupledValue("ini_shear_sts"))
{

  // only works for small strain
  if (hasBlockMaterialProperty<RankTwoTensor>(_base_name + "strain_increment"))
  {
    mooseError("SlipWeakening only works for small strain!");
  }
}

void
SlipWeakeningFriction3d::computeInterfaceTractionAndDerivatives()
{
  // Global Displacement Jump
  RealVectorValue displacement_jump_global(
      _disp_slipweakening_x[_qp] - _disp_slipweakening_neighbor_x[_qp],
      _disp_slipweakening_y[_qp] - _disp_slipweakening_neighbor_y[_qp],
      _disp_slipweakening_z[_qp] - _disp_slipweakening_neighbor_z[_qp]);

  // Global Displacement Jump Old
  RealVectorValue displacement_jump_old_global(
      _disp_slipweakening_x_old[_qp] - _disp_slipweakening_neighbor_x_old[_qp],
      _disp_slipweakening_y_old[_qp] - _disp_slipweakening_neighbor_y_old[_qp],
      _disp_slipweakening_z_old[_qp] - _disp_slipweakening_neighbor_z_old[_qp]);

  // Global Displacement Jump Rate
  RealVectorValue displacement_jump_rate_global =
      (displacement_jump_global - displacement_jump_old_global) * (1 / _dt);

  // Local Displacement Jump / Displacement Jump Rate
  RealVectorValue displacement_jump = _rot[_qp].transpose() * displacement_jump_global;
  RealVectorValue displacement_jump_rate = _rot[_qp].transpose() * displacement_jump_rate_global;

  // n is along normal direction; t is along tangential direction; d is along dip direction
  Real displacement_jump_n = displacement_jump(0);
  Real displacement_jump_rate_n = displacement_jump_rate(0);
  Real displacement_jump_rate_t = displacement_jump_rate(1);
  Real displacement_jump_rate_d = displacement_jump_rate(2);

  // Parameter initialization
  Real tau_f = 0;

  // Reaction force in local coordinate
  RealVectorValue R_plus_global(-_reaction_slipweakening_x[_qp],
                                -_reaction_slipweakening_y[_qp],
                                -_reaction_slipweakening_z[_qp]);
  RealVectorValue R_minus_global(-_reaction_slipweakening_neighbor_x[_qp],
                                 -_reaction_slipweakening_neighbor_y[_qp],
                                 -_reaction_slipweakening_neighbor_z[_qp]);

  RealVectorValue R_plus_local = _rot[_qp].transpose() * R_plus_global;
  RealVectorValue R_minus_local = _rot[_qp].transpose() * R_minus_global;

  // n is along normal direction; t is along tangential direction; d is along dip direction
  Real R_plus_local_n = R_plus_local(0);
  Real R_plus_local_t = R_plus_local(1);
  Real R_plus_local_d = R_plus_local(2);
  Real R_minus_local_n = R_minus_local(0);
  Real R_minus_local_t = R_minus_local(1);
  Real R_minus_local_d = R_minus_local(2);

  // Compute node mass
  Real M = _density[_qp] * _len * _len * _len / 2;

  // Compute T1_o, T2_o, T3_o for current qp
  Real T1_o = _ini_shear_sts[_qp];
  Real T2_o = _T2_o;
  Real T3_o = _T3_o;

  // Compute sticking stress
  Real T1 = (1 / _dt) * M * displacement_jump_rate_t / (2 * _len * _len) +
            (R_plus_local_t - R_minus_local_t) / (2 * _len * _len) + T1_o;
  Real T3 = (1 / _dt) * M * displacement_jump_rate_d / (2 * _len * _len) +
            (R_plus_local_d - R_minus_local_d) / (2 * _len * _len) + T3_o;
  Real T2 = -(1 / _dt) * M * (displacement_jump_rate_n + (1 / _dt) * displacement_jump_n) /
                (2 * _len * _len) +
            ((R_minus_local_n - R_plus_local_n) / (2 * _len * _len)) - T2_o;

  // Compute fault traction
  if (T2 < 0)
  {
  }
  else
  {
    T2 = 0;
  }

  // Compute friction strength
  if (std::norm(displacement_jump) < _Dc)
  {
    tau_f = (_mu_s[_qp] - (_mu_s[_qp] - _mu_d) * std::norm(displacement_jump) / _Dc) *
            (-T2); // square for shear component
  }
  else
  {
    tau_f = _mu_d * (-T2);
  }

  // Compute fault traction
  if (std::sqrt(T1 * T1 + T3 * T3) < tau_f)
  {
  }
  else
  {
    T1 = tau_f * T1 / std::sqrt(T1 * T1 + T3 * T3);
    T3 = tau_f * T3 / std::sqrt(T1 * T1 + T3 * T3);
  }

  // Assign back traction in CZM
  RealVectorValue traction(T2 + T2_o, -T1 + T1_o, -T3 + T3_o);
  _interface_traction[_qp] = traction;
  _dinterface_traction_djump[_qp] = 0;
}

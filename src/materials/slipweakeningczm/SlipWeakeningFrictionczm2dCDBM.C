//* This file is part of the MOOSE framework
//* https://www.mooseframework.org
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

/*
Material Description of Slip Weakening Friction Law 2D (CDBM-coupled)
*/

#include "SlipWeakeningFrictionczm2dCDBM.h"
#include "InterfaceKernel.h"

registerMooseObject("farmsquakeworxApp", SlipWeakeningFrictionczm2dCDBM);

InputParameters
SlipWeakeningFrictionczm2dCDBM::validParams()
{
  InputParameters params = CZMComputeLocalTractionTotalBase::validParams();
  params.addClassDescription("linear slip weakening traction separation law (2D CDBM-coupled).");
  params.addRequiredParam<Real>("mu_s", "static friction coefficient");
  params.addRequiredParam<Real>("mu_d", "value of dynamic friction parameter");
  params.addRequiredParam<Real>("Dc", "value of characteristic length");
  params.addRequiredParam<Real>("len", "element edge length");
  params.addRequiredCoupledVar("disp_slipweakening_x", "displacement in x dir");
  params.addRequiredCoupledVar("disp_slipweakening_y", "displacement in y dir");
  params.addRequiredCoupledVar("reaction_slipweakening_x", "reaction in x dir");
  params.addRequiredCoupledVar("reaction_slipweakening_y", "reaction in y dir");
  params.addParam<Real>("peak_shear_stress", "peak shear stress");
  params.addParam<std::vector<Real>>("nucl_center", "nucleation center");
  params.addParam<Real>("nucl_radius", "nucleation radius");
  return params;
}

SlipWeakeningFrictionczm2dCDBM::SlipWeakeningFrictionczm2dCDBM(const InputParameters & parameters)
  : CZMComputeLocalTractionTotalBase(parameters),
    _mu_s(getParam<Real>("mu_s")),
    _mu_d(getParam<Real>("mu_d")),
    _Dc(getParam<Real>("Dc")),
    _len(getParam<Real>("len")),
    _density(getMaterialPropertyByName<Real>(_base_name + "density")),
    _rot(getMaterialPropertyByName<RankTwoTensor>(_base_name + "czm_total_rotation")),
    _disp_slipweakening_x(coupledValue("disp_slipweakening_x")),
    _disp_slipweakening_neighbor_x(coupledNeighborValue("disp_slipweakening_x")),
    _disp_slipweakening_y(coupledValue("disp_slipweakening_y")),
    _disp_slipweakening_neighbor_y(coupledNeighborValue("disp_slipweakening_y")),
    _reaction_slipweakening_x(coupledValue("reaction_slipweakening_x")),
    _reaction_slipweakening_neighbor_x(coupledNeighborValue("reaction_slipweakening_x")),
    _reaction_slipweakening_y(coupledValue("reaction_slipweakening_y")),
    _reaction_slipweakening_neighbor_y(coupledNeighborValue("reaction_slipweakening_y")),
    _disp_slipweakening_x_old(coupledValueOld("disp_slipweakening_x")),
    _disp_slipweakening_neighbor_x_old(coupledNeighborValueOld("disp_slipweakening_x")),
    _disp_slipweakening_y_old(coupledValueOld("disp_slipweakening_y")),
    _disp_slipweakening_neighbor_y_old(coupledNeighborValueOld("disp_slipweakening_y")),
    _displacement_jump_strike(declareProperty<Real>("displacement_jump_strike")),
    _displacement_jump_normal(declareProperty<Real>("displacement_jump_normal")),
    _displacement_jump_rate_strike(declareProperty<Real>("displacement_jump_rate_strike")),
    _displacement_jump_rate_normal(declareProperty<Real>("displacement_jump_rate_normal")),
    _traction_strike(declareProperty<Real>("traction_strike")),
    _traction_normal(declareProperty<Real>("traction_normal")),
    _static_initial_stress_tensor(
        getMaterialPropertyByName<RankTwoTensor>(_base_name + "static_initial_stress_tensor")),
    _peak_shear_stress(getParam<Real>("peak_shear_stress")),
    _nucl_center(getParam<std::vector<Real>>("nucl_center")),
    _nucl_radius(getParam<Real>("nucl_radius"))
{
  // only works for small strain
  if (hasBlockMaterialProperty<RankTwoTensor>(_base_name + "strain_increment"))
    mooseError("SlipWeakening only works for small strain!");
}

void
SlipWeakeningFrictionczm2dCDBM::computeInterfaceTractionAndDerivatives()
{
  // Global Displacement Jump
  RealVectorValue displacement_jump_global(
      _disp_slipweakening_x[_qp] - _disp_slipweakening_neighbor_x[_qp],
      _disp_slipweakening_y[_qp] - _disp_slipweakening_neighbor_y[_qp]);

  // Global Displacement Jump Old
  RealVectorValue displacement_jump_old_global(
      _disp_slipweakening_x_old[_qp] - _disp_slipweakening_neighbor_x_old[_qp],
      _disp_slipweakening_y_old[_qp] - _disp_slipweakening_neighbor_y_old[_qp]);

  // Global Displacement Jump Rate
  RealVectorValue displacement_jump_rate_global =
      (displacement_jump_global - displacement_jump_old_global) * (1 / _dt);

  // Local Displacement Jump / Displacement Jump Rate
  RealVectorValue displacement_jump = _rot[_qp].transpose() * displacement_jump_global;
  RealVectorValue displacement_jump_rate = _rot[_qp].transpose() * displacement_jump_rate_global;

  // t is along tangential direction, n is along normal direction
  Real displacement_jump_n = displacement_jump(0);
  Real displacement_jump_t = displacement_jump(1);
  Real displacement_jump_rate_n = displacement_jump_rate(0);
  Real displacement_jump_rate_t = displacement_jump_rate(1);

  // Parameter initialization
  Real tau_f = 0;

  // Reaction force in local coordinate
  RealVectorValue R_plus_global(
      -_reaction_slipweakening_x[_qp], -_reaction_slipweakening_y[_qp], 0);
  RealVectorValue R_minus_global(
      -_reaction_slipweakening_neighbor_x[_qp], -_reaction_slipweakening_neighbor_y[_qp], 0);

  RealVectorValue R_plus_local = _rot[_qp].transpose() * R_plus_global;
  RealVectorValue R_minus_local = _rot[_qp].transpose() * R_minus_global;

  Real R_plus_local_n = R_plus_local(0);
  Real R_plus_local_t = R_plus_local(1);
  Real R_minus_local_n = R_minus_local(0);
  Real R_minus_local_t = R_minus_local(1);

  // Compute node mass and area based on elem type
  Real M = 0;
  if (_current_elem->type() == libMesh::ElemType::TRI3)
    M = _density[_qp] * sqrt(3) / 4 * _len * _len / 3;
  else if (_current_elem->type() == libMesh::ElemType::QUAD4)
    M = _density[_qp] * _len * _len / 4 * 2;

  // Rotate the global stress tensor into fault-local coordinates and extract
  // the traction on the fault plane. The CZM rotation matrix _rot maps from
  // fault-local to global; the local frame uses component(0) = normal,
  // component(1) = tangential. Mirrors the convention in
  // SlipWeakeningFrictionczm2dParametricStudy::computeInterfaceTractionAndDerivatives()
  // (lines 165-178), where T1_o = traction_local(1) (shear) and
  // T2_o = -traction_local(0) (normal, compression-positive).
  RankTwoTensor sts_init_local =
      _rot[_qp].transpose() * _static_initial_stress_tensor[_qp] * _rot[_qp];
  RealVectorValue local_normal(1.0, 0.0, 0.0);
  RealVectorValue traction_local = sts_init_local * local_normal;
  Real T1_o = traction_local(1);   // shear (local-tangential)
  Real T2_o = -traction_local(0);  // normal (compression-positive)

  // Get point location and apply nucleation overstress patch
  Real x_coord = _q_point[_qp](0);
  Real y_coord = _q_point[_qp](1);
  if (x_coord > _nucl_center[0] - _nucl_radius && x_coord < _nucl_center[0] + _nucl_radius &&
      y_coord > _nucl_center[1] - _nucl_radius && y_coord < _nucl_center[1] + _nucl_radius)
  {
    T1_o = _peak_shear_stress;
  }

  // Compute sticking stress
  Real T1 = (1 / _dt) * M * displacement_jump_rate_t / (2 * _len) +
            (R_plus_local_t - R_minus_local_t) / (2 * _len) + T1_o;

  Real T2 =
      -(1 / _dt) * M * (displacement_jump_rate_n + (1 / _dt) * displacement_jump_n) / (2 * _len) +
      ((R_minus_local_n - R_plus_local_n) / (2 * _len)) - T2_o;

  // Open fault clamp
  if (T2 >= 0)
    T2 = 0;

  if (T1 > 0)
  {
    if (std::abs(displacement_jump_t) < _Dc)
      tau_f = (_mu_s - (_mu_s - _mu_d) * std::abs(displacement_jump_t) / _Dc) * (-T2);
    else
      tau_f = _mu_d * (-T2);
  }
  else
  {
    if (std::abs(displacement_jump_t) < _Dc)
      tau_f = (-_mu_s + (_mu_s - _mu_d) * std::abs(displacement_jump_t) / _Dc) * (-T2);
    else
      tau_f = -_mu_d * (-T2);
  }

  // Stick / slip
  if ((T1 < 0 && T1 > tau_f) || (T1 > 0 && T1 < tau_f))
  {
    // stuck: T1 unchanged
  }
  else
  {
    if (T1 > 0)
      T1 = 1 * tau_f * T1 / std::abs(T1);
    else
      T1 = -1 * tau_f * T1 / std::abs(T1);
  }

  // Save displacement jump in local coordinate
  _displacement_jump_strike[_qp] = displacement_jump_t;
  _displacement_jump_normal[_qp] = displacement_jump_n;

  // Save displacement jump rate in local coordinate
  _displacement_jump_rate_strike[_qp] = displacement_jump_rate_t;
  _displacement_jump_rate_normal[_qp] = displacement_jump_rate_n;

  // Save traction in local coordinate
  _traction_strike[_qp] = T1;
  _traction_normal[_qp] = T2;

  // Assign back traction in CZM (local frame: n,t)
  RealVectorValue traction(T2 + T2_o, -T1 + T1_o, 0);
  _interface_traction[_qp] = traction;
  _dinterface_traction_djump[_qp] = 0;
}

//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

/*
 * Unit tests for ForcedRuptureTimeCDBMv2 Function.
 *
 * T(r) = r / (0.7*Vs) + (0.081*r_crit) / (0.7*Vs) * (1/(1-(r/r_crit)^2) - 1)
 * for r < r_crit, else T = 1e9.
 */

#include "MooseObjectUnitTest.h"
#include "ForcedRuptureTimeCDBMv2.h"

class ForcedRuptureTimeCDBMv2Test : public MooseObjectUnitTest
{
public:
  ForcedRuptureTimeCDBMv2Test() : MooseObjectUnitTest("farmsquakeworxApp") {}

protected:
  void buildFunction(Real loc_x, Real loc_y, Real loc_z, Real r_crit, Real Vs)
  {
    InputParameters params = _factory.getValidParams("ForcedRuptureTimeCDBMv2");
    params.set<FEProblem *>("_fe_problem") = _fe_problem.get();
    params.set<FEProblemBase *>("_fe_problem_base") = _fe_problem.get();
    params.set<Real>("loc_x") = loc_x;
    params.set<Real>("loc_y") = loc_y;
    params.set<Real>("loc_z") = loc_z;
    params.set<Real>("r_crit") = r_crit;
    params.set<Real>("Vs") = Vs;
    _fe_problem->addFunction("ForcedRuptureTimeCDBMv2", _name, params);
    _func = &_fe_problem->getFunction(_name);
    _name_idx++;
    _name = "test_func_" + std::to_string(_name_idx);
  }

  const Function * _func = nullptr;
  std::string _name = "test_func_0";
  int _name_idx = 0;
};

// ---- At hypocenter: r=0, T=0 ----
TEST_F(ForcedRuptureTimeCDBMv2Test, AtHypocenter)
{
  buildFunction(0.0, 0.0, -7500.0, 3000.0, 3464.0);
  Real val = _func->value(0.0, Point(0.0, 0.0, -7500.0));
  EXPECT_NEAR(val, 0.0, 1e-10);
}

// ---- Outside critical radius: T = 1e9 ----
TEST_F(ForcedRuptureTimeCDBMv2Test, OutsideCritical)
{
  buildFunction(0.0, 0.0, -7500.0, 3000.0, 3464.0);
  Real val = _func->value(0.0, Point(5000.0, 0.0, -7500.0));
  EXPECT_NEAR(val, 1e9, 1e-3);
}

// ---- At critical radius: T = 1e9 ----
TEST_F(ForcedRuptureTimeCDBMv2Test, AtCritical)
{
  buildFunction(0.0, 0.0, -7500.0, 3000.0, 3464.0);
  Real val = _func->value(0.0, Point(3000.0, 0.0, -7500.0));
  EXPECT_NEAR(val, 1e9, 1e-3);
}

// ---- Monotonicity: T increases with r (for r < r_crit) ----
TEST_F(ForcedRuptureTimeCDBMv2Test, Monotonicity)
{
  buildFunction(0.0, 0.0, -7500.0, 3000.0, 3464.0);
  Real T1 = _func->value(0.0, Point(500.0, 0.0, -7500.0));
  Real T2 = _func->value(0.0, Point(1000.0, 0.0, -7500.0));
  Real T3 = _func->value(0.0, Point(2000.0, 0.0, -7500.0));
  EXPECT_GT(T1, 0.0);
  EXPECT_GT(T2, T1);
  EXPECT_GT(T3, T2);
}

// ---- Symmetry: same distance in different directions -> same T ----
TEST_F(ForcedRuptureTimeCDBMv2Test, Symmetry)
{
  buildFunction(0.0, 0.0, -7500.0, 3000.0, 3464.0);
  Real T_pos = _func->value(0.0, Point(1000.0, 0.0, -7500.0));
  Real T_neg = _func->value(0.0, Point(-1000.0, 0.0, -7500.0));
  EXPECT_NEAR(T_pos, T_neg, 1e-10);
}

// ---- T is positive for r > 0 inside critical radius ----
TEST_F(ForcedRuptureTimeCDBMv2Test, PositiveInside)
{
  buildFunction(0.0, 0.0, -7500.0, 3000.0, 3464.0);
  Real val = _func->value(0.0, Point(1500.0, 0.0, -7500.0));
  EXPECT_GT(val, 0.0);
  EXPECT_LT(val, 1e9);
}

// ---- Time-independent ----
TEST_F(ForcedRuptureTimeCDBMv2Test, TimeIndependent)
{
  buildFunction(0.0, 0.0, -7500.0, 3000.0, 3464.0);
  Point p(1000.0, 0.0, -7500.0);
  Real val_t0 = _func->value(0.0, p);
  Real val_t100 = _func->value(100.0, p);
  EXPECT_NEAR(val_t0, val_t100, 1e-15);
}

//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

/*
 * Unit tests for InitialCohesionCDBMv2 Function.
 *
 * Piecewise linear cohesion based on depth:
 *   if |z| <= depth:  Co = min_cohesion*1e6 + slope*1e6 * (depth - |z|)
 *   else:             Co = min_cohesion*1e6
 */

#include "MooseObjectUnitTest.h"
#include "InitialCohesionCDBMv2.h"

class InitialCohesionCDBMv2Test : public MooseObjectUnitTest
{
public:
  InitialCohesionCDBMv2Test() : MooseObjectUnitTest("farmsquakeworxApp") {}

protected:
  void buildFunction(Real depth, Real slope, Real min_cohesion)
  {
    InputParameters params = _factory.getValidParams("InitialCohesionCDBMv2");
    params.set<FEProblem *>("_fe_problem") = _fe_problem.get();
    params.set<FEProblemBase *>("_fe_problem_base") = _fe_problem.get();
    params.set<Real>("depth") = depth;
    params.set<Real>("slope") = slope;
    params.set<Real>("min_cohesion") = min_cohesion;
    _fe_problem->addFunction("InitialCohesionCDBMv2", _name, params);
    _func = &_fe_problem->getFunction(_name);
    _name_idx++;
    _name = "test_func_" + std::to_string(_name_idx);
  }

  const Function * _func = nullptr;
  std::string _name = "test_func_0";
  int _name_idx = 0;
};

// ---- At surface (z=0): Co = min_cohesion*1e6 + slope*1e6 * depth ----
TEST_F(InitialCohesionCDBMv2Test, AtSurface)
{
  buildFunction(1000.0, 5.0, 2.0);
  Real val = _func->value(0.0, Point(0.0, 0.0, 0.0));
  Real expected = 2.0e6 + 5.0e6 * 1000.0; // = 5002e6
  EXPECT_NEAR(val, expected, 1e-3);
}

// ---- At max depth (z=-depth): Co = min_cohesion*1e6 ----
TEST_F(InitialCohesionCDBMv2Test, AtMaxDepth)
{
  buildFunction(1000.0, 5.0, 2.0);
  Real val = _func->value(0.0, Point(0.0, 0.0, -1000.0));
  EXPECT_NEAR(val, 2.0e6, 1e-3);
}

// ---- Below max depth (z=-2000): Co = min_cohesion*1e6 (clamped) ----
TEST_F(InitialCohesionCDBMv2Test, BelowMaxDepth)
{
  buildFunction(1000.0, 5.0, 2.0);
  Real val = _func->value(0.0, Point(0.0, 0.0, -2000.0));
  EXPECT_NEAR(val, 2.0e6, 1e-3);
}

// ---- Mid depth (z=-500): Co = min_cohesion*1e6 + slope*1e6 * (depth - 500) ----
TEST_F(InitialCohesionCDBMv2Test, MidDepth)
{
  buildFunction(1000.0, 5.0, 2.0);
  Real val = _func->value(0.0, Point(0.0, 0.0, -500.0));
  Real expected = 2.0e6 + 5.0e6 * 500.0; // = 2502e6
  EXPECT_NEAR(val, expected, 1e-3);
}

// ---- Time-independent ----
TEST_F(InitialCohesionCDBMv2Test, TimeIndependent)
{
  buildFunction(1000.0, 5.0, 2.0);
  Point p(0.0, 0.0, -500.0);
  Real val_t0 = _func->value(0.0, p);
  Real val_t100 = _func->value(100.0, p);
  EXPECT_NEAR(val_t0, val_t100, 1e-15);
}

// ---- Depth varies only with z coordinate, not x or y ----
TEST_F(InitialCohesionCDBMv2Test, OnlyZMatters)
{
  buildFunction(1000.0, 5.0, 2.0);
  Real val1 = _func->value(0.0, Point(0.0, 0.0, -500.0));
  Real val2 = _func->value(0.0, Point(1000.0, 2000.0, -500.0));
  EXPECT_NEAR(val1, val2, 1e-15);
}

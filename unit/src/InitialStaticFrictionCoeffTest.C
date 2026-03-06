//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

/*
 * Unit tests for InitialStaticFrictionCoeff Function.
 *
 * Returns mu_s_patch inside the rectangular patch, mu_s_outside elsewhere.
 * Default patch: x in [-15e3, 15e3], y in [-15e3, 0]
 * Default values: mu_s_patch=0.677, mu_s_outside=10000
 */

#include "MooseObjectUnitTest.h"
#include "InitialStaticFrictionCoeff.h"

class InitialStaticFrictionCoeffTest : public MooseObjectUnitTest
{
public:
  InitialStaticFrictionCoeffTest() : MooseObjectUnitTest("farmsquakeworxApp") {}

protected:
  void buildFunction(Real xmin = -15e3,
                     Real xmax = 15e3,
                     Real ymin = -15e3,
                     Real ymax = 0.0,
                     Real mu_s_patch = 0.677,
                     Real mu_s_outside = 10000.0)
  {
    InputParameters params = _factory.getValidParams("InitialStaticFrictionCoeff");
    params.set<FEProblem *>("_fe_problem") = _fe_problem.get();
    params.set<FEProblemBase *>("_fe_problem_base") = _fe_problem.get();
    params.set<Real>("patch_xmin") = xmin;
    params.set<Real>("patch_xmax") = xmax;
    params.set<Real>("patch_ymin") = ymin;
    params.set<Real>("patch_ymax") = ymax;
    params.set<Real>("mu_s_patch") = mu_s_patch;
    params.set<Real>("mu_s_outside") = mu_s_outside;
    _fe_problem->addFunction("InitialStaticFrictionCoeff", _name, params);
    _func = &_fe_problem->getFunction(_name);
    _name_idx++;
    _name = "test_func_" + std::to_string(_name_idx);
  }

  const Function * _func = nullptr;
  std::string _name = "test_func_0";
  int _name_idx = 0;
};

// ---- Inside patch (default params): mu_s = 0.677 ----
TEST_F(InitialStaticFrictionCoeffTest, InsidePatch)
{
  buildFunction();
  Real val = _func->value(0.0, Point(0.0, -7500.0, 0.0));
  EXPECT_NEAR(val, 0.677, 1e-15);
}

// ---- Outside patch: mu_s = 10000 ----
TEST_F(InitialStaticFrictionCoeffTest, OutsidePatch)
{
  buildFunction();
  Real val = _func->value(0.0, Point(0.0, 5000.0, 0.0));
  EXPECT_NEAR(val, 10000.0, 1e-15);
}

// ---- At boundary (x=patch_xmax, y=patch_ymax): inside ----
TEST_F(InitialStaticFrictionCoeffTest, AtBoundary)
{
  buildFunction();
  Real val = _func->value(0.0, Point(15e3, 0.0, 0.0));
  EXPECT_NEAR(val, 0.677, 1e-15);
}

// ---- Just outside boundary ----
TEST_F(InitialStaticFrictionCoeffTest, JustOutsideBoundary)
{
  buildFunction();
  Real val = _func->value(0.0, Point(15001.0, -7500.0, 0.0));
  EXPECT_NEAR(val, 10000.0, 1e-15);
}

// ---- Custom parameters ----
TEST_F(InitialStaticFrictionCoeffTest, CustomParams)
{
  buildFunction(-100.0, 100.0, -200.0, 0.0, 0.5, 1000.0);
  Real val_inside = _func->value(0.0, Point(0.0, -100.0, 0.0));
  Real val_outside = _func->value(0.0, Point(200.0, -100.0, 0.0));
  EXPECT_NEAR(val_inside, 0.5, 1e-15);
  EXPECT_NEAR(val_outside, 1000.0, 1e-15);
}

// ---- z-coordinate does not affect result ----
TEST_F(InitialStaticFrictionCoeffTest, ZIndependent)
{
  buildFunction();
  Real val1 = _func->value(0.0, Point(0.0, -7500.0, 0.0));
  Real val2 = _func->value(0.0, Point(0.0, -7500.0, 5000.0));
  EXPECT_NEAR(val1, val2, 1e-15);
}

// ---- Time-independent ----
TEST_F(InitialStaticFrictionCoeffTest, TimeIndependent)
{
  buildFunction();
  Point p(0.0, -7500.0, 0.0);
  Real val_t0 = _func->value(0.0, p);
  Real val_t100 = _func->value(100.0, p);
  EXPECT_NEAR(val_t0, val_t100, 1e-15);
}

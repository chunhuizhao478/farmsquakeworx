//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

/*
 * Unit tests for InitialShearStressTPV2053d Function.
 *
 * Tests the spatial patches of initial shear stress for the TPV205 benchmark:
 *   Center patch:  [-1500, 1500] x [-9000, -6000]  -> 81.6 MPa
 *   Left patch:    [-9000, -6000] x [-9000, -6000]  -> 78.0 MPa
 *   Right patch:   [6000, 9000] x [-9000, -6000]    -> 62.0 MPa
 *   Background:                                      -> 70.0 MPa
 */

#include "MooseObjectUnitTest.h"
#include "InitialShearStressTPV2053d.h"

class InitialShearStressTPV2053dTest : public MooseObjectUnitTest
{
public:
  InitialShearStressTPV2053dTest() : MooseObjectUnitTest("farmsquakeworxApp") {}

protected:
  void buildFunction()
  {
    InputParameters params = _factory.getValidParams("InitialShearStressTPV2053d");
    params.set<FEProblem *>("_fe_problem") = _fe_problem.get();
    params.set<FEProblemBase *>("_fe_problem_base") = _fe_problem.get();
    _fe_problem->addFunction("InitialShearStressTPV2053d", "test_func", params);
    _func = &_fe_problem->getFunction("test_func");
  }

  const Function * _func = nullptr;
};

// ---- Center patch: (0, 0, -7500) -> 81.6 MPa ----
TEST_F(InitialShearStressTPV2053dTest, CenterPatch)
{
  buildFunction();
  Real val = _func->value(0.0, Point(0.0, 0.0, -7500.0));
  EXPECT_NEAR(val, 81.6e6, 1e-3);
}

// ---- Left patch: (-7500, 0, -7500) -> 78.0 MPa ----
TEST_F(InitialShearStressTPV2053dTest, LeftPatch)
{
  buildFunction();
  Real val = _func->value(0.0, Point(-7500.0, 0.0, -7500.0));
  EXPECT_NEAR(val, 78.0e6, 1e-3);
}

// ---- Right patch: (7500, 0, -7500) -> 62.0 MPa ----
TEST_F(InitialShearStressTPV2053dTest, RightPatch)
{
  buildFunction();
  Real val = _func->value(0.0, Point(7500.0, 0.0, -7500.0));
  EXPECT_NEAR(val, 62.0e6, 1e-3);
}

// ---- Background: (0, 0, 0) -> 70.0 MPa ----
TEST_F(InitialShearStressTPV2053dTest, Background)
{
  buildFunction();
  Real val = _func->value(0.0, Point(0.0, 0.0, 0.0));
  EXPECT_NEAR(val, 70.0e6, 1e-3);
}

// ---- Patch boundary inside: (1500, 0, -6000) is inside center patch ----
TEST_F(InitialShearStressTPV2053dTest, PatchBoundaryInside)
{
  buildFunction();
  Real val = _func->value(0.0, Point(1500.0, 0.0, -6000.0));
  EXPECT_NEAR(val, 81.6e6, 1e-3);
}

// ---- Patch boundary outside: (1501, 0, -6000) is outside center patch ----
TEST_F(InitialShearStressTPV2053dTest, PatchBoundaryOutside)
{
  buildFunction();
  Real val = _func->value(0.0, Point(1501.0, 0.0, -6000.0));
  EXPECT_NEAR(val, 70.0e6, 1e-3);
}

// ---- Time-independent: same value at t=0 and t=100 ----
TEST_F(InitialShearStressTPV2053dTest, TimeIndependent)
{
  buildFunction();
  Point p(0.0, 0.0, -7500.0);
  Real val_t0 = _func->value(0.0, p);
  Real val_t100 = _func->value(100.0, p);
  EXPECT_NEAR(val_t0, val_t100, 1e-15);
}

// ---- Background far from all patches ----
TEST_F(InitialShearStressTPV2053dTest, FarFromPatches)
{
  buildFunction();
  Real val = _func->value(0.0, Point(20000.0, 0.0, -20000.0));
  EXPECT_NEAR(val, 70.0e6, 1e-3);
}

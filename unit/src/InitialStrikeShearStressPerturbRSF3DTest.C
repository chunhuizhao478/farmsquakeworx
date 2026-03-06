//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

/*
 * Unit tests for InitialStrikeShearStressPerturbRSF3D Function.
 *
 * Same formula as 2D but with r = sqrt((x-x_o)^2 + (z-z_o)^2)
 * where x_o = 0, z_o = 0.
 *
 * T1_o = T1_perturb * F(r, R) * G(t, T)
 * Hardcoded: T1_perturb=25e6, R=3000, T=1.0
 */

#include "MooseObjectUnitTest.h"
#include "InitialStrikeShearStressPerturbRSF3D.h"

class InitialStrikeShearStressPerturbRSF3DTest : public MooseObjectUnitTest
{
public:
  InitialStrikeShearStressPerturbRSF3DTest() : MooseObjectUnitTest("farmsquakeworxApp") {}

protected:
  void buildFunction()
  {
    InputParameters params = _factory.getValidParams("InitialStrikeShearStressPerturbRSF3D");
    params.set<FEProblem *>("_fe_problem") = _fe_problem.get();
    params.set<FEProblemBase *>("_fe_problem_base") = _fe_problem.get();
    _fe_problem->addFunction("InitialStrikeShearStressPerturbRSF3D", "test_func", params);
    _func = &_fe_problem->getFunction("test_func");
  }

  const Function * _func = nullptr;
};

// ---- Zero at time zero ----
TEST_F(InitialStrikeShearStressPerturbRSF3DTest, ZeroAtTimeZero)
{
  buildFunction();
  Real val = _func->value(0.0, Point(0.0, 0.0, 0.0));
  EXPECT_NEAR(val, 0.0, 1e-10);
}

// ---- Zero outside R ----
TEST_F(InitialStrikeShearStressPerturbRSF3DTest, ZeroOutsideR)
{
  buildFunction();
  Real val = _func->value(5.0, Point(4000.0, 0.0, 0.0));
  EXPECT_NEAR(val, 0.0, 1e-10);
}

// ---- Steady state after T at origin ----
TEST_F(InitialStrikeShearStressPerturbRSF3DTest, SteadyAfterT)
{
  buildFunction();
  Real val = _func->value(5.0, Point(0.0, 0.0, 0.0));
  EXPECT_NEAR(val, 25e6, 1e-3);
}

// ---- 3D radius: r = sqrt((x-x_o)^2 + (z-z_o)^2), y doesn't matter ----
TEST_F(InitialStrikeShearStressPerturbRSF3DTest, YIndependent)
{
  buildFunction();
  Real t = 5.0;
  Real val_y0 = _func->value(t, Point(1000.0, 0.0, 0.0));
  Real val_y5000 = _func->value(t, Point(1000.0, 5000.0, 0.0));
  EXPECT_NEAR(val_y0, val_y5000, 1e-10);
}

// ---- Symmetry: r depends on |x| and |z| ----
TEST_F(InitialStrikeShearStressPerturbRSF3DTest, Symmetry)
{
  buildFunction();
  Real t = 5.0;
  Real val1 = _func->value(t, Point(1000.0, 0.0, 1000.0));
  Real val2 = _func->value(t, Point(-1000.0, 0.0, -1000.0));
  EXPECT_NEAR(val1, val2, 1e-10);
}

// ---- Monotonic spatial decay ----
TEST_F(InitialStrikeShearStressPerturbRSF3DTest, MonotonicSpatialDecay)
{
  buildFunction();
  Real t = 5.0;
  Real val_near = _func->value(t, Point(500.0, 0.0, 0.0));
  Real val_far = _func->value(t, Point(2000.0, 0.0, 0.0));
  EXPECT_GT(val_near, val_far);
}

// ---- 3D: r uses x and z, same distance different decomposition ----
TEST_F(InitialStrikeShearStressPerturbRSF3DTest, RadiusDecomposition)
{
  buildFunction();
  Real t = 5.0;
  // r = sqrt(1000^2 + 1000^2) = 1414.2
  Real val_xz = _func->value(t, Point(1000.0, 0.0, 1000.0));
  Real val_x = _func->value(t, Point(1414.213562, 0.0, 0.0));
  EXPECT_NEAR(val_xz, val_x, 0.01);
}

//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

/*
 * Unit tests for InitialStrikeShearStressPerturbRSF2D Function.
 *
 * T1_o = T1_perturb * F(r, R) * G(t, T)
 *
 * F(r, R) = exp(r^2 / (r^2 - R^2))  for r < R, else 0
 * G(t, T) = exp((t-T)^2 / (t*(t-2T))) for 0 < t < T, 1 for t >= T, 0 for t <= 0
 *
 * Hardcoded: T1_perturb=25e6, R=3000, T=1.0
 */

#include "MooseObjectUnitTest.h"
#include "InitialStrikeShearStressPerturbRSF2D.h"

class InitialStrikeShearStressPerturbRSF2DTest : public MooseObjectUnitTest
{
public:
  InitialStrikeShearStressPerturbRSF2DTest() : MooseObjectUnitTest("farmsquakeworxApp") {}

protected:
  void buildFunction()
  {
    InputParameters params = _factory.getValidParams("InitialStrikeShearStressPerturbRSF2D");
    params.set<FEProblem *>("_fe_problem") = _fe_problem.get();
    params.set<FEProblemBase *>("_fe_problem_base") = _fe_problem.get();
    _fe_problem->addFunction("InitialStrikeShearStressPerturbRSF2D", "test_func", params);
    _func = &_fe_problem->getFunction("test_func");
  }

  const Function * _func = nullptr;
};

// ---- Zero at time zero: G(0)=0 ----
TEST_F(InitialStrikeShearStressPerturbRSF2DTest, ZeroAtTimeZero)
{
  buildFunction();
  Real val = _func->value(0.0, Point(0.0, 0.0, 0.0));
  EXPECT_NEAR(val, 0.0, 1e-10);
}

// ---- Zero outside R: F(r>=R)=0 ----
TEST_F(InitialStrikeShearStressPerturbRSF2DTest, ZeroOutsideR)
{
  buildFunction();
  Real val = _func->value(5.0, Point(4000.0, 0.0, 0.0));
  EXPECT_NEAR(val, 0.0, 1e-10);
}

// ---- Steady state after T: G(t>=T)=1 at origin: F(0)=exp(0)=1 ----
TEST_F(InitialStrikeShearStressPerturbRSF2DTest, SteadyAfterT)
{
  buildFunction();
  // At r=0: F(0,3000) = exp(0/(0-R^2)) = exp(0) = 1
  // At t=5 >= T=1: G(5,1) = 1
  // T1_o = 25e6 * 1 * 1 = 25e6
  Real val = _func->value(5.0, Point(0.0, 0.0, 0.0));
  EXPECT_NEAR(val, 25e6, 1e-3);
}

// ---- Monotonic spatial decay: closer to origin -> larger value ----
TEST_F(InitialStrikeShearStressPerturbRSF2DTest, MonotonicSpatialDecay)
{
  buildFunction();
  Real t = 5.0;
  Real val_near = _func->value(t, Point(500.0, 0.0, 0.0));
  Real val_far = _func->value(t, Point(2000.0, 0.0, 0.0));
  EXPECT_GT(val_near, val_far);
  EXPECT_GT(val_near, 0.0);
  EXPECT_GT(val_far, 0.0);
}

// ---- Temporal ramp: increases from 0 to steady state ----
TEST_F(InitialStrikeShearStressPerturbRSF2DTest, TemporalRamp)
{
  buildFunction();
  Point origin(0.0, 0.0, 0.0);
  Real val_early = _func->value(0.1, origin);
  Real val_mid = _func->value(0.5, origin);
  Real val_late = _func->value(5.0, origin);

  EXPECT_GT(val_mid, val_early);
  EXPECT_GT(val_late, val_mid);
  EXPECT_NEAR(val_late, 25e6, 1e-3);
}

// ---- Symmetry in x: F depends on r = sqrt(x^2 + z^2) ----
TEST_F(InitialStrikeShearStressPerturbRSF2DTest, SymmetryX)
{
  buildFunction();
  Real t = 5.0;
  Real val_pos = _func->value(t, Point(1000.0, 0.0, 0.0));
  Real val_neg = _func->value(t, Point(-1000.0, 0.0, 0.0));
  EXPECT_NEAR(val_pos, val_neg, 1e-10);
}

// ---- At boundary R: F(R, R) -> 0 (from the left) ----
TEST_F(InitialStrikeShearStressPerturbRSF2DTest, AtBoundaryR)
{
  buildFunction();
  // F(r=R) = 0 (from the else branch)
  Real val = _func->value(5.0, Point(3000.0, 0.0, 0.0));
  EXPECT_NEAR(val, 0.0, 1e-10);
}

// ---- r uses x and z coordinates (2D: r = sqrt(x^2 + z^2)) ----
TEST_F(InitialStrikeShearStressPerturbRSF2DTest, RadiusUsesXZ)
{
  buildFunction();
  Real t = 5.0;
  // r = sqrt(1000^2 + 1000^2) = 1414.2
  Real val_xz = _func->value(t, Point(1000.0, 0.0, 1000.0));
  // r = sqrt(1414.2^2 + 0^2) = 1414.2
  Real val_x = _func->value(t, Point(1414.213562, 0.0, 0.0));
  EXPECT_NEAR(val_xz, val_x, 0.01);
}

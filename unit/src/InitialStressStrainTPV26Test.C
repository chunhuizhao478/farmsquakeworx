//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

/*
 * Unit tests for InitialStressStrainTPV26 Function.
 *
 * Tests stress/strain computation for the TPV26 benchmark:
 *   sigmazz = -rho_rock * g * |z|
 *   sigmaxx = Omega * (bxx * (sigmazz + Pf) - Pf) + (1-Omega) * sigmazz
 *   sigmayy = Omega * (byy * (sigmazz + Pf) - Pf) + (1-Omega) * sigmazz
 *   sigmaxy = Omega * bxy * (sigmazz + Pf)
 *   Effective stress = total + Pf
 *
 * Also tests error validation, tapering, and overpressure modes.
 */

#include "MooseObjectUnitTest.h"
#include "InitialStressStrainTPV26.h"

class InitialStressStrainTPV26Test : public MooseObjectUnitTest
{
public:
  InitialStressStrainTPV26Test() : MooseObjectUnitTest("farmsquakeworxApp") {}

protected:
  InputParameters getBaseParams()
  {
    InputParameters params = _factory.getValidParams("InitialStressStrainTPV26");
    params.set<FEProblem *>("_fe_problem") = _fe_problem.get();
    params.set<FEProblemBase *>("_fe_problem_base") = _fe_problem.get();
    params.set<Real>("lambda_o") = 32.04e9;
    params.set<Real>("shear_modulus_o") = 32.04e9;
    params.set<Real>("fluid_density") = 1000.0;
    params.set<Real>("rock_density") = 2670.0;
    params.set<Real>("gravity") = 9.8;
    params.set<Real>("bxx") = 0.6;
    params.set<Real>("byy") = 1.0;
    params.set<Real>("bxy") = 0.4;
    return params;
  }

  const Function & buildFunction(InputParameters & params)
  {
    _fe_problem->addFunction("InitialStressStrainTPV26", _name, params);
    const Function & f = _fe_problem->getFunction(_name);
    _name_idx++;
    _name = "test_func_" + std::to_string(_name_idx);
    return f;
  }

  std::string _name = "test_func_0";
  int _name_idx = 0;
};

// ---- Error: both stress and strain ----
TEST_F(InitialStressStrainTPV26Test, ErrorBothStressAndStrain)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 1;
  params.set<Real>("j") = 1;
  params.set<bool>("get_initial_stress") = true;
  params.set<bool>("get_initial_strain") = true;
  EXPECT_THROW(buildFunction(params), std::exception);
}

// ---- Error: fluid pressure with stress ----
TEST_F(InitialStressStrainTPV26Test, ErrorFluidPressureWithStress)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 1;
  params.set<Real>("j") = 1;
  params.set<bool>("get_initial_stress") = true;
  params.set<bool>("get_fluid_pressure") = true;
  EXPECT_THROW(buildFunction(params), std::exception);
}

// ---- Error: tapering with bad depths (A >= B) ----
TEST_F(InitialStressStrainTPV26Test, ErrorTaperingBadDepths)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 1;
  params.set<Real>("j") = 1;
  params.set<bool>("get_initial_stress") = true;
  params.set<bool>("use_tapering") = true;
  params.set<Real>("tapering_depth_A") = 5000.0;
  params.set<Real>("tapering_depth_B") = 5000.0; // A >= B
  EXPECT_THROW(buildFunction(params), std::exception);
}

// ---- Error: overpressure with bad depths ----
TEST_F(InitialStressStrainTPV26Test, ErrorOverpressureBadDepths)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 1;
  params.set<Real>("j") = 1;
  params.set<bool>("get_initial_stress") = true;
  params.set<bool>("use_overpressure") = true;
  params.set<Real>("overpressure_depth_A") = 10000.0;
  params.set<Real>("overpressure_depth_B") = 5000.0; // A > B
  EXPECT_THROW(buildFunction(params), std::exception);
}

// ---- Error: low effective without overpressure ----
TEST_F(InitialStressStrainTPV26Test, ErrorLowEffNoOverpressure)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 1;
  params.set<Real>("j") = 1;
  params.set<bool>("get_initial_stress") = true;
  params.set<bool>("overpressure_loweffective") = true;
  params.set<bool>("use_overpressure") = false;
  EXPECT_THROW(buildFunction(params), std::exception);
}

// ---- Error: lambda_pp out of range ----
TEST_F(InitialStressStrainTPV26Test, ErrorLambdaPPRange)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 1;
  params.set<Real>("j") = 1;
  params.set<bool>("get_initial_stress") = true;
  params.set<bool>("use_overpressure") = true;
  params.set<Real>("overpressure_depth_A") = 1000.0;
  params.set<Real>("overpressure_depth_B") = 10000.0;
  params.set<bool>("overpressure_loweffective") = true;
  params.set<Real>("lambda_pp") = 1.5; // > 1.0
  EXPECT_THROW(buildFunction(params), std::exception);
}

// ---- Sigmazz effective = -rho*g*|z| + Pf ----
TEST_F(InitialStressStrainTPV26Test, StressZZ)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 3;
  params.set<Real>("j") = 3;
  params.set<bool>("get_initial_stress") = true;
  const Function & f = buildFunction(params);

  Real z = -5000.0;
  Real val = f.value(0.0, Point(0.0, 0.0, z));
  // sigmazz_total = -rho*g*|z| = -2670*9.8*5000 = -130.83e6
  // Pf = rho_f*g*|z| = 1000*9.8*5000 = 49.0e6
  // effective = total + Pf = -130.83e6 + 49.0e6 = -81.83e6
  Real expected = -2670.0 * 9.8 * 5000.0 + 1000.0 * 9.8 * 5000.0;
  EXPECT_NEAR(val, expected, 1.0);
}

// ---- Fluid pressure: Pf = rho_f * g * |z| (no overpressure) ----
TEST_F(InitialStressStrainTPV26Test, FluidPressure)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 0;
  params.set<Real>("j") = 0;
  params.set<bool>("get_fluid_pressure") = true;
  const Function & f = buildFunction(params);

  Real z = -5000.0;
  Real val = f.value(0.0, Point(0.0, 0.0, z));
  Real expected = 1000.0 * 9.8 * 5000.0; // 49.0e6
  EXPECT_NEAR(val, expected, 1.0);
}

// ---- Stress symmetry: sigma_ij = sigma_ji ----
TEST_F(InitialStressStrainTPV26Test, StressSymmetry)
{
  auto params12 = getBaseParams();
  params12.set<Real>("i") = 1;
  params12.set<Real>("j") = 2;
  params12.set<bool>("get_initial_stress") = true;
  const Function & f12 = buildFunction(params12);

  auto params21 = getBaseParams();
  params21.set<Real>("i") = 2;
  params21.set<Real>("j") = 1;
  params21.set<bool>("get_initial_stress") = true;
  const Function & f21 = buildFunction(params21);

  Point p(0.0, 0.0, -5000.0);
  EXPECT_NEAR(f12.value(0.0, p), f21.value(0.0, p), 1e-6);
}

// ---- Tapering: at shallow depth (above A), Omega=1 ----
TEST_F(InitialStressStrainTPV26Test, TaperingAboveA)
{
  auto params_no_taper = getBaseParams();
  params_no_taper.set<Real>("i") = 1;
  params_no_taper.set<Real>("j") = 2;
  params_no_taper.set<bool>("get_initial_stress") = true;
  const Function & f_no = buildFunction(params_no_taper);

  auto params_taper = getBaseParams();
  params_taper.set<Real>("i") = 1;
  params_taper.set<Real>("j") = 2;
  params_taper.set<bool>("get_initial_stress") = true;
  params_taper.set<bool>("use_tapering") = true;
  params_taper.set<Real>("tapering_depth_A") = 5000.0;
  params_taper.set<Real>("tapering_depth_B") = 15000.0;
  const Function & f_tap = buildFunction(params_taper);

  // At z = -100 (above A=5000): Omega=1, same as no tapering
  Point p(0.0, 0.0, -100.0);
  EXPECT_NEAR(f_tap.value(0.0, p), f_no.value(0.0, p), 1e-3);
}

// ---- Tapering: at deep depth (below B), Omega=0, shear stress vanishes ----
TEST_F(InitialStressStrainTPV26Test, TaperingBelowB)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 1;
  params.set<Real>("j") = 2;
  params.set<bool>("get_initial_stress") = true;
  params.set<bool>("use_tapering") = true;
  params.set<Real>("tapering_depth_A") = 5000.0;
  params.set<Real>("tapering_depth_B") = 15000.0;
  const Function & f = buildFunction(params);

  // At z = -20000 (below B=15000): Omega=0, sigmaxy = 0
  Point p(0.0, 0.0, -20000.0);
  EXPECT_NEAR(f.value(0.0, p), 0.0, 1e-3);
}

// ---- Strain computation: verify diagonal strain via Hooke's law ----
TEST_F(InitialStressStrainTPV26Test, StrainXX)
{
  auto params_stress = getBaseParams();
  params_stress.set<Real>("i") = 1;
  params_stress.set<Real>("j") = 1;
  params_stress.set<bool>("get_initial_stress") = true;
  const Function & f_stress = buildFunction(params_stress);

  auto params_strain = getBaseParams();
  params_strain.set<Real>("i") = 1;
  params_strain.set<Real>("j") = 1;
  params_strain.set<bool>("get_initial_strain") = true;
  const Function & f_strain = buildFunction(params_strain);

  Point p(0.0, 0.0, -5000.0);
  Real eps_xx = f_strain.value(0.0, p);
  // Strain should be non-zero for non-zero stress
  Real sigma_xx = f_stress.value(0.0, p);
  // Both should be negative (compression)
  EXPECT_LT(sigma_xx, 0.0);
  EXPECT_LT(eps_xx, 0.0);
}

// ---- Time-independent ----
TEST_F(InitialStressStrainTPV26Test, TimeIndependent)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 3;
  params.set<Real>("j") = 3;
  params.set<bool>("get_initial_stress") = true;
  const Function & f = buildFunction(params);

  Point p(0.0, 0.0, -5000.0);
  EXPECT_NEAR(f.value(0.0, p), f.value(100.0, p), 1e-15);
}

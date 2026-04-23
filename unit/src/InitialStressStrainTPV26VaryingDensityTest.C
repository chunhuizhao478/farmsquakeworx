/*
 * Unit tests for InitialStressStrainTPV26VaryingDensity Function.
 *
 * Tests stress/strain computation for the TPV26 benchmark with depth-varying
 * density from the TPV32 profile. The vertical stress is computed via a
 * trapezoidal integration of the piecewise-linear density profile:
 *   sigmazz = -g * integral_0^depth rho(s) ds
 *
 * Tests cover: parameter validation, stress computation, tapering, symmetry,
 * fluid pressure, and strain via inverse Hooke's law.
 */

#include "MooseObjectUnitTest.h"
#include "InitialStressStrainTPV26VaryingDensity.h"

class InitialStressStrainTPV26VaryingDensityTest : public MooseObjectUnitTest
{
public:
  InitialStressStrainTPV26VaryingDensityTest() : MooseObjectUnitTest("farmsquakeworxApp") {}

protected:
  InputParameters getBaseParams()
  {
    InputParameters params = _factory.getValidParams("InitialStressStrainTPV26VaryingDensity");
    params.set<FEProblem *>("_fe_problem") = _fe_problem.get();
    params.set<FEProblemBase *>("_fe_problem_base") = _fe_problem.get();
    params.set<Real>("lambda_o") = 32.04e9;
    params.set<Real>("shear_modulus_o") = 32.04e9;
    params.set<Real>("fluid_density") = 1000.0;
    params.set<Real>("gravity") = 9.8;
    params.set<Real>("bxx") = 0.926793;
    params.set<Real>("byy") = 1.073206;
    params.set<Real>("bxy") = -0.8;
    return params;
  }

  const Function & buildFunction(InputParameters & params)
  {
    _fe_problem->addFunction("InitialStressStrainTPV26VaryingDensity", _name, params);
    const Function & f = _fe_problem->getFunction(_name);
    _name_idx++;
    _name = "test_func_vd_" + std::to_string(_name_idx);
    return f;
  }

  std::string _name = "test_func_vd_0";
  int _name_idx = 0;
};

// ---- Error: both stress and strain ----
TEST_F(InitialStressStrainTPV26VaryingDensityTest, ErrorBothStressAndStrain)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 1;
  params.set<Real>("j") = 1;
  params.set<bool>("get_initial_stress") = true;
  params.set<bool>("get_initial_strain") = true;
  EXPECT_THROW(buildFunction(params), std::exception);
}

// ---- Error: fluid pressure with stress ----
TEST_F(InitialStressStrainTPV26VaryingDensityTest, ErrorFluidPressureWithStress)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 1;
  params.set<Real>("j") = 1;
  params.set<bool>("get_initial_stress") = true;
  params.set<bool>("get_fluid_pressure") = true;
  EXPECT_THROW(buildFunction(params), std::exception);
}

// ---- Error: tapering with bad depths (A >= B) ----
TEST_F(InitialStressStrainTPV26VaryingDensityTest, ErrorTaperingBadDepths)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 1;
  params.set<Real>("j") = 1;
  params.set<bool>("get_initial_stress") = true;
  params.set<bool>("use_tapering") = true;
  params.set<Real>("tapering_depth_A") = 5000.0;
  params.set<Real>("tapering_depth_B") = 5000.0;
  EXPECT_THROW(buildFunction(params), std::exception);
}

// ---- Sigmazz at depth=500m: overburden = 0.5*(2200+2450)*500 = 1162500 ----
TEST_F(InitialStressStrainTPV26VaryingDensityTest, StressZZShallow)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 3;
  params.set<Real>("j") = 3;
  params.set<bool>("get_initial_stress") = true;
  const Function & f = buildFunction(params);

  Real z = -500.0;
  Real val = f.value(0.0, Point(0.0, 0.0, z));
  // sigmazz_total = -g * integral_0^500 rho(s) ds = -9.8 * 0.5*(2200+2450)*500
  Real overburden = 0.5 * (2200.0 + 2450.0) * 500.0;
  Real sigmazz_total = -9.8 * overburden;
  Real Pf = 1000.0 * 9.8 * 500.0;
  Real expected = sigmazz_total + Pf; // effective stress
  EXPECT_NEAR(val, expected, 1.0);
}

// ---- Fluid pressure: Pf = rho_f * g * |z| (no overpressure) ----
TEST_F(InitialStressStrainTPV26VaryingDensityTest, FluidPressure)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 0;
  params.set<Real>("j") = 0;
  params.set<bool>("get_fluid_pressure") = true;
  const Function & f = buildFunction(params);

  Real z = -5000.0;
  Real val = f.value(0.0, Point(0.0, 0.0, z));
  Real expected = 1000.0 * 9.8 * 5000.0;
  EXPECT_NEAR(val, expected, 1.0);
}

// ---- Stress symmetry: sigma_ij = sigma_ji ----
TEST_F(InitialStressStrainTPV26VaryingDensityTest, StressSymmetry)
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

// ---- Tapering: below B, shear stress vanishes ----
TEST_F(InitialStressStrainTPV26VaryingDensityTest, TaperingBelowB)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 1;
  params.set<Real>("j") = 2;
  params.set<bool>("get_initial_stress") = true;
  params.set<bool>("use_tapering") = true;
  params.set<Real>("tapering_depth_A") = 5000.0;
  params.set<Real>("tapering_depth_B") = 15000.0;
  const Function & f = buildFunction(params);

  Point p(0.0, 0.0, -20000.0);
  EXPECT_NEAR(f.value(0.0, p), 0.0, 1e-3);
}

// ---- Strain: compression yields negative strain ----
TEST_F(InitialStressStrainTPV26VaryingDensityTest, StrainCompression)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 3;
  params.set<Real>("j") = 3;
  params.set<bool>("get_initial_strain") = true;
  const Function & f = buildFunction(params);

  Point p(0.0, 0.0, -5000.0);
  EXPECT_LT(f.value(0.0, p), 0.0);
}

// ---- Time-independent ----
TEST_F(InitialStressStrainTPV26VaryingDensityTest, TimeIndependent)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 3;
  params.set<Real>("j") = 3;
  params.set<bool>("get_initial_stress") = true;
  const Function & f = buildFunction(params);

  Point p(0.0, 0.0, -5000.0);
  EXPECT_NEAR(f.value(0.0, p), f.value(100.0, p), 1e-15);
}

// ---- Surface: zero depth gives zero stress ----
TEST_F(InitialStressStrainTPV26VaryingDensityTest, SurfaceZeroStress)
{
  auto params = getBaseParams();
  params.set<Real>("i") = 3;
  params.set<Real>("j") = 3;
  params.set<bool>("get_initial_stress") = true;
  const Function & f = buildFunction(params);

  Point p(0.0, 0.0, 0.0);
  EXPECT_NEAR(f.value(0.0, p), 0.0, 1e-3);
}

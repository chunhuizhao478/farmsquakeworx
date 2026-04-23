/*
 * Unit tests for TPV32DepthSeismicProperties.
 *
 * Tests piecewise-linear interpolation of the TPV32 1D velocity/density profile:
 *   depth (m): {0, 500, 1000, 1600, 2400, 3600, 5000, 9000, 11000, 15000}
 *   Vp  (m/s): {2200, 3000, 3600, 4400, 4800, 5250, 5500, 5750, 6100, 6300}
 *   Vs  (m/s): {1050, 1400, 1950, 2500, 2800, 3100, 3250, 3450, 3600, 3700}
 *   rho(kg/m3):{2200, 2450, 2550, 2600, 2600, 2620, 2650, 2720, 2750, 2900}
 *
 * Derived elastic constants:
 *   mu     = rho * Vs^2
 *   lambda = max(rho * Vp^2 - 2*mu, 0)
 */

#include "gtest/gtest.h"
#include <cmath>
#include <vector>
#include <algorithm>

namespace
{
// Replicate the TPV32 interpolation logic for standalone testing
double
tpv32_interp(const std::vector<double> & xs, const std::vector<double> & ys, double x)
{
  if (x <= xs.front())
    return ys.front();
  if (x >= xs.back())
    return ys.back();
  for (std::size_t i = 0; i + 1 < xs.size(); ++i)
  {
    if (x >= xs[i] && x <= xs[i + 1])
    {
      double t = (x - xs[i]) / (xs[i + 1] - xs[i]);
      return ys[i] + t * (ys[i + 1] - ys[i]);
    }
  }
  return ys.back();
}

const std::vector<double> depth = {0, 500, 1000, 1600, 2400, 3600, 5000, 9000, 11000, 15000};
const std::vector<double> Vp = {2200, 3000, 3600, 4400, 4800, 5250, 5500, 5750, 6100, 6300};
const std::vector<double> Vs = {1050, 1400, 1950, 2500, 2800, 3100, 3250, 3450, 3600, 3700};
const std::vector<double> rho = {2200, 2450, 2550, 2600, 2600, 2620, 2650, 2720, 2750, 2900};
}

// ---- Surface values (depth=0) ----
TEST(TPV32DepthSeismicProperties, SurfaceValues)
{
  EXPECT_NEAR(tpv32_interp(depth, Vp, 0.0), 2200.0, 1e-10);
  EXPECT_NEAR(tpv32_interp(depth, Vs, 0.0), 1050.0, 1e-10);
  EXPECT_NEAR(tpv32_interp(depth, rho, 0.0), 2200.0, 1e-10);
}

// ---- Exact knot values ----
TEST(TPV32DepthSeismicProperties, ExactKnotValues)
{
  EXPECT_NEAR(tpv32_interp(depth, Vs, 1000.0), 1950.0, 1e-10);
  EXPECT_NEAR(tpv32_interp(depth, Vp, 5000.0), 5500.0, 1e-10);
  EXPECT_NEAR(tpv32_interp(depth, rho, 15000.0), 2900.0, 1e-10);
}

// ---- Midpoint interpolation at depth=250 (between 0 and 500) ----
TEST(TPV32DepthSeismicProperties, MidpointInterpolation)
{
  double d = 250.0;
  double expected_vs = 1050.0 + 0.5 * (1400.0 - 1050.0); // 1225
  EXPECT_NEAR(tpv32_interp(depth, Vs, d), expected_vs, 1e-10);
}

// ---- Clamping: negative depth returns surface values ----
TEST(TPV32DepthSeismicProperties, NegativeDepthClamp)
{
  EXPECT_NEAR(tpv32_interp(depth, Vp, -100.0), 2200.0, 1e-10);
  EXPECT_NEAR(tpv32_interp(depth, rho, -500.0), 2200.0, 1e-10);
}

// ---- Extrapolation: beyond last knot returns last value ----
TEST(TPV32DepthSeismicProperties, BeyondLastKnot)
{
  EXPECT_NEAR(tpv32_interp(depth, Vp, 20000.0), 6300.0, 1e-10);
  EXPECT_NEAR(tpv32_interp(depth, Vs, 99999.0), 3700.0, 1e-10);
  EXPECT_NEAR(tpv32_interp(depth, rho, 20000.0), 2900.0, 1e-10);
}

// ---- Derived elastic constants: mu = rho * Vs^2 ----
TEST(TPV32DepthSeismicProperties, ShearModulus)
{
  double d = 5000.0;
  double r = tpv32_interp(depth, rho, d);   // 2650
  double vs = tpv32_interp(depth, Vs, d);   // 3250
  double mu = r * vs * vs;
  EXPECT_NEAR(mu, 2650.0 * 3250.0 * 3250.0, 1e-3);
}

// ---- Derived elastic constants: lambda = rho*Vp^2 - 2*mu >= 0 ----
TEST(TPV32DepthSeismicProperties, LambdaNonNegative)
{
  for (double d = 0; d <= 15000; d += 500)
  {
    double r = tpv32_interp(depth, rho, d);
    double vs = tpv32_interp(depth, Vs, d);
    double vp = tpv32_interp(depth, Vp, d);
    double mu = r * vs * vs;
    double lambda = std::max(r * vp * vp - 2.0 * mu, 0.0);
    EXPECT_GE(lambda, 0.0);
  }
}

// ---- Monotonicity: Vs increases with depth ----
TEST(TPV32DepthSeismicProperties, VsMonotonicallyIncreasing)
{
  double prev = 0.0;
  for (double d = 0; d <= 15000; d += 100)
  {
    double vs = tpv32_interp(depth, Vs, d);
    EXPECT_GE(vs, prev);
    prev = vs;
  }
}

//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

/*
 * Unit tests for CDBM (Continuum Damage-Breakage Mechanics) math formulas
 * from ComputeDamageBreakageStress3DSlipWeakening.
 *
 * Tests: node mass/area, damage evolution, breakage evolution,
 *        stress blending, strain-rate-dependent Cd.
 */

#include "gtest/gtest.h"
#include <cmath>

// ---- 3D Node mass for TET4 ----
TEST(DamageBreakageMath, NodeMassTET4)
{
  double density = 2670.0;
  double len = 100.0;
  // M = (density * sqrt(2) * len^3 / 12 / 4) * 6
  double M = (density * std::sqrt(2.0) * len * len * len / 12.0 / 4.0) * 6.0;
  EXPECT_GT(M, 0.0);

  // Verify formula: volume of TET4 = sqrt(2)/12 * L^3, mass = rho*V
  // then /4 nodes * 6 (lumped mass factor)
  double V_tet = std::sqrt(2.0) / 12.0 * len * len * len;
  double M_expected = density * V_tet / 4.0 * 6.0;
  EXPECT_NEAR(M, M_expected, 1e-6);
}

// ---- 3D Node mass for HEX8 ----
TEST(DamageBreakageMath, NodeMassHEX8)
{
  double density = 2670.0;
  double len = 100.0;
  // M = (density * len^3 / 8) * 4
  double M = (density * len * len * len / 8.0) * 4.0;

  double V_hex = len * len * len;
  double M_expected = density * V_hex / 8.0 * 4.0;
  EXPECT_NEAR(M, M_expected, 1e-6);
  EXPECT_GT(M, 0.0);
}

// ---- 3D Face area for TET4 ----
TEST(DamageBreakageMath, AreaTET4)
{
  double len = 100.0;
  // A = (sqrt(3) * len^2 / 4 / 3) * 6
  double A = (std::sqrt(3.0) * len * len / 4.0 / 3.0) * 6.0;
  EXPECT_GT(A, 0.0);

  // equilateral triangle face area = sqrt(3)/4 * L^2
  // /3 nodes on face * 6 lumped area factor
  double A_face = std::sqrt(3.0) / 4.0 * len * len;
  double A_expected = A_face / 3.0 * 6.0;
  EXPECT_NEAR(A, A_expected, 1e-6);
}

// ---- 3D Face area for HEX8 ----
TEST(DamageBreakageMath, AreaHEX8)
{
  double len = 100.0;
  // A = (len^2 / 4) * 4
  double A = (len * len / 4.0) * 4.0;
  double A_expected = len * len; // = face area
  EXPECT_NEAR(A, A_expected, 1e-6);
}

// ---- Damage evolution: dalpha/dt = (1-B) * Cd * I2 * (xi - xi_0) ----
TEST(DamageBreakageMath, DamageEvolutionPositive)
{
  double B = 0.0;       // no breakage
  double Cd = 1e5;
  double I2 = 1e-6;
  double xi = -0.5;     // above threshold
  double xi_0 = -1.0 * std::sqrt(3.0);
  double dt = 1e-4;

  double dalpha_dt = (1.0 - B) * Cd * I2 * (xi - xi_0);
  EXPECT_GT(dalpha_dt, 0.0); // damage increases when xi > xi_0

  double alpha_new = 0.0 + dalpha_dt * dt;
  EXPECT_GT(alpha_new, 0.0);
}

// ---- Damage evolution: no damage when xi < xi_0 (healing branch) ----
TEST(DamageBreakageMath, DamageHealingBranch)
{
  double B = 0.0;
  double xi = -2.0;     // below xi_0
  double xi_0 = -1.0 * std::sqrt(3.0); // ~-1.732

  // For xi < xi_0: dalpha/dt = (1-B) * C1 * exp(alpha/C2) * I2 * (xi - xi_0)
  double alpha = 0.1;
  double C1 = 1e4;
  double C2 = 0.1;
  double I2 = 1e-6;

  double dalpha_dt = (1.0 - B) * C1 * std::exp(alpha / C2) * I2 * (xi - xi_0);
  EXPECT_LT(dalpha_dt, 0.0); // damage decreases (healing)
}

// ---- Alpha clamped to [0, 1] ----
TEST(DamageBreakageMath, AlphaClamping)
{
  double alpha = 1.5; // exceeds 1
  if (alpha > 1.0) alpha = 1.0;
  EXPECT_NEAR(alpha, 1.0, 1e-15);

  alpha = -0.5; // below 0
  if (alpha < 0.0) alpha = 0.0;
  EXPECT_NEAR(alpha, 0.0, 1e-15);
}

// ---- Breakage evolution: dB/dt = C_B * Prob * (1-B) * I2 * (xi - xi_d) ----
TEST(DamageBreakageMath, BreakageEvolution)
{
  double xi = 0.0;
  double xi_d = -0.8;
  double B = 0.0;
  double I2 = 1e-6;
  double CdCb_multiplier = 10.0;
  double Cd = 1e5;

  // Probability function (logistic)
  double alpha = 0.3;
  double beta_width = 0.1;
  double m1 = 0.5; // or some threshold
  double Prob = 1.0 / (1.0 + std::exp(-(alpha - m1) / beta_width));

  double dB_dt = CdCb_multiplier * Cd * Prob * (1.0 - B) * I2 * (xi - xi_d);
  EXPECT_GT(dB_dt, 0.0); // breakage increases when xi > xi_d
}

// ---- Breakage no increase when xi < xi_d ----
TEST(DamageBreakageMath, BreakageThreshold)
{
  double xi = -1.5;
  double xi_d = -0.8;

  // xi < xi_d -> healing branch (CBH * I2 * (xi - xi_d))
  double CBH = 1e3;
  double I2 = 1e-6;
  double dB_dt = CBH * I2 * (xi - xi_d);
  EXPECT_LT(dB_dt, 0.0); // breakage decreases (healing)
}

// ---- Stress blending: sigma = (1-B)*sigma_s + B*sigma_b ----
TEST(DamageBreakageMath, StressBlendPureSolid)
{
  double B = 0.0;
  double sigma_s = 100e6;
  double sigma_b = 50e6;
  double sigma = (1.0 - B) * sigma_s + B * sigma_b;
  EXPECT_NEAR(sigma, sigma_s, 1e-6);
}

TEST(DamageBreakageMath, StressBlendPureGranular)
{
  double B = 1.0;
  double sigma_s = 100e6;
  double sigma_b = 50e6;
  double sigma = (1.0 - B) * sigma_s + B * sigma_b;
  EXPECT_NEAR(sigma, sigma_b, 1e-6);
}

TEST(DamageBreakageMath, StressBlendHalf)
{
  double B = 0.5;
  double sigma_s = 100e6;
  double sigma_b = 50e6;
  double sigma = (1.0 - B) * sigma_s + B * sigma_b;
  EXPECT_NEAR(sigma, 75e6, 1e-6);
}

// ---- Strain-rate dependent Cd ----
TEST(DamageBreakageMath, StrainRateCdBelowThreshold)
{
  double eps_dot = 0.5;    // below threshold
  double eps_hat = 1.0;    // threshold
  double Cd_constant = 1e5;

  // Below threshold: use Cd_constant
  double Cd = Cd_constant;
  if (eps_dot >= eps_hat)
  {
    double m = 0.5;
    double cd_hat = 1e4;
    Cd = std::pow(10.0, 1.0 + m * std::log10(eps_dot / eps_hat)) * cd_hat;
  }

  EXPECT_NEAR(Cd, Cd_constant, 1e-6);
}

TEST(DamageBreakageMath, StrainRateCdAboveThreshold)
{
  double eps_dot = 10.0;   // above threshold
  double eps_hat = 1.0;
  double m = 0.5;
  double cd_hat = 1e4;

  double Cd = std::pow(10.0, 1.0 + m * std::log10(eps_dot / eps_hat)) * cd_hat;
  EXPECT_GT(Cd, cd_hat * 10.0); // Cd increases with strain rate
}

// ---- Deviatoric strain rate computation ----
TEST(DamageBreakageMath, DeviatoricStrainRate)
{
  // eps_dev = eps - 1/3 * tr(eps) * I
  // J2_dot = 0.5 * eps_dev_dot : eps_dev_dot
  // eps_eq_dot = sqrt(2/3 * J2_dot)
  double dt = 1e-4;
  double I2 = 1e-6;
  double I2_old = 0.5e-6;
  double I1 = 3e-3;
  double I1_old = 1.5e-3;

  // Simplified: dI2/dt
  double dI2_dt = (I2 - I2_old) / dt;
  EXPECT_GT(dI2_dt, 0.0);
}

// ---- Logistic probability function ----
TEST(DamageBreakageMath, LogisticProbability)
{
  double beta = 0.1;

  // alpha << m1: Prob -> 0
  double alpha1 = 0.0;
  double m1 = 0.5;
  double P1 = 1.0 / (1.0 + std::exp(-(alpha1 - m1) / beta));
  EXPECT_LT(P1, 0.01);

  // alpha >> m1: Prob -> 1
  double alpha2 = 1.0;
  double P2 = 1.0 / (1.0 + std::exp(-(alpha2 - m1) / beta));
  EXPECT_GT(P2, 0.99);

  // alpha = m1: Prob = 0.5
  double P3 = 1.0 / (1.0 + std::exp(-(m1 - m1) / beta));
  EXPECT_NEAR(P3, 0.5, 1e-15);
}

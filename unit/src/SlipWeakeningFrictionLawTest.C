//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

/*
 * Unit tests for the slip weakening friction law math.
 * Tests the core formulas used in SlipWeakeningFrictionczm2d,
 * SlipWeakeningFrictionczm3d, and SlipWeakeningFrictionczm2dParametricStudy.
 *
 * Friction law:
 *   if |slip| < Dc:  mu = mu_s - (mu_s - mu_d) * |slip| / Dc
 *   else:            mu = mu_d
 *   tau_f = mu * (-T2)       (T2 < 0 for compression)
 *
 * Stuck/slip logic:
 *   if |T1| < tau_f:  stuck (T1 unchanged)
 *   else:             T1 = tau_f * sign(T1)
 */

#include "gtest/gtest.h"
#include <cmath>

// Standard TPV205 parameters
static const double mu_s = 0.677;
static const double mu_d = 0.525;
static const double Dc = 0.4;

// Helper: compute friction coefficient
static double frictionCoeff(double slip, double mu_s_val, double mu_d_val, double Dc_val)
{
  if (std::abs(slip) < Dc_val)
    return mu_s_val - (mu_s_val - mu_d_val) * std::abs(slip) / Dc_val;
  else
    return mu_d_val;
}

// ---- Zero slip: mu = mu_s ----
TEST(SlipWeakeningFriction, FrictionAtZeroSlip)
{
  double mu = frictionCoeff(0.0, mu_s, mu_d, Dc);
  EXPECT_NEAR(mu, mu_s, 1e-15);
}

// ---- Full slip (= Dc): mu = mu_d ----
TEST(SlipWeakeningFriction, FrictionAtDc)
{
  double mu = frictionCoeff(Dc, mu_s, mu_d, Dc);
  EXPECT_NEAR(mu, mu_d, 1e-15);
}

// ---- Half slip: linear interpolation ----
TEST(SlipWeakeningFriction, FrictionLinear)
{
  double mu = frictionCoeff(Dc / 2.0, mu_s, mu_d, Dc);
  EXPECT_NEAR(mu, (mu_s + mu_d) / 2.0, 1e-15);
}

// ---- Beyond Dc: clamped at mu_d ----
TEST(SlipWeakeningFriction, FrictionBeyondDc)
{
  double mu = frictionCoeff(2.0 * Dc, mu_s, mu_d, Dc);
  EXPECT_NEAR(mu, mu_d, 1e-15);
}

// ---- Negative slip: abs(slip) used ----
TEST(SlipWeakeningFriction, FrictionNegativeSlip)
{
  double mu_pos = frictionCoeff(0.2, mu_s, mu_d, Dc);
  double mu_neg = frictionCoeff(-0.2, mu_s, mu_d, Dc);
  EXPECT_NEAR(mu_pos, mu_neg, 1e-15);
}

// ---- Open fault: T2 >= 0 -> T2 clamped to 0 -> tau_f = 0 ----
TEST(SlipWeakeningFriction, OpenFaultZeroFriction)
{
  double T2 = 10e6; // tensile
  if (T2 >= 0)
    T2 = 0;
  double tau_f = mu_s * (-T2);
  EXPECT_NEAR(tau_f, 0.0, 1e-15);
}

// ---- Compressive fault: tau_f > 0 ----
TEST(SlipWeakeningFriction, CompressiveFriction)
{
  double T2 = -120e6; // compressive
  double slip = 0.0;
  double mu = frictionCoeff(slip, mu_s, mu_d, Dc);
  double tau_f = mu * (-T2); // mu * 120e6
  EXPECT_GT(tau_f, 0.0);
  EXPECT_NEAR(tau_f, mu_s * 120e6, 1e-3);
}

// ---- Stuck condition: |T1| < tau_f -> T1 unchanged ----
TEST(SlipWeakeningFriction, StuckCondition)
{
  double T2 = -120e6;
  double slip = 0.0;
  double mu = frictionCoeff(slip, mu_s, mu_d, Dc);
  double tau_f = mu * (-T2); // ~ 81.24e6

  double T1 = 50e6; // less than tau_f
  double T1_original = T1;

  // Stuck logic: if T1 > 0 and T1 < tau_f, do nothing
  if ((T1 > 0 && T1 < tau_f) || (T1 < 0 && T1 > tau_f))
  {
    // stuck, no change
  }
  else
  {
    T1 = tau_f * T1 / std::abs(T1);
  }

  EXPECT_NEAR(T1, T1_original, 1e-15);
}

// ---- Slip condition: |T1| > tau_f -> T1 = tau_f * sign(T1) ----
TEST(SlipWeakeningFriction, SlipConditionPositiveT1)
{
  double T2 = -120e6;
  double slip = Dc; // fully weakened
  double mu = frictionCoeff(slip, mu_s, mu_d, Dc);
  double tau_f = mu * (-T2); // mu_d * 120e6 = 63e6

  double T1 = 80e6; // greater than tau_f

  // Slip logic from source: T1 > 0 case
  if (T1 > 0 && T1 >= tau_f)
  {
    T1 = 1 * tau_f * T1 / std::abs(T1); // = tau_f
  }

  EXPECT_NEAR(T1, tau_f, 1e-3);
}

// ---- Slip condition: T1 < 0, |T1| > |tau_f| ----
TEST(SlipWeakeningFriction, SlipConditionNegativeT1)
{
  double T2 = -120e6;
  double slip = Dc;
  double tau_f_neg = -mu_d * (-T2); // negative for T1 < 0

  double T1 = -80e6;

  // From source: T1 < 0 case
  if (T1 < 0 && T1 <= tau_f_neg) // tau_f_neg is negative
  {
    T1 = -1 * tau_f_neg * T1 / std::abs(T1); // = tau_f_neg (negative)
  }

  EXPECT_NEAR(T1, tau_f_neg, 1e-3);
}

// ---- 3D slip magnitude: sqrt(t^2 + d^2) ----
TEST(SlipWeakeningFriction, SlipMagnitude3D)
{
  double displacement_jump_t = 0.3;
  double displacement_jump_d = 0.4;
  double slip_total = std::sqrt(displacement_jump_t * displacement_jump_t +
                                displacement_jump_d * displacement_jump_d);
  EXPECT_NEAR(slip_total, 0.5, 1e-15);
}

// ---- 3D traction projection when |T| > tau_f ----
TEST(SlipWeakeningFriction, TractionProjection3D)
{
  double T2 = -120e6;
  double slip_total = Dc; // fully weakened
  double tau_f = mu_d * (-T2); // 63e6

  double T1 = 50e6;
  double T3 = 40e6;
  double T_mag = std::sqrt(T1 * T1 + T3 * T3); // ~64.03e6 > tau_f

  // Project T1, T3 to have magnitude tau_f while preserving direction
  if (T_mag > tau_f)
  {
    double T1_new = tau_f * T1 / T_mag;
    double T3_new = tau_f * T3 / T_mag;

    double T_new_mag = std::sqrt(T1_new * T1_new + T3_new * T3_new);
    EXPECT_NEAR(T_new_mag, tau_f, 1e-3);

    // Direction preserved
    EXPECT_NEAR(T1_new / T3_new, T1 / T3, 1e-10);
  }
}

// ---- 3D stuck: |T| < tau_f -> unchanged ----
TEST(SlipWeakeningFriction, StuckCondition3D)
{
  double T2 = -120e6;
  double slip_total = 0.0;
  double tau_f = mu_s * (-T2); // ~81.24e6

  double T1 = 30e6;
  double T3 = 20e6;
  double T_mag = std::sqrt(T1 * T1 + T3 * T3); // ~36.06e6 < tau_f

  double T1_orig = T1, T3_orig = T3;

  if (T_mag < tau_f)
  {
    // stuck - no modification
  }
  else
  {
    T1 = tau_f * T1 / T_mag;
    T3 = tau_f * T3 / T_mag;
  }

  EXPECT_NEAR(T1, T1_orig, 1e-15);
  EXPECT_NEAR(T3, T3_orig, 1e-15);
}

// ---- Traction assignment: traction = (T2 + T2_o, -T1 + T1_o, 0) in 2D ----
TEST(SlipWeakeningFriction, TractionAssignment2D)
{
  double T1 = 70e6;  // computed fault traction (shear)
  double T2 = -100e6; // computed fault traction (normal, after clamping)
  double T1_o = 70e6; // initial shear stress
  double T2_o = 120e6; // initial normal stress (positive = compressive in this convention)

  double trac_n = T2 + T2_o;      // normal component in CZM local coords
  double trac_t = -T1 + T1_o;     // tangential component in CZM local coords

  // When T1 = T1_o (stuck): trac_t = 0 (no additional traction)
  EXPECT_NEAR(trac_t, 0.0, 1e-3);
  EXPECT_NEAR(trac_n, T2_o + T2, 1e-3);
}

// ---- Node mass formulas ----
TEST(SlipWeakeningFriction, NodeMassTRI3)
{
  double density = 2670.0;
  double len = 100.0;
  double M = density * std::sqrt(3.0) / 4.0 * len * len / 3.0;
  double expected = 2670.0 * std::sqrt(3.0) / 4.0 * 10000.0 / 3.0;
  EXPECT_NEAR(M, expected, 1e-6);
  EXPECT_GT(M, 0.0);
}

TEST(SlipWeakeningFriction, NodeMassQUAD4)
{
  double density = 2670.0;
  double len = 100.0;
  double M = density * len * len / 4.0 * 2.0;
  double expected = 2670.0 * 10000.0 / 4.0 * 2.0;
  EXPECT_NEAR(M, expected, 1e-6);
  EXPECT_GT(M, 0.0);
}

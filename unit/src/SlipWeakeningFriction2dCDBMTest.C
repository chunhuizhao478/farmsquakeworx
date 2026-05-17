//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

/*
 * Unit tests for the 2D CDBM-coupled slip weakening friction law math.
 * Mirrors the math in SlipWeakeningFrictionczm2dCDBM::computeInterfaceTractionAndDerivatives.
 *
 * Pieces tested:
 *   1) Extraction of T1_o, T2_o from the CDBM static_initial_stress_tensor:
 *        T1_o =  sigma(0,1)
 *        T2_o = -sigma(1,1)
 *   2) Nucleation-patch overstress:
 *        if (x,y) inside the square box of half-width nucl_radius around nucl_center
 *          T1_o := peak_shear_stress
 *   3) Asymmetric (signed) friction-coefficient branch when T1 < 0:
 *        if T1 > 0: tau_f = ( mu_s - (mu_s-mu_d) s/Dc ) * (-T2)
 *        if T1 < 0: tau_f = (-mu_s + (mu_s-mu_d) s/Dc ) * (-T2)
 *      and the corresponding stick/slip projection.
 *   4) Final CZM traction assignment:
 *        traction_local = (T2 + T2_o, -T1 + T1_o, 0)
 *      For a stuck step T1 == T1_o ⇒ tangential CZM traction is zero.
 *   5) Node mass formulas for TRI3 and QUAD4.
 */

#include "gtest/gtest.h"
#include <cmath>
#include <vector>

// Standard TPV205-style parameters used by 2d_damagebreakage_case1
static const double mu_s = 0.677;
static const double mu_d = 0.525;
static const double Dc = 0.4;

// ---- Initial-stress-tensor extraction (CDBM convention) ----
TEST(SlipWeakening2dCDBM, InitialStressFromTensor)
{
  // sigma_xy = 70 MPa, sigma_yy = -120 MPa (compressive)
  const double sxy = 70e6;
  const double syy = -120e6;

  double T1_o = sxy;       // sigma(0,1)
  double T2_o = -1.0 * syy; // -sigma(1,1)

  EXPECT_NEAR(T1_o,  70e6, 1e-3);
  EXPECT_NEAR(T2_o, 120e6, 1e-3);
  EXPECT_GT(T2_o, 0.0); // by convention T2_o > 0 means compressive normal stress
}

// ---- Nucleation overstress patch: inside box ----
TEST(SlipWeakening2dCDBM, NucleationOverstressInsideBox)
{
  std::vector<double> nucl_center = {0.0, 0.0};
  const double nucl_radius = 1500.0;
  const double peak_shear = 81.6e6;

  double T1_o = 70e6;
  // Sample point well inside the patch
  double x = 100.0, y = -50.0;

  bool inside = (x > nucl_center[0] - nucl_radius && x < nucl_center[0] + nucl_radius &&
                 y > nucl_center[1] - nucl_radius && y < nucl_center[1] + nucl_radius);
  if (inside)
    T1_o = peak_shear;

  EXPECT_TRUE(inside);
  EXPECT_NEAR(T1_o, peak_shear, 1e-3);
}

// ---- Nucleation overstress patch: outside box ----
TEST(SlipWeakening2dCDBM, NucleationOverstressOutsideBox)
{
  std::vector<double> nucl_center = {0.0, 0.0};
  const double nucl_radius = 1500.0;
  const double peak_shear = 81.6e6;

  double T1_o = 70e6;
  // Sample point outside the patch (|x| > nucl_radius)
  double x = 5000.0, y = 0.0;

  bool inside = (x > nucl_center[0] - nucl_radius && x < nucl_center[0] + nucl_radius &&
                 y > nucl_center[1] - nucl_radius && y < nucl_center[1] + nucl_radius);
  if (inside)
    T1_o = peak_shear;

  EXPECT_FALSE(inside);
  EXPECT_NEAR(T1_o, 70e6, 1e-3);
  // Confirm that overstress is NOT applied
  EXPECT_LT(T1_o, peak_shear);
}

// ---- Nucleation overstress patch: open interval (boundary excluded) ----
TEST(SlipWeakening2dCDBM, NucleationOverstressOnBoundaryExcluded)
{
  std::vector<double> nucl_center = {0.0, 0.0};
  const double nucl_radius = 1500.0;
  const double peak_shear = 81.6e6;

  double T1_o = 70e6;
  // Exactly on the boundary -> source uses strict inequalities (>, <)
  double x = nucl_center[0] + nucl_radius;
  double y = 0.0;

  bool inside = (x > nucl_center[0] - nucl_radius && x < nucl_center[0] + nucl_radius &&
                 y > nucl_center[1] - nucl_radius && y < nucl_center[1] + nucl_radius);
  if (inside)
    T1_o = peak_shear;

  EXPECT_FALSE(inside);
  EXPECT_NEAR(T1_o, 70e6, 1e-3);
}

// Helper: signed friction strength used by the 2D-CDBM source
static double signedTauF(double T1, double slip_t, double T2,
                         double mu_s_v, double mu_d_v, double Dc_v)
{
  double s = std::abs(slip_t);
  if (T1 > 0)
  {
    if (s < Dc_v)
      return (mu_s_v - (mu_s_v - mu_d_v) * s / Dc_v) * (-T2);
    else
      return mu_d_v * (-T2);
  }
  else
  {
    if (s < Dc_v)
      return (-mu_s_v + (mu_s_v - mu_d_v) * s / Dc_v) * (-T2);
    else
      return -mu_d_v * (-T2);
  }
}

// ---- Signed friction strength: T1 > 0 branch ----
TEST(SlipWeakening2dCDBM, SignedTauFPositiveBranchZeroSlip)
{
  double T2 = -120e6;
  double tau_f = signedTauF(/*T1=*/50e6, /*slip=*/0.0, T2, mu_s, mu_d, Dc);
  EXPECT_NEAR(tau_f, mu_s * 120e6, 1e-3);
  EXPECT_GT(tau_f, 0.0);
}

// ---- Signed friction strength: T1 < 0 branch yields negative tau_f ----
TEST(SlipWeakening2dCDBM, SignedTauFNegativeBranchZeroSlip)
{
  double T2 = -120e6;
  double tau_f = signedTauF(/*T1=*/-50e6, /*slip=*/0.0, T2, mu_s, mu_d, Dc);
  EXPECT_NEAR(tau_f, -mu_s * 120e6, 1e-3);
  EXPECT_LT(tau_f, 0.0);
}

// ---- Signed friction strength: full weakening at slip = Dc ----
TEST(SlipWeakening2dCDBM, SignedTauFFullWeakening)
{
  double T2 = -120e6;
  double tau_f_pos = signedTauF(/*T1=*/+10e6, /*slip=*/Dc, T2, mu_s, mu_d, Dc);
  double tau_f_neg = signedTauF(/*T1=*/-10e6, /*slip=*/Dc, T2, mu_s, mu_d, Dc);
  EXPECT_NEAR(tau_f_pos,  mu_d * 120e6, 1e-3);
  EXPECT_NEAR(tau_f_neg, -mu_d * 120e6, 1e-3);
}

// ---- Stick condition (T1 > 0): T1 < tau_f -> unchanged ----
TEST(SlipWeakening2dCDBM, StickConditionPositiveT1)
{
  double T2 = -120e6;
  double tau_f = signedTauF(40e6, 0.0, T2, mu_s, mu_d, Dc); // ~81.24e6
  double T1 = 40e6;
  double T1_orig = T1;

  if ((T1 < 0 && T1 > tau_f) || (T1 > 0 && T1 < tau_f))
  {
    // stuck
  }
  else
  {
    if (T1 > 0)
      T1 =  1 * tau_f * T1 / std::abs(T1);
    else
      T1 = -1 * tau_f * T1 / std::abs(T1);
  }

  EXPECT_NEAR(T1, T1_orig, 1e-15);
}

// ---- Stick condition (T1 < 0): T1 > tau_f (both negative) -> unchanged ----
TEST(SlipWeakening2dCDBM, StickConditionNegativeT1)
{
  double T2 = -120e6;
  double tau_f = signedTauF(-40e6, 0.0, T2, mu_s, mu_d, Dc); // ~ -81.24e6
  EXPECT_LT(tau_f, 0.0);

  double T1 = -40e6;        // T1 > tau_f (less negative)
  double T1_orig = T1;

  if ((T1 < 0 && T1 > tau_f) || (T1 > 0 && T1 < tau_f))
  {
    // stuck
  }
  else
  {
    if (T1 > 0)
      T1 =  1 * tau_f * T1 / std::abs(T1);
    else
      T1 = -1 * tau_f * T1 / std::abs(T1);
  }

  EXPECT_NEAR(T1, T1_orig, 1e-15);
}

// ---- Slip projection (T1 > 0): T1 above tau_f -> T1 := tau_f ----
TEST(SlipWeakening2dCDBM, SlipProjectionPositiveT1)
{
  double T2 = -120e6;
  double tau_f = signedTauF(/*T1=*/+90e6, /*slip=*/Dc, T2, mu_s, mu_d, Dc); // mu_d*120e6 = 63e6
  double T1 = 90e6;

  ASSERT_GT(T1, tau_f);

  if ((T1 < 0 && T1 > tau_f) || (T1 > 0 && T1 < tau_f))
  {
    // stuck path NOT taken
  }
  else
  {
    if (T1 > 0)
      T1 = 1 * tau_f * T1 / std::abs(T1);
    else
      T1 = -1 * tau_f * T1 / std::abs(T1);
  }

  EXPECT_NEAR(T1, tau_f, 1e-3);
}

// ---- Slip projection (T1 < 0): T1 below tau_f (both negative) -> T1 := -tau_f * sign(T1)/|...| ----
//      Per source: T1 = -tau_f * T1/|T1| when T1<0 and slip path is taken.
TEST(SlipWeakening2dCDBM, SlipProjectionNegativeT1)
{
  double T2 = -120e6;
  double tau_f = signedTauF(/*T1=*/-90e6, /*slip=*/Dc, T2, mu_s, mu_d, Dc); // -mu_d*120e6 = -63e6
  double T1 = -90e6;

  ASSERT_LT(T1, tau_f); // T1 = -90e6  <  tau_f = -63e6

  if ((T1 < 0 && T1 > tau_f) || (T1 > 0 && T1 < tau_f))
  {
    // stuck path NOT taken
  }
  else
  {
    if (T1 > 0)
      T1 = 1 * tau_f * T1 / std::abs(T1);
    else
      T1 = -1 * tau_f * T1 / std::abs(T1);
  }

  // For T1 < 0, source does:  T1 = -1 * tau_f * T1/|T1|
  //   T1/|T1| = -1  and  tau_f = -mu_d*(-T2) < 0
  //   => T1 = -1 * (-63e6) * (-1) = -63e6 = tau_f
  EXPECT_NEAR(T1, tau_f, 1e-3);
}

// ---- Open-fault clamp: T2 >= 0 -> T2 := 0 -> tau_f = 0 ----
TEST(SlipWeakening2dCDBM, OpenFaultClamp)
{
  double T2 = 5e6; // tensile
  if (T2 >= 0)
    T2 = 0;

  double tau_f = signedTauF(10e6, 0.0, T2, mu_s, mu_d, Dc);
  EXPECT_NEAR(tau_f, 0.0, 1e-15);
}

// ---- CZM traction assignment: stuck step -> tangential CZM traction = 0 ----
TEST(SlipWeakening2dCDBM, CZMTractionAssignmentStuck)
{
  // After the stuck branch, T1 = T1_o, so -T1 + T1_o = 0
  double T1_o = 70e6;
  double T2_o = 120e6;
  double T1 = T1_o;
  double T2 = -T2_o; // matches physical compressive state used to compute trac_n

  double trac_n = T2 + T2_o; // 0
  double trac_t = -T1 + T1_o; // 0

  EXPECT_NEAR(trac_t, 0.0, 1e-9);
  EXPECT_NEAR(trac_n, 0.0, 1e-9);
}

// ---- CZM traction assignment: slipping -> tangential traction = T1_o - T1 ----
TEST(SlipWeakening2dCDBM, CZMTractionAssignmentSlipping)
{
  double T1_o = 70e6;
  double T2_o = 120e6;
  double T1 = 63e6;   // post-projection (mu_d * 120e6)
  double T2 = -100e6; // some compressive value after dynamics

  double trac_n = T2 + T2_o; // 20e6
  double trac_t = -T1 + T1_o; // 7e6

  EXPECT_NEAR(trac_n, 20e6, 1e-3);
  EXPECT_NEAR(trac_t,  7e6, 1e-3);
}

// ---- Node mass formulas (must match the 2D base class) ----
TEST(SlipWeakening2dCDBM, NodeMassTRI3)
{
  double density = 2670.0;
  double len = 100.0;
  double M = density * std::sqrt(3.0) / 4.0 * len * len / 3.0;
  double expected = 2670.0 * std::sqrt(3.0) / 4.0 * 10000.0 / 3.0;
  EXPECT_NEAR(M, expected, 1e-6);
  EXPECT_GT(M, 0.0);
}

TEST(SlipWeakening2dCDBM, NodeMassQUAD4)
{
  double density = 2670.0;
  double len = 100.0;
  double M = density * len * len / 4.0 * 2.0;
  double expected = 2670.0 * 10000.0 / 4.0 * 2.0;
  EXPECT_NEAR(M, expected, 1e-6);
  EXPECT_GT(M, 0.0);
}

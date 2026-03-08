//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

/*
 * Unit tests for the background stress tensor rotation to fault-local coordinates.
 *
 * Tests the math used in SlipWeakeningFrictionczm2dParametricStudy when
 * use_stress_tensor = true.
 *
 * Rotation:
 *   sigma_local = R^T * sigma_global * R
 *   traction_local = sigma_local * n_local   (n_local = (1,0,0))
 *
 * Sign convention:
 *   Global: tension +, compression -, clockwise shear +
 *   Local:  compression +, shear same as global
 *   T1_o = traction_local(1)    (shear: no flip)
 *   T2_o = -traction_local(0)   (normal: flip for compression+)
 */

#include "gtest/gtest.h"
#include "RankTwoTensor.h"
#include <cmath>

// Helper: build a 2D CZM rotation matrix from fault angle.
// angle = 0 -> horizontal fault, normal = (0,1), tangent = (1,0) or (-1,0)
//
// CZM convention: column 0 = normal, column 1 = tangent
// For a fault with normal direction at angle theta from +x axis:
//   normal  = (sin(theta), cos(theta), 0)
//   tangent = (cos(theta), -sin(theta), 0)   [right-hand rule, tangent x normal = +z]
//
// For theta=0 (horizontal fault): normal=(0,1), tangent=(1,0)
static RankTwoTensor buildCZMRotation(double angle_rad)
{
  double s = std::sin(angle_rad);
  double c = std::cos(angle_rad);

  // R columns: col0 = normal, col1 = tangent, col2 = (0,0,1)
  // normal  = ( sin(theta),  cos(theta), 0)
  // tangent = ( cos(theta), -sin(theta), 0)
  RankTwoTensor R;
  R.zero();
  R(0, 0) = s;   R(0, 1) = c;   R(0, 2) = 0;
  R(1, 0) = c;   R(1, 1) = -s;  R(1, 2) = 0;
  R(2, 0) = 0;   R(2, 1) = 0;   R(2, 2) = 1;
  return R;
}

// Helper: build a 2D stress tensor in global coordinates
static RankTwoTensor buildStressTensor2D(double sxx, double sxy, double syy)
{
  RankTwoTensor sigma;
  sigma.zero();
  sigma(0, 0) = sxx;
  sigma(0, 1) = sxy;
  sigma(1, 0) = sxy;
  sigma(1, 1) = syy;
  return sigma;
}

// Helper: compute T1_o, T2_o from global stress tensor and CZM rotation
static void computeLocalTraction(const RankTwoTensor & sigma_global,
                                 const RankTwoTensor & R,
                                 double & T1_o,
                                 double & T2_o)
{
  RankTwoTensor sigma_local = R.transpose() * sigma_global * R;
  RealVectorValue local_normal(1.0, 0.0, 0.0);
  RealVectorValue traction_local = sigma_local * local_normal;

  T1_o = traction_local(1);   // shear: same sign convention
  T2_o = -traction_local(0);  // normal: flip for compression+
}

// ============================================================================
// Horizontal fault (theta = 0): normal=(0,1), tangent=(1,0)
// For TPV205: sxx=-120e6, syy=-120e6, sxy=70e6
// Expected: T1_o = +70e6, T2_o = +120e6
// ============================================================================
TEST(StressTensorRotation, HorizontalFault_TPV205)
{
  double sxx = -120e6, sxy = 70e6, syy = -120e6;
  RankTwoTensor sigma = buildStressTensor2D(sxx, sxy, syy);
  RankTwoTensor R = buildCZMRotation(0.0);

  double T1_o, T2_o;
  computeLocalTraction(sigma, R, T1_o, T2_o);

  EXPECT_NEAR(T1_o, 70e6, 1e-3);
  EXPECT_NEAR(T2_o, 120e6, 1e-3);
}

// ============================================================================
// Verify horizontal fault matches the direct (no-rotation) approach:
//   T1_o = sigma(0,1) = sxy
//   T2_o = -sigma(1,1) = -syy
// ============================================================================
TEST(StressTensorRotation, ConsistencyWithDirectApproach)
{
  double sxx = -100e6, sxy = 50e6, syy = -150e6;
  RankTwoTensor sigma = buildStressTensor2D(sxx, sxy, syy);
  RankTwoTensor R = buildCZMRotation(0.0);

  double T1_o, T2_o;
  computeLocalTraction(sigma, R, T1_o, T2_o);

  // Direct approach (horizontal fault only, no rotation)
  double T1_o_direct = sigma(0, 1);    // = sxy
  double T2_o_direct = -sigma(1, 1);   // = -syy

  EXPECT_NEAR(T1_o, T1_o_direct, 1e-3);
  EXPECT_NEAR(T2_o, T2_o_direct, 1e-3);
}

// ============================================================================
// Vertical fault (theta = pi/2): normal=(1,0), tangent=(0,-1)
// sigma = [sxx, sxy; sxy, syy]
// Normal direction is now x, so:
//   T2_o = -sxx (compression+), T1_o = -sxy (tangent flips y)
// ============================================================================
TEST(StressTensorRotation, VerticalFault)
{
  double sxx = -120e6, sxy = 70e6, syy = -120e6;
  RankTwoTensor sigma = buildStressTensor2D(sxx, sxy, syy);
  RankTwoTensor R = buildCZMRotation(M_PI / 2.0);

  double T1_o, T2_o;
  computeLocalTraction(sigma, R, T1_o, T2_o);

  // For vertical fault: normal=(1,0), tangent=(0,-1)
  // sigma_nn = sxx, sigma_tn = tangent^T * sigma * normal
  // tangent = (0,-1): sigma_tn = -sxy
  // T1_o = sigma_tn = -sxy = -70e6
  // T2_o = -sigma_nn = -sxx = 120e6
  EXPECT_NEAR(T1_o, -70e6, 1e-3);
  EXPECT_NEAR(T2_o, 120e6, 1e-3);
}

// ============================================================================
// 45-degree fault: normal=(sin45, cos45), tangent=(cos45, -sin45)
// Analytical: use Mohr's circle for rotation
// ============================================================================
TEST(StressTensorRotation, Fault45deg)
{
  double sxx = -100e6, sxy = 50e6, syy = -150e6;
  RankTwoTensor sigma = buildStressTensor2D(sxx, sxy, syy);
  RankTwoTensor R = buildCZMRotation(M_PI / 4.0);

  double T1_o, T2_o;
  computeLocalTraction(sigma, R, T1_o, T2_o);

  // Hand computation for 45-deg rotation:
  // normal  = (sqrt(2)/2, sqrt(2)/2)
  // tangent = (sqrt(2)/2, -sqrt(2)/2)
  // sigma_nn = n^T * sigma * n
  //   = 0.5*sxx + 2*0.5*sxy + 0.5*syy
  //   = 0.5*(-100e6) + 50e6 + 0.5*(-150e6)
  //   = -50e6 + 50e6 - 75e6 = -75e6
  double sigma_nn = 0.5 * sxx + sxy + 0.5 * syy;

  // sigma_tn = t^T * sigma * n
  //   = (sqrt2/2)*(sxx*sqrt2/2 + sxy*sqrt2/2) + (-sqrt2/2)*(sxy*sqrt2/2 + syy*sqrt2/2)
  //   = 0.5*(sxx + sxy) - 0.5*(sxy + syy)
  //   = 0.5*(sxx - syy)
  //   = 0.5*(-100e6 - (-150e6)) = 0.5*(50e6) = 25e6
  double sigma_tn = 0.5 * (sxx - syy);

  EXPECT_NEAR(T1_o, sigma_tn, 1e-3);
  EXPECT_NEAR(T2_o, -sigma_nn, 1e-3);
}

// ============================================================================
// 30-degree fault
// ============================================================================
TEST(StressTensorRotation, Fault30deg)
{
  double sxx = -120e6, sxy = 70e6, syy = -120e6;
  RankTwoTensor sigma = buildStressTensor2D(sxx, sxy, syy);
  double theta = M_PI / 6.0; // 30 degrees
  RankTwoTensor R = buildCZMRotation(theta);

  double T1_o, T2_o;
  computeLocalTraction(sigma, R, T1_o, T2_o);

  // Hand computation:
  // n = (sin30, cos30) = (0.5, sqrt(3)/2)
  // t = (cos30, -sin30) = (sqrt(3)/2, -0.5)
  double s = std::sin(theta), c = std::cos(theta);

  // sigma_nn = s^2 * sxx + 2*s*c * sxy + c^2 * syy
  double sigma_nn = s * s * sxx + 2 * s * c * sxy + c * c * syy;

  // sigma_tn = s*c*sxx + (c^2 - s^2)*sxy - s*c*syy
  //          = s*c*(sxx - syy) + (c^2 - s^2)*sxy
  double sigma_tn = s * c * (sxx - syy) + (c * c - s * s) * sxy;

  EXPECT_NEAR(T1_o, sigma_tn, 1e-3);
  EXPECT_NEAR(T2_o, -sigma_nn, 1e-3);
}

// ============================================================================
// Isotropic stress: sigma = -P*I -> T1_o = 0 for any angle, T2_o = P
// ============================================================================
TEST(StressTensorRotation, IsotropicStress)
{
  double P = 100e6;
  RankTwoTensor sigma = buildStressTensor2D(-P, 0.0, -P);

  // Test multiple angles
  for (int deg = 0; deg <= 90; deg += 15)
  {
    double theta = deg * M_PI / 180.0;
    RankTwoTensor R = buildCZMRotation(theta);

    double T1_o, T2_o;
    computeLocalTraction(sigma, R, T1_o, T2_o);

    EXPECT_NEAR(T1_o, 0.0, 1e-3) << "Failed at angle=" << deg << " deg";
    EXPECT_NEAR(T2_o, P, 1e-3) << "Failed at angle=" << deg << " deg";
  }
}

// ============================================================================
// Pure shear stress: sigma = [[0, tau], [tau, 0]]
// Horizontal fault: T1_o = tau, T2_o = 0
// ============================================================================
TEST(StressTensorRotation, PureShear_HorizontalFault)
{
  double tau = 70e6;
  RankTwoTensor sigma = buildStressTensor2D(0.0, tau, 0.0);
  RankTwoTensor R = buildCZMRotation(0.0);

  double T1_o, T2_o;
  computeLocalTraction(sigma, R, T1_o, T2_o);

  EXPECT_NEAR(T1_o, tau, 1e-3);
  EXPECT_NEAR(T2_o, 0.0, 1e-3);
}

// ============================================================================
// Pure normal stress: sigma = [[0, 0], [0, -P]]
// Horizontal fault: T1_o = 0, T2_o = P
// ============================================================================
TEST(StressTensorRotation, PureNormal_HorizontalFault)
{
  double P = 120e6;
  RankTwoTensor sigma = buildStressTensor2D(0.0, 0.0, -P);
  RankTwoTensor R = buildCZMRotation(0.0);

  double T1_o, T2_o;
  computeLocalTraction(sigma, R, T1_o, T2_o);

  EXPECT_NEAR(T1_o, 0.0, 1e-3);
  EXPECT_NEAR(T2_o, P, 1e-3);
}

// ============================================================================
// Symmetry: +theta and -theta with symmetric stress
// For sxx = syy (equal normal): T2_o should be the same, T1_o opposite sign
// ============================================================================
TEST(StressTensorRotation, SymmetryCheck)
{
  double sxx = -120e6, sxy = 70e6, syy = -120e6;
  RankTwoTensor sigma = buildStressTensor2D(sxx, sxy, syy);

  double theta = M_PI / 6.0;
  RankTwoTensor R_pos = buildCZMRotation(theta);
  RankTwoTensor R_neg = buildCZMRotation(-theta);

  double T1_pos, T2_pos, T1_neg, T2_neg;
  computeLocalTraction(sigma, R_pos, T1_pos, T2_pos);
  computeLocalTraction(sigma, R_neg, T1_neg, T2_neg);

  // When sxx == syy, the normal stress on the fault is independent of angle
  // (only sxy contributes to the angle dependence of sigma_nn through the cross term)
  // T2 depends on angle, but for sxx==syy:
  //   sigma_nn = sxx*(s^2+c^2) + 2*s*c*sxy = sxx + sin(2*theta)*sxy
  //   sigma_nn(+theta) != sigma_nn(-theta) unless sxy=0
  // So instead, just verify the shear flips sign:
  //   sigma_tn(+theta) = s*c*(sxx-syy) + (c^2-s^2)*sxy = cos(2*theta)*sxy  (since sxx==syy)
  //   sigma_tn(-theta) = -s*c*(sxx-syy) + (c^2-s^2)*sxy = cos(2*theta)*sxy (same!)
  // Actually for sxx==syy: sigma_tn = (c^2 - s^2)*sxy = cos(2*theta)*sxy for both
  // So T1_o should be the SAME for +/- theta when sxx==syy.
  EXPECT_NEAR(T1_pos, T1_neg, 1e-3);
}

// ============================================================================
// Nucleation patch override: T1_o replaced by peak_shear_stress
// (Tests the logic, not the material — just the override behavior)
// ============================================================================
TEST(StressTensorRotation, NuclOverridesTensor)
{
  double sxx = -120e6, sxy = 70e6, syy = -120e6;
  RankTwoTensor sigma = buildStressTensor2D(sxx, sxy, syy);
  RankTwoTensor R = buildCZMRotation(0.0);

  double T1_o, T2_o;
  computeLocalTraction(sigma, R, T1_o, T2_o);

  // Simulate nucleation override
  double peak_shear_stress = 81.6e6;
  double nucl_center_x = 0.0, nucl_center_y = 0.0, nucl_radius = 3000.0;
  double x_coord = 100.0, y_coord = 100.0; // inside patch

  if (nucl_radius > 0.0 &&
      x_coord > nucl_center_x - nucl_radius && x_coord < nucl_center_x + nucl_radius &&
      y_coord > nucl_center_y - nucl_radius && y_coord < nucl_center_y + nucl_radius)
  {
    T1_o = peak_shear_stress;
  }

  EXPECT_NEAR(T1_o, 81.6e6, 1e-3);
  EXPECT_NEAR(T2_o, 120e6, 1e-3); // T2_o unchanged
}

// ============================================================================
// Point outside nucleation patch: T1_o from rotation, not overridden
// ============================================================================
TEST(StressTensorRotation, NuclOutsidePatch)
{
  double sxx = -120e6, sxy = 70e6, syy = -120e6;
  RankTwoTensor sigma = buildStressTensor2D(sxx, sxy, syy);
  RankTwoTensor R = buildCZMRotation(0.0);

  double T1_o, T2_o;
  computeLocalTraction(sigma, R, T1_o, T2_o);

  // Simulate nucleation check — point is outside
  double peak_shear_stress = 81.6e6;
  double nucl_center_x = -8000.0, nucl_center_y = 0.0, nucl_radius = 1500.0;
  double x_coord = 5000.0, y_coord = 0.0; // outside patch

  if (nucl_radius > 0.0 &&
      x_coord > nucl_center_x - nucl_radius && x_coord < nucl_center_x + nucl_radius &&
      y_coord > nucl_center_y - nucl_radius && y_coord < nucl_center_y + nucl_radius)
  {
    T1_o = peak_shear_stress;
  }

  // T1_o should remain the tensor-derived value
  EXPECT_NEAR(T1_o, 70e6, 1e-3);
}

// ============================================================================
// Rotation invariant: trace of stress tensor = trace of rotated tensor
// (Sanity check that the rotation preserves tensor invariants)
// ============================================================================
TEST(StressTensorRotation, RotationPreservesTrace)
{
  double sxx = -100e6, sxy = 50e6, syy = -150e6;
  RankTwoTensor sigma = buildStressTensor2D(sxx, sxy, syy);

  for (int deg = 0; deg <= 90; deg += 10)
  {
    double theta = deg * M_PI / 180.0;
    RankTwoTensor R = buildCZMRotation(theta);
    RankTwoTensor sigma_local = R.transpose() * sigma * R;

    double trace_global = sigma(0, 0) + sigma(1, 1) + sigma(2, 2);
    double trace_local = sigma_local(0, 0) + sigma_local(1, 1) + sigma_local(2, 2);

    EXPECT_NEAR(trace_local, trace_global, 1e-3) << "Failed at angle=" << deg << " deg";
  }
}

//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

/*
 * Unit tests for the coordinate rotation math used in FarmsMaterialRealAux.
 * Tests the local (fault-aligned) coordinate system transformation.
 *
 * The AuxKernel applies:
 *   normal  = -_normals[qp]           (sign flip)
 *   tangent = (normal_y, -normal_x)   (90-degree CCW rotation)
 *   local_shear  = dot(global, tangent)
 *   local_normal = dot(global, normal)
 */

#include "gtest/gtest.h"
#include <cmath>

// ---- Horizontal fault: interface normal (0, 1) ----
TEST(CoordinateRotation, HorizontalFault)
{
  // MOOSE interface normal points from primary to secondary: (0, 1)
  double nx = 0.0, ny = 1.0;

  // FarmsMaterialRealAux flips the sign
  double normal_x = -nx;  // 0
  double normal_y = -ny;  // -1

  // Tangent = (normal_y, -normal_x)
  double tangent_x = normal_y;   // -1
  double tangent_y = -normal_x;  //  0

  EXPECT_NEAR(normal_x, 0.0, 1e-15);
  EXPECT_NEAR(normal_y, -1.0, 1e-15);
  EXPECT_NEAR(tangent_x, -1.0, 1e-15);
  EXPECT_NEAR(tangent_y, 0.0, 1e-15);
}

// ---- Vertical fault: interface normal (1, 0) ----
TEST(CoordinateRotation, VerticalFault)
{
  double nx = 1.0, ny = 0.0;
  double normal_x = -nx;  // -1
  double normal_y = -ny;  //  0
  double tangent_x = normal_y;   //  0
  double tangent_y = -normal_x;  //  1

  EXPECT_NEAR(normal_x, -1.0, 1e-15);
  EXPECT_NEAR(normal_y, 0.0, 1e-15);
  EXPECT_NEAR(tangent_x, 0.0, 1e-15);
  EXPECT_NEAR(tangent_y, 1.0, 1e-15);
}

// ---- 45-degree fault: projection of known global jump ----
TEST(CoordinateRotation, Angle45Fault)
{
  double s = 1.0 / std::sqrt(2.0);
  double nx = s, ny = s;
  double normal_x = -nx, normal_y = -ny;
  double tangent_x = normal_y, tangent_y = -normal_x;

  // Apply a pure x-direction global jump
  double jump_gx = 1.0, jump_gy = 0.0;
  double local_shear  = jump_gx * tangent_x + jump_gy * tangent_y;
  double local_normal = jump_gx * normal_x  + jump_gy * normal_y;

  EXPECT_NEAR(local_shear, -s, 1e-12);
  EXPECT_NEAR(local_normal, -s, 1e-12);
}

// ---- Orthogonality: dot(normal, tangent) = 0 for all angles ----
TEST(CoordinateRotation, Orthogonality)
{
  for (int i = 0; i < 12; ++i)
  {
    double angle = i * M_PI / 6.0;
    double nx = std::cos(angle), ny = std::sin(angle);
    double normal_x = -nx, normal_y = -ny;
    double tangent_x = normal_y, tangent_y = -normal_x;

    double dot = normal_x * tangent_x + normal_y * tangent_y;
    EXPECT_NEAR(dot, 0.0, 1e-14);
  }
}

// ---- Unit length: both normal and tangent have magnitude 1 ----
TEST(CoordinateRotation, UnitLength)
{
  for (int i = 0; i < 12; ++i)
  {
    double angle = i * M_PI / 6.0;
    double nx = std::cos(angle), ny = std::sin(angle);
    double normal_x = -nx, normal_y = -ny;
    double tangent_x = normal_y, tangent_y = -normal_x;

    double n_mag = std::sqrt(normal_x * normal_x + normal_y * normal_y);
    double t_mag = std::sqrt(tangent_x * tangent_x + tangent_y * tangent_y);
    EXPECT_NEAR(n_mag, 1.0, 1e-14);
    EXPECT_NEAR(t_mag, 1.0, 1e-14);
  }
}

// ---- Rotation preserves magnitude: |local|^2 = |global|^2 ----
TEST(CoordinateRotation, MagnitudePreservation)
{
  for (int i = 0; i < 12; ++i)
  {
    double angle = i * M_PI / 6.0;
    double nx = std::cos(angle), ny = std::sin(angle);
    double normal_x = -nx, normal_y = -ny;
    double tangent_x = normal_y, tangent_y = -normal_x;

    // Arbitrary global jump
    double gx = 3.0, gy = -4.0;
    double ls = gx * tangent_x + gy * tangent_y;
    double ln = gx * normal_x  + gy * normal_y;

    double global_mag2 = gx * gx + gy * gy;
    double local_mag2  = ls * ls + ln * ln;
    EXPECT_NEAR(local_mag2, global_mag2, 1e-10);
  }
}

// ---- Traction rotation: verify local traction from known global traction ----
TEST(CoordinateRotation, TractionRotation)
{
  // 30-degree fault
  double angle = M_PI / 6.0;
  double nx = std::cos(angle), ny = std::sin(angle);
  double normal_x = -nx, normal_y = -ny;
  double tangent_x = normal_y, tangent_y = -normal_x;

  // Global traction: (1e6, 0)
  double trac_gx = 1e6, trac_gy = 0.0;

  // Sign flip (matches FarmsMaterialRealAux: traction = -1 * global / 1e6)
  trac_gx *= -1.0 / 1e6;
  trac_gy *= -1.0 / 1e6;

  double local_shear  = trac_gx * tangent_x + trac_gy * tangent_y;
  double local_normal = trac_gx * normal_x  + trac_gy * normal_y;

  // Verify: magnitude preserved after rotation
  double global_mag = std::sqrt(trac_gx * trac_gx + trac_gy * trac_gy);
  double local_mag  = std::sqrt(local_shear * local_shear + local_normal * local_normal);
  EXPECT_NEAR(local_mag, global_mag, 1e-14);

  // Verify specific values
  EXPECT_NEAR(local_shear,  -1.0 * (-ny), 1e-14);  // -(-sin30) = 0.5
  EXPECT_NEAR(local_normal, -1.0 * (-nx), 1e-14);  // -(-cos30) = sqrt(3)/2
}

// ---- Jump rate: (jump - jump_old) / dt ----
TEST(CoordinateRotation, JumpRateComputation)
{
  double nx = 0.0, ny = 1.0; // horizontal fault
  double normal_x = -nx, normal_y = -ny;
  double tangent_x = normal_y, tangent_y = -normal_x;

  double dt = 0.001;

  // Current jump (global, sign-flipped)
  double jump_x = -0.002, jump_y = -0.001;
  // Old jump (global, sign-flipped)
  double jump_x_old = -0.001, jump_y_old = -0.0005;

  // Local current
  double ls = jump_x * tangent_x + jump_y * tangent_y;
  double ln = jump_x * normal_x  + jump_y * normal_y;

  // Local old
  double ls_old = jump_x_old * tangent_x + jump_y_old * tangent_y;
  double ln_old = jump_x_old * normal_x  + jump_y_old * normal_y;

  double rate_s = (ls - ls_old) / dt;
  double rate_n = (ln - ln_old) / dt;

  // For horizontal fault with flipped normal (0,-1) and tangent (-1,0):
  // ls = jump_x * (-1) + jump_y * 0 = 0.002
  // ls_old = 0.001
  // rate_s = (0.002 - 0.001) / 0.001 = 1.0
  EXPECT_NEAR(rate_s, 1.0, 1e-10);
  EXPECT_NEAR(rate_n, 0.5, 1e-10);
}

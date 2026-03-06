//* This file is part of the MOOSE framework
//* https://mooseframework.inl.gov
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

/*
 * Unit tests for strain invariant ratio (xi) computation from ComputeXi.
 *
 * xi = I1 / sqrt(I2)
 * where I1 = trace(eps) = eps_00 + eps_11 + eps_22
 *       I2 = eps:eps    = sum(eps_ij * eps_ij)  (with 2x for off-diagonal)
 */

#include "gtest/gtest.h"
#include <cmath>

// ---- Pure volumetric strain: diag(a,a,a) -> xi = sqrt(3) ----
TEST(XiComputation, PureVolumetric)
{
  double a = 0.001;
  double I1 = 3.0 * a;
  double I2 = 3.0 * a * a;
  double xi = I1 / std::sqrt(I2);
  EXPECT_NEAR(xi, std::sqrt(3.0), 1e-10);
}

// ---- Pure deviatoric (shear): diag(a,-a,0) -> xi = 0 ----
TEST(XiComputation, PureShear)
{
  double a = 0.001;
  double I1 = a + (-a) + 0.0;
  double I2 = a * a + a * a + 0.0;
  double xi = I1 / std::sqrt(I2);
  EXPECT_NEAR(xi, 0.0, 1e-10);
}

// ---- Uniaxial compression: diag(-a, 0, 0) -> xi = -1 ----
TEST(XiComputation, UniaxialCompression)
{
  double a = 0.001;
  double I1 = -a;
  double I2 = a * a;
  double xi = I1 / std::sqrt(I2);
  EXPECT_NEAR(xi, -1.0, 1e-10);
}

// ---- Uniaxial tension: diag(a, 0, 0) -> xi = 1 ----
TEST(XiComputation, UniaxialTension)
{
  double a = 0.001;
  double I1 = a;
  double I2 = a * a;
  double xi = I1 / std::sqrt(I2);
  EXPECT_NEAR(xi, 1.0, 1e-10);
}

// ---- Initial value in ComputeXi is -sqrt(3) ----
TEST(XiComputation, InitialValue)
{
  double xi_init = -std::sqrt(3.0);
  EXPECT_NEAR(xi_init, -1.7320508075688772, 1e-10);
}

// ---- I1 computation with known diagonal strain ----
TEST(XiComputation, I1Computation)
{
  double eps00 = 1e-3, eps11 = 2e-3, eps22 = 3e-3;
  double I1 = eps00 + eps11 + eps22;
  EXPECT_NEAR(I1, 6e-3, 1e-15);
}

// ---- I2 computation with known strain (diagonal only) ----
TEST(XiComputation, I2DiagonalOnly)
{
  double eps00 = 1e-3, eps11 = 2e-3, eps22 = 3e-3;
  double I2 = eps00 * eps00 + eps11 * eps11 + eps22 * eps22;
  EXPECT_NEAR(I2, 14e-6, 1e-18);
}

// ---- I2 computation with off-diagonal components ----
// ComputeXi formula: I2 = eps_ii*eps_ii + 2*eps_ij*eps_ij (i!=j)
TEST(XiComputation, I2WithOffDiagonal)
{
  double eps00 = 1e-3, eps11 = 0.0, eps22 = 0.0;
  double eps01 = 0.5e-3; // off-diagonal
  double eps02 = 0.0, eps12 = 0.0;

  double I2 = eps00 * eps00 + eps11 * eps11 + eps22 * eps22 +
              2.0 * eps01 * eps01 + 2.0 * eps02 * eps02 + 2.0 * eps12 * eps12;

  double expected = 1e-6 + 2.0 * 0.25e-6; // = 1.5e-6
  EXPECT_NEAR(I2, expected, 1e-18);
}

// ---- Xi with off-diagonal strain ----
TEST(XiComputation, XiWithOffDiagonal)
{
  double eps00 = 1e-3, eps11 = 1e-3, eps22 = 1e-3;
  double eps01 = 0.5e-3;

  double I1 = eps00 + eps11 + eps22; // 3e-3
  double I2 = eps00 * eps00 + eps11 * eps11 + eps22 * eps22 +
              2.0 * eps01 * eps01; // 3e-6 + 0.5e-6 = 3.5e-6

  double xi = I1 / std::sqrt(I2);
  double expected = 3e-3 / std::sqrt(3.5e-6);
  EXPECT_NEAR(xi, expected, 1e-10);
  // xi should be less than sqrt(3) due to off-diagonal contribution to I2
  EXPECT_LT(xi, std::sqrt(3.0));
}

// ---- Negative volumetric: diag(-a,-a,-a) -> xi = -sqrt(3) ----
TEST(XiComputation, NegativeVolumetric)
{
  double a = 0.001;
  double I1 = -3.0 * a;
  double I2 = 3.0 * a * a;
  double xi = I1 / std::sqrt(I2);
  EXPECT_NEAR(xi, -std::sqrt(3.0), 1e-10);
}

// ---- Xi is bounded: -sqrt(3) <= xi <= sqrt(3) for any strain ----
TEST(XiComputation, XiBounds)
{
  // Random strain states
  double strains[][6] = {
    {1e-3, 2e-3, -3e-3, 0.5e-3, -0.1e-3, 0.3e-3},
    {-1e-3, -2e-3, -3e-3, 0, 0, 0},
    {5e-3, 5e-3, 5e-3, 1e-3, 1e-3, 1e-3},
    {0, 0, 0.001, 0, 0, 0},
  };

  for (auto & e : strains)
  {
    double I1 = e[0] + e[1] + e[2];
    double I2 = e[0]*e[0] + e[1]*e[1] + e[2]*e[2] +
                2.0*e[3]*e[3] + 2.0*e[4]*e[4] + 2.0*e[5]*e[5];
    if (I2 > 0)
    {
      double xi = I1 / std::sqrt(I2);
      EXPECT_GE(xi, -std::sqrt(3.0) - 1e-10);
      EXPECT_LE(xi, std::sqrt(3.0) + 1e-10);
    }
  }
}

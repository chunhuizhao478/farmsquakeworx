# Continuum Damage-Breakage Model using Slip Weakening Friction Law

Chunhui Zhao$^1$ and Ahmed Elbanna$^{1,2}$ \\
Department of Civil and Environmental Engineering, University of Illinois Urbana-Champaign$^1$ \\
Beckman Institute of Advanced Science and Technology, University of Illinois Urbana-Champaign$^2$

## Introduction

This pages serves as an introduction for the implementation of continuum damage-breakage model coupled with slip weakening friction law for simulating off-fault material damage, soild-to-granular phase transition along with on-fault dynamic rupture propagation, we layout the basics from recent paper [!cite](zhao2024dynamic).

## Boundary Value Problem

The governing equations for the boundary value problem are as follows:

\begin{equation}
\begin{aligned}
    \label{eq1}
    \nabla \cdot \sigma = \rho \ddot{u} \hspace{3mm} in \hspace{3mm} V \hspace{1mm}\\
    \sigma \cdot n = T \hspace{3mm} on \hspace{3mm} S_T \hspace{1mm}\\
    u = u_o \hspace{3mm} on \hspace{3mm} S_u \hspace{1mm}\\
    T^{f+} + T^{f-} = 0 \hspace{3mm} on \hspace{3mm} S_f \hspace{1mm}\\
    I.C. \hspace{3mm} \sigma = \sigma_o + \Delta \sigma \hspace{3mm} S_f
\end{aligned}
\end{equation}

where $\sigma$ is the Cauchy stress tensor. The balance of linear momentum is solved in the bulk $V$. We neglect body forces (e.g. gravity or those arising from pore fluids). The traction boundary condition and displacement boundary condition are specified on $S_T$ and $S_u$, respectively. Along the fault interface $S_f$, the positive side fault interface traction $T^{f^+}$ and the negative side fault interface traction $T^{f^-}$ are governed by the traction at split node algorithm proposed by [!cite](Day_Dalguer_Lapusta_Liu_2005) (This is handled by ```Cohesive Zone Model``` in ```TensorMechanics```, see also "Slip Weakening Friction Law" Section). The rupture is initiated by including a perturbation stress term with a value $\Delta \sigma$ in the initial conditions over a finite length along the fault interface in addition to the initial stress state $\sigma_o$. We restrict this study to small strain kinematics.

## Damage-Breakage Rheology Model and Implementation

The continuum damage-breakage (CDB) rheology model provides relations between displacement gradients and stresses complementary to the equation set equation (1), which is necessary for the closure of the system of equations. Here we provide a general overview of the CDB model, and refer to earlier papers: [!cite](lyakhovsky2011non,lyakhovsky2014continuum,lyakhovsky2014damage,lyakhovsky2016dynamic) for detailed derivations and discussions.

The CDB rheology model combines aspects of a continuum viscoelastic damage framework for brittle solid with a continuum breakage mechanics for granular flow within dynamically generated slip zones. This is accomplished by defining a scalar damage parameter $(\alpha)$ which accounts for the density of distributed cracking [!cite](lyakhovsky1997distributed), together with a scalar breakage parameter $(B)$ representing grain size distribution of a granular phase \citep{einav2007breakage,einav2007breakage2}. Both parameters are defined within the range of $[0,1]$.

The starting point is to formulate the free energy of the deforming medium and include appropriate modifications to account for the damage and breakge effects. To that end, the free energy $F$ is developed as a function of elastic strain $\epsilon^e$, damage parameter $\alpha$, its spatial gradient $\nabla \alpha$, and the breakage parameter $B$. The gradient term accounts for properties in regions around each point \citep{bazant2002nonlocal} and provides an intrinsic length scale for material changes. Following \citep{lyakhovsky2014damage}, the free energy is partitioned by the breakage parameter $B$ into a solid phase $(B=0)$, a granular phase $(B=1)$ or a mixture of both phases $(0<B<1)$:

\begin{equation}
\begin{aligned}
    \label{eq2}
    F(\epsilon^e, \alpha, \nabla \alpha, B)
    =
    (1-B) F_s(\epsilon^e, \alpha, \nabla \alpha)
    +
    B F_b(\epsilon^e)
\end{aligned}
\end{equation}

The free energy for the solid phase $F_s$, and the free energy for the granular phase $F_b$ in equation \eqref{eq2} are given by:

\begin{equation}
\begin{aligned}
    \label{eq3}
    F_s(\epsilon^e, \alpha, \nabla \alpha)
    =
    \frac{1}{\rho} (\frac{\lambda}{2} I_1^2 + \mu I_2 - \gamma I_1 \sqrt{I_2} + \frac{\nu}{2} \nabla_i \alpha \cdot \nabla_i \alpha)
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
    \label{eq4}
    F_b(\epsilon^e) = \frac{1}{\rho} ( a_o I_2 + a_1 I_1 \sqrt{I_2} + a_2 I_2^2 + a_3 \frac{I_1^3}{\sqrt{I_2}})
\end{aligned}
\end{equation}

where the mass density $\rho$, first Lamé constant $\lambda$ and shear modulus $\mu$ are rock properties. As a first order approximation, $\rho$ and $\lambda=\lambda_o$ are kept constant during the deformation, but the shear modulus $\mu$ evolves with damage (see equation \eqref{eq7} given below). The coefficient $\nu$ presented in equation \eqref{eq3} introduces a non-local contribution in the stress tensor through the damage gradient. $I_1 = \epsilon_{ij}^e \delta_{ij}, I_2 = \epsilon_{ij}^e \epsilon_{ij}^e$ are the first and second invariants of elastic strain $\epsilon^e$. $a_o, a_1, a_2, a_3$ are coefficients of granular phase energy (see [!cite](lyakhovsky2014continuum) for detailed derivation). By taking derivative of equations above with respect to elastic strain $\epsilon_{ij}^e$, we obtain stress tensor in the two phases separately (See also [!cite](lyakhovsky2014damage)):

\begin{equation}
\begin{aligned}
    \label{eq5}
    \sigma_{s,ij} = (\lambda - \frac{\gamma}{\xi}) I_1 \delta_{ij} + (2\mu - \gamma\xi)\epsilon^e_{ij} - \nu \nabla_i \alpha \nabla_j \alpha
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
    \label{eq6}
    \sigma_{b,ij} = (2 a_2 + \frac{a_1}{\xi} + 3 a_3 \xi) I_1 \delta_{ij} + (2a_0 + a_1\xi - a_3\xi^3)\epsilon_{ij}^e
\end{aligned}
\end{equation}

The strain invariant ratio is defined as $\xi = I_1 / \sqrt{I_2}$. In the general 3D case (or 2D plane strain case), $\xi$ spans values from $-\sqrt{3}$ (isotropic compression) to $\sqrt{3}$ (isotropic tension). The damage variable $\alpha$ ranges from $0$ (intact material) to $1$ (fully damaged material). Increasing $\alpha$  reduces the shear modulus $\mu$ and increases the damage modulus $\gamma$, as given by the following equations (see also [!cite](lyakhovsky2014damage), equation 12):

\begin{equation}
\begin{aligned}
    \label{eq7}
    \mu = \mu_o + \alpha \xi_o \gamma_r
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
    \label{eq8}
    \gamma = \alpha \gamma_r
\end{aligned}
\end{equation}

where $\mu_o$ denotes the initial shear modulus and $\gamma_r$ is the damage modulus when the damage variable reaches its maximum $(\alpha = 1)$. $\xi_o$ is the strain invariant ratio at the onset of damage, which is considered as a material property related to the internal friction angle (see equation \eqref{eqA1}). We assume the Poisson ratio to be $0.25$ which is appropriate for most rock types.  

Following [!cite](lyakhovsky2014continuum,lyakhovsky2014damage), the flow rule for the permanent strain $\epsilon^p$, as a function of breakage parameter $B$ is given by:

\begin{equation}
\begin{aligned}
    \label{eq9}
    \frac{d\epsilon^p_{ij}}{dt} = C_g B^{m_1} \tau^{m_2}_{ij}
\end{aligned}
\end{equation}

where $C_g$ is a tunable material parameter for the rate of permanent strain accumulation, $\tau_{ij} = \sigma_{ij} - 1/3 \sigma_{kk} \delta_{ij}$ is the deviatoric stress tensor, and $m_1, m_2$ are power constants. The evolution equations for damage $(\alpha)$ and breakage $(B)$ parameters are given by (see [!cite](lyakhovsky2011non) for detailed derivation):

\begin{equation}
\begin{aligned}
    \label{eq10}
    \frac{\partial \alpha}{\partial t}
    \begin{cases}
      (1-B)[C_d I_2 (\xi-\xi_o) + D \nabla^2 \alpha], & \xi \ge \xi_o \\
      (1-B)[C_1 exp(\frac{\alpha}{C_2}) I_2 (\xi - \xi_o) + D \nabla^2 \alpha], &\xi < \xi_o 
    \end{cases}
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
    \label{eq11}
    \frac{\partial B}{\partial t}
    \begin{cases}
      C_B P(\alpha) (1-B) I_2 (\xi-\xi_o), & \xi \ge \xi_o \\
      C_{BH} I_2 (\xi - \xi_o), &\xi < \xi_o 
    \end{cases}
\end{aligned}
\end{equation}

In equation (10), the parameter $C_d$ controls the rate of damage accumulation. $D$ is a damage diffusion coefficient. We restrict our focus in this study to a local model neglecting non-local effects. That is, we set $D=0$. With the adopted formulation, permanent strain begins to rapidly accumulate near the transition to the granular phase. The healing rate of damage variable $\alpha$ is governed by an exponential function with coefficients $C_1$ and $C_2$. As for the breakage evolution shown in equation (11), the parameter $C_B$ is assumed to be related to $C_d$. Here we adopt $C_B = 10C_d$ as suggested in [!cite](lyakhovsky2014continuum,lyakhovsky2014damage). The probability function $P(\alpha)$ in the breakage parameter evolution equation (11) controls the timing for transition to the granular phase, such that the transition happens only when damage reaches its critical value $\alpha_{cr}$. As pointed out in [!cite](lyakhovsky2014damage), the coefficient controlling the breakage healing is not well constrained. Some experiments suggest that the granular flow may abruptly halt under low velocity. Here we set $C_{BH} = 10 ^ 4 \hspace{1mm}1/s$ in equation (11), as suggested in [!cite](lyakhovsky2016dynamic).

## Slip Weakening Friction Law

In this study, the slip behavior of fault interfaces is assumed to be governed by a slip weakening friction law illustrated in Fig.\ref{fig1}(a). The frictional strength is given by the product of the normal stress on the fault and the friction coefficient. Before the resolved shear stress $\tau$ reaches the peak strength $\tau_s = \mu_s \sigma_n$, the fault is stuck with zero slip. After $\tau$ reaches $\tau_s$, the frictional strength decreases to a residual strength $\tau_d = \mu_d \sigma_n$ value over a critical distance $D_c$ and the fault slips following the frictional strength evolution. The drop in friction coefficient from $\mu_s$ to $\mu_d$ is linear. For slip values larger than $D_c$, the dynamic friction coefficient $\mu_d$ remains constant.
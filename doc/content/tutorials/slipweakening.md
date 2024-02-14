# Dynamic Rupture Simulation on a Frictional Planar Fault

Chunhui Zhao$^2$, Mohamed Abdelmeguid$^1$, and Ahmed Elbanna$^{2,3}$ \\
Graduate Aerospace Laboratories, California Institute of Technology$^1$ \\
Department of Civil and Environmental Engineering, University of Illinois Urbana-Champaign$^2$ \\
Beckman Institute of Advanced Science and Technology, University of Illinois Urbana-Champaign$^3$

This page serves as an introduction to simulating dynamic rupture with the planar fault in isotropic media using slip weakening friction law. The cohesive zone model ```(TensorMechanics/CohesiveZoneMaster)``` and central difference explicit time integration are used. The algorithm is previously implemented in our in-house code FEBE [!cite](Ma_Hajarolasvadi_Albertini_Kammer_Elbanna_2018). The implementation in MOOSE is recently used to analyze 2023 Turkey-Syria Earthquake [!cite](Abdelmeguid_Zhao_Yalcinkaya_Gazetas_Elbanna_Rosakis_2023).

### Introduction

An overview of the methodology is given below, followed by a verification case of Southern California Earthquake Center (SCEC) benchmark problem TPV205 [!cite](Harris_Barall_Archuleta_Dunham_Aagaard_Ampuero_Bhat_Cruz-Atienza_Dalguer_Dawson).

#### The Mesh

The mesh generation is handled by MOOSE built-in mesh generator using functionalities from Cohesive Zone Model. Specifically, an initial mesh is generated using ```GeneratedMeshGenerator``` as a first step. Two subdomains, upper and lower blocks associated with planar fault are identified by calling ```ParsedSubdomainMeshGenerator```. Using the function ```BreakMeshByBlockGenerator```, an interface between the two blocks (fault surfaces) is created and the added nodes and boundaries between block pairs are taken care of.

Note the adopted coordinate convention defines the global fault surface as x-z plane. This convention is consistent with **Custom Material Kernel: SlipWeakeningFriction** section.

The example input file for the ```Mesh``` section is given below:

!listing farmsquakeworx/test/tests/3D_slipweakening/tpv2053D.i
         block=Mesh
         id=input-block-0
         caption=Mesh Generation: Input File.

#### Weak Formulation

The dynamic rupture problem possesses the following weak form:

\begin{equation}
\begin{aligned}
\begin{array}{r} - \int_{V}^{}{\sigma \cdot \nabla\psi}\ dV - q\int_{V}^{}{\overline{\sigma} \cdot \nabla\psi}dV + \int_{S_{T}}^{}{T\psi}\ dV + \int_{S_{f}^{+}}^{}{T^{f^{+}}\psi}\ dS + \int_{S_{f}^{-}}^{}{T^{f^{-}}\psi}\ dS - \int_{V}^{}{\rho\ddot{u}\ \psi}\ dV = 0\ \\ \end{array}\ (1)
\end{aligned}
\end{equation}

Where $\sigma$ is the stress tensor, $\overline{\sigma}$ is the damping stress tensor, $T$ is the external traction forces, $\psi$ is the testing function, $\rho$ is the density, $\ddot{u}$ is the acceleration.

The stress divergence term after integration by part $\sigma \cdot \nabla\psi$ , the inertia term $\rho\ddot{u}$ and the stiffness proportional damping $q \overline{\sigma} \cdot \nabla \psi$ are integrated over the whole simulation domain $V$, while $T$ represents the surface tractions acting as external forces.

Importantly, traction $T^{f^{+}}$ on the upper fault surface $S_{f}^{+}$ and traction $T^{f^{-}}$ on the lower fault surface $S_{f}^{-}$ are handled through custom material object inherited from Cohesive Zone Model, which will be explained below in detail. We thus neglect these two on-fault surface traction terms when constructing the residuals.

#### Action and Kernels 

One ```Action```, ```TensorMechanics/Master```, and two kernels ```InertiaForce``` and ```StiffPropDamping``` are used to construct residual for this problem.

```TensorMechanics/Master``` action automatically creates the ```StressDivergenceTensors``` kernel which provides the following term:

\begin{equation}
\begin{aligned}
\begin{array}{r} \int_{V}^{}{\sigma \cdot \nabla\psi}\ dV(2) \end{array}
\end{aligned}
\end{equation}

```InertiaForce``` gives the inertia term in the weak form:

\begin{equation}
\begin{aligned}
\begin{array}{r} \int_{V}^{}{\rho\ddot{u}\ \psi}\ dV(3) \end{array}
\end{aligned}
\end{equation}

The input file defining both kernels are given below, note in 2D formulation, “plane strain” needs to be set:

!listing farmsquakeworx/test/tests/2D_slipweakening/tpv2052D.i 
         block=Modules
         id=input-block-1
         caption=StressDivergenceTensors Kernels: Input File (2D)

!listing farmsquakeworx/test/tests/3D_slipweakening/tpv2053D.i
         block=Modules
         id=input-block-2
         caption=StressDivergenceTensors Kernels: Input File (3D)

The inertia force kernel is given as follows, with the assumption of small strain, we set ```use_displaced_mesh``` to ```false```:

!listing farmsquakeworx/test/tests/3D_slipweakening/tpv2053D.i
         block=Kernels
         id=input-block-3
         caption=InertiaForce Kernels: Input File

#### Custom Kernel: StiffPropDamping

```StiffPropDamping``` is a custom kernel for adding stiffness proportional damping into the system to reduce the high-frequency oscillations. The weak form is expressed as follows:

\begin{equation}
\begin{aligned}
\begin{array}{r} q\int_{V}^{}{\overline{\sigma} \cdot \nabla\psi}dV (4) \end{array}
\end{aligned}
\end{equation}

Where $\overline{\sigma}$ is the damping stress tensor, $q$ is damping constant. To see how the damping term is introduced, the .h and .cpp file is provided below:

The header file explains its inherence relation with its parent class ```StressDivergenceTensors```, which is introduced earlier.

!listing farmsquakeworx/include/kernels/StiffPropDamping.h
         caption=StiffPropDamping: Input File

The source file implements the weak form evaluation at each quadrature point, here we follow similar definition of damping stress tensor given in [!cite](Day_Dalguer_Lapusta_Liu_2005) , Appendix A8:

\begin{equation}
\begin{aligned}
\begin{array}{r} \overline{\sigma} = \Delta t\left\lbrack \frac{\sigma_{t} - \sigma_{t - \Delta t}}{\Delta t} \right\rbrack = \left\lbrack \sigma_{t} - \sigma_{t - \Delta t} \right\rbrack (5)\end{array}
\end{aligned}
\end{equation}

Where $\sigma_{t}$ and $\sigma_{t - \Delta t}$ are stress tensor from current/last time step. The code snippet is given below, notice that for each custom function, user needs to register the function to their own app using ```registerMooseObject```. (```TensorMechanicsApp``` is a custom app name that can be replaced).

!listing farmsquakeworx/src/kernels/StiffPropDamping.C
         caption=StiffPropDamping: Source File

To utilize the kernel, allocate it inside ```[Kernels]``` section of input file:

!listing farmsquakeworx/test/tests/3D_slipweakening/tpv2053D.i
         block=Kernels
         id=input-block-4
         caption=StiffPropDamping: Input File

#### AuxKernels

All the quantities passed as variable input into the material kernel are defined as aux-variables. The code for defining aux variables residuals (```resid, resid_slipweakening```), displacements (```disp_slipweakening```), velocity (```vel_slipweakening```), spatial distribution of static friction coefficient (```mu_s```) and initial shear stress along strike direction (```ini_shear_stress```) is given below:

!listing farmsquakeworx/test/tests/3D_slipweakening/tpv2053D.i
         block=AuxVariables
         id=input-block-5
         caption=AuxVariables: Input File

Two Aux Kernels ```CopyValueAux``` ```ComputeValueRate``` are defined to pass/store data ```coupled```, data time change ```coupledDot``` to aux variables. Below provides the input file:

!listing farmsquakeworx/test/tests/3D_slipweakening/tpv2053D.i
         block=AuxKernels
         id=input-block-6
         caption=AuxKernels: Input File
         start=Vel_x
         end=Residual_z

Notice ```TIMESTEP_BEGIN``` option makes all the aux kernel operations executed at the beginning of every time step before the system solve.

The time integration is handled using ```CentralDifference``` explicit time integrator with ```lumped``` mass solve type, the corresponding code is here:

!listing farmsquakeworx/test/tests/3D_slipweakening/tpv2053D.i
         block=Executioner
         id=input-block-7
         caption=CentralDifference: Input File

!listing farmsquakeworx/test/tests/3D_slipweakening/tpv2053D.i
         block=Outputs
         id=input-block-8
         caption=Output: Input File

#### Tagging System

To obtain the most up-to-date restoration force from ```StressDivergenTensors``` kernel, a custom ```Tagging UserObject``` is set up to retrieve them after the system solve. MOOSE provides such a system to easily obtain solution or restoration force vector/matrix, please refer to [the tagging documentation](TaggingInterface.md) for more information. Here, we define a custom UserObject ```ResidualEvaluationUserObject``` inherited from ```GeneralUserObject``` to obtain the stress divergence term $\begin{array}{r} \int_{V}^{}{\sigma \cdot \nabla\psi}\ dV(2) \end{array}$ evaluated at each quadrature point, the header and source file is presented below.

!listing farmsquakeworx/include/userobjects/ResidualEvaluationUserObject.h
caption=ResidualEvaluationUserObject: Header File*

!listing farmsquakeworx/src/userobjects/ResidualEvaluationUserObject.C
caption=ResidualEvaluationUserObject: Source File*

To execute the ```ResidualEvaluationUserObject```, in the input file we add the following code block:

!listing farmsquakeworx/test/tests/3D_slipweakening/tpv2053D.i
         block=Problem
         id=input-block-9
         caption=Problem: Input File

This allocates the tag vector. The tag vector needs to link with the action block ```[TensorMechanics]```, which automatically set up stress divergence term:

!listing farmsquakeworx/test/tests/3D_slipweakening/tpv2053D.i
         block=Modules
         id=input-block-10
         caption=Add "extra_vector_tags" in the Action `[TensorMechanics]`: Input File

```ResidualEvaluationUserObject``` is called in ```[UserObjects]```:

!listing farmsquakeworx/test/tests/3D_slipweakening/tpv2053D.i
         block=UserObjects
         id=input-block-11
         caption=UserObject: Input File

The block executes ```ResidualEvaluationUserObject``` at ```TIMESTEP_END``` but before the execuation of ```[AuxKernels]```. After retrieving the force vector, in the ```[AuxKernels]```, we assign it to pre-defined restoration force aux variable using ```TagVectorAux```:

!listing farmsquakeworx/test/tests/3D_slipweakening/tpv2053D.i
         block=AuxKernels
         id=input-block-12
         caption=TagVectorAux: Input File

Here ```v``` is primary variable name ```disp_x, disp_y, disp_z``` and ```variable``` accepts aux variable. As mentioned before, these operation happens only after the latest restoration force is obtained through ```ResidualEvaluationUserObject```.
Then the variable ```resid_x, resid_y, resid_z``` will pass stored value to ```resid_slipweakening_x, resid_slipweakening_y, resid_slipweakening_z``` at the beginning of next time step, the later ones then feed into material kernel to ensure the time consistency of retreiving quantities.

#### Materials Object

Isotropic, linear elastic material is used for simplicity, but users are free to adopt other material types. The input file for this part is given below as an example:

!listing farmsquakeworx/test/tests/3D_slipweakening/tpv2053D.i
         block=Materials
         id=input-block-13
         caption=Materials: Input File

Note a custom material kernel ```SlipWeakeningFriction3d``` is added after the definition of ```density```, this part related to the Cohesive Zone Model, and it is explained next.

#### Custom Material Kernel: SlipWeakeningFriction

Inheriting from ```InterfaceKernel```, the update of interface traction is accomplished by defining a custom material kernel. Following [!cite](Day_Dalguer_Lapusta_Liu_2005) approach combing finite difference and traction-at-split node (TSN), the traction at the fault surface is calculated to enforce continuity, see also (Ma, 2019). Here, a step-by-step instruction along with detailed code explanation is given below.

!listing farmsquakeworx/include/materials/slipweakening/SlipWeakeningFriction3d.h

The header file is a subclass of ```CZMComputeLocalTractionTotalBase```:

We allocate ```Real```, ```VariableValue``` parameters to take on the values passing from the input file, and the parameters extracted from the ```MaterialProperty``` is available to be evaluated at each quadrature point.

The source file first includes the header file we just defined in ```InterfaceKernel.h```, followed by constructor declaration which takes input data:

!listing farmsquakeworx/src/materials/slipweakening/SlipWeakeningFriction3d.C
         re=InputParameters\sSlipWeakeningFriction3d::validParams.*?^}

!listing farmsquakeworx/src/materials/slipweakening/SlipWeakeningFriction3d.C
         re=SlipWeakeningFriction3d::SlipWeakeningFriction3d.*?^}

Moose provides an easy access to ```neighbor``` quadrature point data across the interface by declaring ```coupledNeighborValue```, and ```old``` data from last time step evaluated at each quadrature point can be retrieved by declaring ```coupledValueOld``` or ```coupledNeighborValueOld```.

All the algorithms are implemented by overriding the function of ```InterfaceKernel```: ```computeInterfaceTractionAndDerivatives```, which takes displacement jump, reaction forces across the interface as input, compute and enforce traction boundary condition along the interface.

!listing farmsquakeworx/src/materials/slipweakening/SlipWeakeningFriction3d.C
         re=void\sSlipWeakeningFriction3d::computeInterfaceTractionAndDerivatives.*?^}

We now start by computing all the necessary quantities:

The equation for rate of displacement jump $\dot{D}$ given displacement jump $D$ in global coordinate$ is as follows:

\begin{equation}
\begin{aligned}
\begin{array}{r} D_{i}^{global} = u_{i}^{+} - u_{i}^{-} \hspace{3mm} {\dot{D}}_{i}^{global} = {\dot{u}}_{i}^{+} - {\dot{u}}_{i}^{-} (6) \end{array}
\end{aligned}
\end{equation}

The coordinate transformation is performed using rotation matrix $\mathbf{R}$ to obtain local displacement jump $D_{i}$ and local displacement jump rate $\dot{D}:$

\begin{equation}
\begin{aligned}
D_{i} = \mathbf{R}^{\mathbf{T}}D_{i}^{global}\ \hspace{3mm} {\dot{D}}_{i} = \mathbf{R}^{\mathbf{T}}{\dot{D}}_{i}^{global}(7)
\end{aligned}
\end{equation}

The code snippet is given below:

!listing id=local0 caption=SlipWeakeningFriction: Source File. language=cpp
// Global Displacement Jump
RealVectorValue displacement_jump_global(_disp_slipweakening_x[_qp] - _disp_slipweakening_neighbor_x[_qp], _disp_slipweakening_y[_qp] - _disp_slipweakening_neighbor_y[_qp], _disp_slipweakening_z[_qp] - _disp_slipweakening_neighbor_z[_qp]);
// Global Displacement Jump Old
RealVectorValue displacement_jump_old_global(_disp_slipweakening_x_old[_qp] - _disp_slipweakening_neighbor_x_old[_qp], _disp_slipweakening_y_old[_qp] - _disp_slipweakening_neighbor_y_old[_qp], _disp_slipweakening_z_old[_qp] - _disp_slipweakening_neighbor_z_old[_qp]);
// Global Displacement Jump Rate
RealVectorValue displacement_jump_rate_global = (displacement_jump_global - displacement_jump_old_global) * (1 / _dt);
// Local Displacement Jump / Displacement Jump Rate
RealVectorValue displacement_jump = _rot[_qp].transpose() * displacement_jump_global;
RealVectorValue displacement_jump_rate = _rot[_qp].transpose() * displacement_jump_rate_global;

Similarly, reactions at primary (plus) or secondary (minus) side
$R_{+ / -}$ are first defined in global coordinate and then transform
to local coordinate:

\begin{equation}
\begin{aligned}
R_{+ / -}^{global} = ( - R_{x,\  + / -}, - R_{y,\  + / -}, - R_{z,\  + / -})
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
R_{+ / -} = \mathbf{R}^{\mathbf{T}}R_{+ / -}^{global}\ \ \ (8)
\end{aligned}
\end{equation}

Notice the added minus sign indicates the quantity is the bulk to fault node traction.

The nodal mass $M^{\pm}$ for plus/minus side of fault surface is computed in an explicit form:

\begin{equation}
\begin{aligned}
\begin{array}{r} M^{\pm} = \rho\frac{a^{3}}{2} (9) \end{array}
\end{aligned}
\end{equation}

Where $\rho$ is the density, $a$ is the edge element length of the fault surface. Along with parameter initialization, the code is outlined below:

The code snippet is given below:

!listing id=local1 caption=SlipWeakeningFriction: Source File. language=cpp
//Parameter initialization
Real mu_s = 0;
Real mu_d = _mu_d;
Real Dc = _Dc;
Real tau_f = 0;
Real T1_o = 0;
Real T2_o = _T2_o;
Real T3_o = _T3_o;
Real len = _len;
// Reaction force in local coordinate
RealVectorValue R_plus_global(-_reaction_slipweakening_x[_qp], -_reaction_slipweakening_y[_qp],-_reaction_slipweakening_z[_qp]);
RealVectorValue R_minus_global(-_reaction_slipweakening_neighbor_x[_qp],-_reaction_slipweakening_neighbor_y[_qp], -_reaction_slipweakening_neighbor_z[_qp]);
RealVectorValue R_plus_local = _rot[_qp].transpose() * R_plus_global;
RealVectorValue R_minus_local = _rot[_qp].transpose() * R_minus_global;
Real R_plus_local_x = R_plus_local(1);
Real R_plus_local_y = R_plus_local(0);
Real R_plus_local_z = R_plus_local(2);
Real R_minus_local_x = R_minus_local(1);
Real R_minus_local_y = R_minus_local(0);
Real R_minus_local_z = R_minus_local(2);
// Compute node mass
Real M = _density[_qp] * len * len * len / 2;
// Compute mu_s for current qp
mu_s = _mu_s[_qp];
// Compute T1_o for current qp
T1_o = _ini_shear_sts[_qp];

Notice the last two lines that the spatial distribution of static friction coefficient $\mu_s$ and initial shear stress along the strike direction $T_1^o$ are passed into the material object as aux variable. We define the quantities first as two separate ```function``` object ```StaticFricCoeffMus```, ```InitialStrikeShearStress``` given as follows: 

The spatial distribution of $\mu_s$:

!listing id=local22 caption=PiecewiseConstant mu_s: Input File. language=cpp
[func_static_friction_coeff_mus]
       type = PiecewiseConstant
       axis=x
       x = '-1000e3 -15e3 15e3'
       y = '10000 0.677 10000.0'
       direction = left
[]

The spatial distribution of $T_1^o$:

!listing id=local23 caption=PiecewiseConstant T1_o: Input File. language=cpp
[func_initial_strike_shear_stress]
       type = PiecewiseConstant
       axis=x
       x = '-1000e3 -9.0e3 -6.0e3 -1.5e3  1.5e3  6.0e3  9.0e3'
       y = ' 70.0e6 78.0e6 70.0e6 81.6e6 70.0e6 62.0e6 70.0e6'
[]

We then have them defined in the input file within ```[Functions]``` section:

!listing farmsquakeworx/test/tests/3D_slipweakening/tpv2053D.i
         block=Functions
         id=input-block-14
         caption=”InitialStrikeShearStress” and “StaticFricCoeffMus" Example
Function

In the ```[AuxKernels]```, we pass the functions to pre-defined aux variables:

!listing id=local2 caption=FunctionAux: Input File. language=cpp
[StaticFricCoeff]
    type = FunctionAux
    variable = mu_s
    function = func_static_friction_coeff_mus
    execute_on = 'LINEAR TIMESTEP_BEGIN'
[]
[StrikeShearStress]
    type = FunctionAux
    variable = ini_shear_stress
    function = func_initial_strike_shear_stress
    execute_on = 'LINEAR TIMESTEP_BEGIN'
[]

With all the parameters at hand, the construction of ```SlipWeakeningFriction3d``` kernel proceeds by computing sticking traction ${\widetilde{T}}_{v}$, which enforces continuity of tangential velocity and normal displacement, refer to [!cite](Day_Dalguer_Lapusta_Liu_2005) for detailed derivation:

\begin{equation}
\begin{aligned}
{\widetilde{T}}_{v} = \ \frac{\Delta t^{- 1}M^{+}M^{-}\left( {\dot{u}}_{v}^{+} - {\dot{u}}_{v}^{-} \right) + M^{-}f_{v}^{+} - M^{+}f_{v}^{-}}{a^{2}\left( M^{+} + M^{-} \right)} + T_{v}^{0},\ \ v = x,z\ (10) 
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
{\widetilde{T}}_{v} = \frac{- \Delta t^{- 1}M^{+}M^{-}\left\lbrack \left( {\dot{u}}_{v}^{+} - {\dot{u}}_{v}^{-} \right) + \Delta t^{- 1}\left( u_{v}^{+} - u_{v}^{-} \right) \right\rbrack - M^{-}f_{v}^{+} + M^{+}f_{v}^{-}}{a^{2}\left( M^{+} + M^{-} \right)} + T_{v}^{0},\ \ v = y\ \ \ (11) \\
\end{aligned}
\end{equation}

Where
$M^{\pm},\ \ u_{i}^{\pm},\ \ {{\dot{u}}_{i}}^{\pm},\ f_{i}^{\pm},\ a$ are node mass, displacement, velocity, elastic forces for plus/minus side, the edge element size of the fault surface. The code is provided below:

!listing id=local3 caption=SlipWeakeningFriction: Source File. language=cpp
//Compute sticking stress
Real T1 =  (1/_dt)*M*displacement_jump_rate(1)/(2*len*len) + (R_plus_local_x - R_minus_local_x)/(2*len*len) + T1_o;
Real T3 =  (1/_dt)*M*displacement_jump_rate(2)/(2*len*len) + (R_plus_local_z - R_minus_local_z)/(2*len*len) + T3_o;
Real T2 =  -(1/_dt)*M*(displacement_jump_rate(0)+(1/_dt)*displacement_jump(0))/(2*len*len) + ( (R_minus_local_y - R_plus_local_y) / ( 2*len*len ) ) - T2_o ;

The friction strength $\tau_{f}$, which is a function of slip magnitude,is computed below:

\begin{equation}
\begin{aligned}
\begin{array}{r}
\tau_{f}(D) = \left\{ \begin{array}{r}
\tau_{s} - \frac{\left( \tau_{s} - \tau_{r} \right)\left| |D| \right|_{2}}{D_{c}} \\
\tau_{r},\ \ \left| |D| \right|_{2} \geq D_{c} \\
\end{array},\ \left| |D| \right|_{2} < D_{c} \right.\ \ \ (11) \\
\end{array}
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
\begin{array}{r}
\tau_{s} = \mu_{s}T_{2},\ \ \tau_{r} = \mu_{d}T_{2}\ \ \ (12) \\
\end{array}
\end{aligned}
\end{equation}

$\tau_{s}$ and $\tau_{r}$ are the peak and residual frictional strength, $D_{c}$ is the critical slip required for stress to reach the residual value, $\mu_{s}$ and $\mu_{d}$ are static and dynamic friction parameters, respectively.

!listing id=local4 caption=SlipWeakeningFriction: Source File. language=cpp
//Compute friction strength
   if (std::norm(displacement_jump) < Dc)
   {
     tau_f = (mu_s - (mu_s - mu_d)*std::norm(displacement_jump)/Dc)*(-T2); // square for shear component
   } 
   else
   {
     tau_f = mu_d * (-T2);
   }

Note the negative sign with $T_{2}$ to ensure positiveness of $\tau_{s}$. The fault traction $T_{v}$ is then calculated to satisfy jump conditions:

\begin{equation}
\begin{aligned}
\begin{array}{r}
T_{v} = \left\{ \begin{array}{r}
{\widetilde{T}}_{v},\ \ v = x,z,\ \ \left\lbrack \left( {\widetilde{T}}_{x} \right)^{2} + \left( {\widetilde{T}}_{z} \right)^{2} \right\rbrack \leq \tau_{f}\ \  \\
\tau_{f}\frac{{\widetilde{T}}_{v}}{\left\lbrack \left( {\widetilde{T}}_{x} \right)^{2} + \left( {\widetilde{T}}_{z} \right)^{2} \right\rbrack},\ \ v = x,z,\ \ \left\lbrack \left( {\widetilde{T}}_{x} \right)^{2} + \left( {\widetilde{T}}_{z} \right)^{2} \right\rbrack > \tau_{f}\ \ \  \\
\begin{matrix}
{\widetilde{T}}_{v},\ \ v = y,\ \ {\widetilde{T}}_{2} \leq 0 \\
0,\ \ v = y,\ \ {\widetilde{T}}_{2} > 0 \\
\end{matrix} \\
\end{array} \right.\ (13) \\
\end{array}
\end{aligned}
\end{equation}

!listing id=local5 caption=SlipWeakeningFriction: Source File. language=cpp
//Compute fault traction
if (T2<0)
{
}else{
T2 = 0;
}
//Compute fault traction
if (std::sqrt(T1*T1 + T3*T3)<tau_f)
{
}else{
T1 = tau_f*T1/std::sqrt(T1*T1 + T3*T3);
T3 = tau_f*T3/std::sqrt(T1*T1 + T3*T3);
}

Note that the first two conditions for $v = x,z$ in equation (12) are utilized for shear jump condition (along strike and dip direction, respectively), which is implemented in the code, the last two conditions $v = y$ are used to enforce normal components jump conditions.

Finally, the new computed local tractions increments (measured from the initial stage) are plugged into the ```interface_traction``` to enforce traction boundary condition along the interface:

!listing id=local6 caption=SlipWeakeningFriction: Source File. language=cpp
//Assign back traction in CZM
RealVectorValue traction;
traction(0) = T2+T2_o; 
traction(1) = -T1+T1_o; 
traction(2) = -T3+T3_o;
_interface_traction[_qp] = traction;
_dinterface_traction_djump[_qp] = 0;

#### Solution steps:

All the previous steps are gathered and summarized below:

1.  ```(Mesh Generation)``` Generate mesh and interface using built-in mesh
    generator.

2.  ```(Aux Variable Calculation)``` Update/store the displacement,
    reaction, velocity at current time step

3.  ```(Material Object Evaluation)``` Using current quantities to
    enforce fault tractions

5.  ```(Residual Computation)``` Use Central difference computing residual
    using equation (2) (3) (4).

6.  ```(Tagging UserObject)``` Save the latest restoration forces

7. ```(Output)``` Output results as exodus file for post-processing

7.  Go back and repeat 1 with time marching.

Inside ```(Material Object Calculation)```, do the following:

1.  Retrieve relevant aux variables (displacements, reactions at two
    sides of interface)

2.  Compute interface displacement jump $D$, calculate displacement jump
    rate $\dot{D}$ in the local coordinate using equation $(6)$ $(7)$, nodal
    mass $M^{\pm}$ using equation $(8)$ $(9)$.

3.  Compute sticking traction using equation $(10)$, $(11)$.

4.  Compute $\tau_{f}(D)$ using equation $(11)$, $(12)$

5.  Compute $T_{v}$ using equation $(13)$ and enforce as interface
    traction boundary condition

A flow chart summarizing the solving procedure is given as follows;

!media large_media/tensor_mechanics/slip_weakening/flowchart.png
       id=sw-flowchart
       style=halign=center
       caption=Solve Procedure Flow Chart

### Verification Case: TPV205-2D

#### Mesh:

A square mesh with uniform **QUAD4** element and mesh size **100m** is created using MOOSE built-in mesh generator, following the descriptions in the previous section, the fault is represented as an interface using
**Cohesive Zone Model**.

!media large_media/tensor_mechanics/slip_weakening/2dmesh.png
       id=sw-2dmesh
       caption=Example 2D Mesh Configuration with QUAD4 Element (blue - lower block, red - upper block)*
       style=width:50%;padding:20px;

#### Problem Description

We use the benchmark problem TPV205-2D from the SCEC Dynamic Rupture Validation exercises (Harris, 2009). Figure 3 shows the setup of the problem. The following assumptions are made:

1.  2D-in plane under plane strain condition,

2.  Fault is governed by linear slip-weakening friction law,

3.  Linear elastic homogeneous bulk material.

The rupture is nucleated using a 3-km wide overstressed region located at the center of the fault. The normal stress is uniform along the entire fault length while initial shear stress is nonuniform. Two strength barriers with length $L_{s}$, are located at the left and right edges of the fault. The barriers provide enough static frictional strength to stop the rupture propagation.

!media large_media/tensor_mechanics/slip_weakening/swlaw.png
       id=sw-swlaw
       caption=TPV205 Problem Description (Problem Setup, Initial Shear Stress Distribution, Linear Slip Weakening Friction Law)
       style=halign=center

The parameter table used for this validation is summarized in Table 1.

!table id=table1 caption=Simulation Parameter Table
| Variable                                 | Value                                   | Description                |
|------------------------------------------|-----------------------------------------|----------------------------|
| $\mathbf{\rho}$                       | 2670 $kg/m^{3}$                         | Density                    |
| $\mathbf{\lambda = \mu}$               | 32.04 $GPa$                             | Lame Parameters            |
| $\mathbf{T}_{\mathbf{2}}^{\mathbf{o}}$ | 120 $MPa$                               | Background Normal Stress   |
| $\mathbf{T}_{\mathbf{1}}^{\mathbf{o}}$ | 81.6 $MPa$ where $abs(x)$ < 1.5 $km$;  78.0 $MPa$ where - 9$km$ < $x$ < - 6$km$;                62.0 $MPa$ where 6$km$ < $x$ < 9$km$; 70 $MPa$ elsewise                              | Background Shear Stress    |
| $\mathbf{D}_{\mathbf{c}}$             | 0.4 $m$                                 | Characteristic Length      |
| $\mathbf{\mu}_{\mathbf{s}}$            | 0.677,$abs(x)$ < 15 $km$; 10000, $abs(x)$ > 15$km$   | Static Friction Parameter  |
| $\mathbf{\mu}_{\mathbf{d}}$            | 0.525                                   | Dynamic Friction Parameter |
| $\mathbf{\Delta}\mathbf{x}$            | 100 m                                   | Mesh Size                  |

#### Results

The simulation runs up to *12s*. The results here compare the current implementation (Moose) and reported benchmark data with mesh size 50m,
100m (FEM 50m, FEM 100m) for the time history of slip and slip rate observed in several site locations $x = - 4.5km,\ \ x = 0km,\ \ x = 4.5m.$ There is an excellent match between the current Moose implementation and benchmark problem published results.

!media large_media/tensor_mechanics/slip_weakening/2dsliptimehist.png
       id=sw-2dsliptimehist
       caption=Time History of Slip (FE - 50m, FE - 100m, Moose) at locations 0 km, 4.5 km, -4.5 km
       style=width:50%;padding:20px;

!media large_media/tensor_mechanics/slip_weakening/2dslipratetimehist.png
       id=sw-figure32
       caption=Time History of Slip rate (FE - 50m, FE - 100m, Moose) at locations 0 km, 4.5 km, -4.5 km
       style=width:50%;padding:20px;

The L2 error norm is measured with FE – 100m for full time history of
slip, which gives error within 5%:

!media large_media/tensor_mechanics/slip_weakening/2dl2errornorm.png
       id=sw-2dl2errornorm
       caption=Time History of Slip rate (FE - 50m, FE - 100m, Moose) at locations 0 km, 4.5 km, -4.5 km
       style=width:50%;padding:20px;

### Verification Case: TPV205-3D

#### Mesh

A cubic mesh (30km $\times$ 30km $\times$ 30km) with uniform Hex8
element and mesh size 200m is created using MOOSE built-in mesh
generator, following the descriptions in the previous section, the fault
is represented as an x-z plane surface using **Cohesive Zone Model**.

!media large_media/tensor_mechanics/slip_weakening/3dmesh.png
       id=sw-3dmesh
       caption=Example 3D Mesh Configuration with QUAD4 Element (blue - lower block, red - upper block)
       style=width:50%;padding:20px;

**Problem Description

We use the benchmark problem TPV205-3D from the SCEC Dynamic Rupture Validation exercises. Figure 24 shows the setup of the problem at x-z fault surface plane. The following assumptions are made:

1.  Fault is governed by linear slip-weakening friction law,

2.  Linear elastic homogeneous bulk material.

The rupture is nucleated within a (3km $\times$ 3km) overstressed region which the nucleation center is located at strike(x) 0m, dip(z) 7.5km. The normal stress is uniform along the entire fault length while initial shear stress $\tau_{xy}$ (along strike direction) is nonuniform, while initial shear stress $\tau_{zy}$ (along dip direction) is kept zero. Two strength barriers (3km $\times$ 3km) with the centers located at the strike -7.5km, dip 7.5km on the left and the strike 7.5km, dip 7.5km on the right of the overstressed region on the fault. The barriers (dip > 15km) provide enough static frictional strength to stop the rupture propagation along dip direction.

!media large_media/tensor_mechanics/slip_weakening/3dshearstressdistribution.png
       id=sw-3dshearstressdistribution
       caption=Fault Surface Background Shear Stress Distribution
       style=halign=center

The parameter table used for this validation is summarized in Table 2.

!table id=table2 caption=Simulation Parameter Table
| Variable                                 | Value                                   | Description                |
|------------------------------------------|-----------------------------------------|----------------------------|
| $\mathbf{\rho}$                       | 2670 $kg/m^{3}$                         | Density                    |
| $\mathbf{\lambda = \mu}$               | 32.04 $GPa$                             | Lame Parameters            |
| $\mathbf{T}_{\mathbf{2}}^{\mathbf{o}}$ | 120 $MPa$                               | Background Normal Stress   |
| $\mathbf{T}_{\mathbf{1}}^{\mathbf{o}}$ | 81.6 $MPa$ where $abs(x)$ < 1.5 $km$;  78.0 $MPa$ where - 9$km$ < $x$ < - 6$km$;                62.0 $MPa$ where 6$km$ < $x$ < 9$km$; 70 $MPa$ elsewise                              | Background Shear Stress    |
| $\mathbf{D}_{\mathbf{c}}$             | 0.4 $m$                                 | Characteristic Length      |
| $\mathbf{\mu}_{\mathbf{s}}$            | 0.677,$abs(x)$ < 15 $km$; 10000, $abs(x)$ > 15$km$   | Static Friction Parameter  |
| $\mathbf{\mu}_{\mathbf{d}}$            | 0.525                                   | Dynamic Friction Parameter |
| $\mathbf{\Delta}\mathbf{x}$            | 200 m                                   | Mesh Size                  |

#### Results

The simulation runs up to *3s*. The results here compare the current implementation (Moose) and reported benchmark data with mesh size 100m, 200m (FEM 100m, FEM 200m) for the time history of slip and slip rate observed in several site locations
$x = -4.5km,\ \ x = 0km,\ \ x = 4.5m.$ with same dip distance 7.5km.

!media large_media/tensor_mechanics/slip_weakening/3dsliptimehist.png
       id=sw-3dsliptimehist
       caption=Time History of Slip (Reference FE - 200m, FE – 100m, Moose) at locations 0 km, 4.5 km, -4.5 km
       style=width:50%;padding:20px;

!media large_media/tensor_mechanics/slip_weakening/3dslipratetimehist.png
       id=sw-3dslipratetimehist
       caption=Time History of Slip Rate (Reference FE - 200m, FE – 100m, Moose) at locations 0 km, 4.5 km, -4.5 km
       style=width:50%;padding:20px;

Good agreements can be observed especially compared with FE-100m results. With the help of mesh refinement and lager domain size, the results are promised to match for the full-time history (up to 12s).

The L2 error norm between (FE-100m and MOOSE-200m) is documented in the following chart with the error within 5%:

!media large_media/tensor_mechanics/slip_weakening/3derrornorm.png
       id=sw-3derrornorm
       caption=TPV-3D L2 Error Norm of Slip (FE-100m, MOOSE-200m) at locations (0m, 4.5km, -4.5km)
       style=width:50%;padding:20px;

#### Bibliography

!bibtex bibliography

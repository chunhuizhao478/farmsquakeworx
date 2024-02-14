# Dynamic Rupture Simulation using Rate-and-State Friction Law

Chunhui Zhao$^1$ and Ahmed Elbanna$^{1,2}$ \\
Department of Civil and Environmental Engineering, University of Illinois Urbana-Champaign$^1$ \\
Beckman Institute of Advanced Science and Technology, University of Illinois Urbana-Champaign$^2$

## Introduction

This page serves as an introduction for simulating dynamic rupture with the planar fault in isotropic media using rate-and-state friction law.

## Weak Formulation

The dynamic rupture problem possesses the following weak form:

\begin{equation}
\begin{aligned}
\begin{array}{r} - \int_{V}^{}{\sigma \cdot \nabla\psi}\ dV - q\int_{V}^{}{\overline{\sigma} \cdot \nabla\psi}dV + \int_{S_{T}}^{}{T\psi}\ dV + \int_{S_{f}^{+}}^{}{T^{f^{+}}\psi}\ dS + \int_{S_{f}^{-}}^{}{T^{f^{-}}\psi}\ dS - \int_{V}^{}{\rho\ddot{u}\ \psi}\ dV = 0\ \\ \end{array}\ (1)
\end{aligned}
\end{equation}

Where $\sigma$ is the stress tensor, $\overline{\sigma}$ is the damping stress tensor, $T$ is the external traction forces, $\psi$ is the testing function, $\rho$ is the density, $\ddot{u}$ is the acceleration.

The stress divergence term after integration by part $\sigma \cdot \nabla\psi$ (```TensorMechanics/Master```), the inertia term $\rho\ddot{u}$ (```InertiaForce```) and the stiffness proportional damping $q \overline{\sigma} \cdot \nabla \psi$ (```StiffPropDamping```) are integrated over the whole simulation domain $V$, while $T$ represents the surface tractions acting as external forces.

Importantly, traction $T^{f^{+}}$ on the upper fault surface $S_{f}^{+}$ and traction $T^{f^{-}}$ on the lower fault surface $S_{f}^{-}$ are handled through custom material objects, which will be explained in the next section. We thus neglect these two on-fault surface traction terms when constructing the residuals.

### Custom Kernel: StiffPropDamping

```StiffPropDamping``` is a custom kernel for adding stiffness proportional damping into the system to reduce the high-frequency oscillations. The weak form is expressed as follows:

\begin{equation}
\begin{aligned}
\begin{array}{r} q\int_{V}^{}{\overline{\sigma} \cdot \nabla\psi}dV (2) \end{array}
\end{aligned}
\end{equation}

Where $\overline{\sigma}$ is the damping stress tensor, $q$ is damping constant. To see how the damping term is introduced, the .h and .cpp file is provided below:

The header file explains its inherence relation with its parent class ```StressDivergenceTensors```, which is introduced earlier.

!listing farmsquakeworx/include/kernels/StiffPropDamping.h
         caption=StiffPropDamping: Input File

The source file implements the weak form evaluation at each quadrature point, here we follow similar definition of damping stress tensor given in [!cite](Day_Dalguer_Lapusta_Liu_2005) , Appendix A8:

\begin{equation}
\begin{aligned}
\begin{array}{r} \overline{\sigma} = \Delta t\left\lbrack \frac{\sigma_{t} - \sigma_{t - \Delta t}}{\Delta t} \right\rbrack = \left\lbrack \sigma_{t} - \sigma_{t - \Delta t} \right\rbrack (3)\end{array}
\end{aligned}
\end{equation}

Where $\sigma_{t}$ and $\sigma_{t - \Delta t}$ are stress tensor from current/last time step.

### Custom Userobject: ResidualEvaluationUserObject

To obtain the most up-to-date restoration force from ```StressDivergenTensors``` kernel, a custom ```Tagging UserObject``` is set up to retrieve them after the system solve. MOOSE provides such a system to easily obtain solution or restoration force vector/matrix, please refer to [the tagging documentation](TaggingInterface.md) for more information. Here, we define a custom UserObject ```ResidualEvaluationUserObject``` inherited from ```GeneralUserObject``` to obtain the stress divergence term $\begin{array}{r} \int_{V}^{}{\sigma \cdot \nabla\psi}\ dV(2) \end{array}$ evaluated at each quadrature point, the header and source file is presented below.

!listing farmsquakeworx/include/userobjects/ResidualEvaluationUserObject.h
caption=ResidualEvaluationUserObject: Header File*

!listing farmsquakeworx/src/userobjects/ResidualEvaluationUserObject.C
caption=ResidualEvaluationUserObject: Source File*

To execute the ```ResidualEvaluationUserObject```, in the input file we add the following code block:

!listing farmsquakeworx/examples/ratestate3D/ratestate3D_main.i
         block=Problem
         id=input-block-1
         caption=Problem: Input File

This allocates the tag vector. The tag vector needs to link with the action block ```[TensorMechanics]```, which automatically set up stress divergence term:

!listing farmsquakeworx/examples/ratestate3D/ratestate3D_main.i
         block=Modules
         id=input-block-2
         caption=Add "extra_vector_tags" in the Action `[TensorMechanics]`: Input File

```ResidualEvaluationUserObject``` is called in ```[UserObjects]```:

!listing farmsquakeworx/examples/ratestate3D/ratestate3D_main.i
         block=UserObjects
         id=input-block-3
         caption=UserObject: Input File

The block executes ```ResidualEvaluationUserObject``` at ```TIMESTEP_END``` but before the execuation of ```[AuxKernels]```. After retrieving the force vector, in the ```[AuxKernels]```, we assign it to pre-defined restoration force aux variable using ```TagVectorAux```:

!listing examples/ratestate3D/ratestate3D_main.i
         block=AuxKernels
         id=input-block-4
         caption=TagVectorAux: Input File

Here ```v``` is primary variable name ```disp_x, disp_y, disp_z``` and ```variable``` accepts aux variable. As mentioned before, these operation happens only after the latest restoration force is obtained through ```ResidualEvaluationUserObject```.
Then the variable ```resid_x, resid_y, resid_z``` will pass stored value to ```resid_slipweakening_x, resid_slipweakening_y, resid_slipweakening_z``` at the beginning of next time step, the later ones then feed into material kernel to ensure the time consistency of retreiving quantities.

### Rate-and-State Friction Implementation

This section explains the basic idea of MOOSE implementation of rate-and-state friction law. It utilizes ```MultiApps``` to arrange the process as follows: in the ```Main App``` after solving the weak form of system equations, we retrieve the residual vector of stress divergence term and pass it into the ```Sub App```. In the ```Sub App```, we have rate-and-state friction law which basically equates stress with strength, it is implemented in ```Material Object```. It uses residual vector as input, displacement prediction for the next time step as output. These displacement prediction values along either the primary or secondary interface are stored as ```Material Property``` and retrieved by the ```Interface Kernel```, such that it can be placed along the interfaces. The residual of the ```Interface Kernel``` is essentially the displacement times fault area. The displacement at the interfaces is thus the residual values divided by the fault area. Once we obtain the prescribed displacement values at the interfaces, we pass it back to ```Main App``` and enforce as boundary condition for the next time step calculation of the weak form.

!media media/examples/ratestate/ratestate_flowchart.jpg
       id=rate state flow chart
       caption= rate-and-state implementation flow chart
       style=width:100%;padding:20px;

### Custom Material Object : RateStateFrictionLaw3D

Inherit from cohesive zone model, we define the following files:
```CZMComputeLocalTractionBaseRSF3D```, ```CZMComputeLocalTractionTotalBaseRSF3D```,```RateStateFrictionLaw3D```. 

```CZMComputeLocalTractionBaseRSF3D``` is the base file which initializes material properties that will be updated in ```RateStateFrictionLaw3D```. Important quantities like velocity, displacement in strike, normal, dip direction on either interface; slip, slip rate, traction in strike, normal, dip direction and state variable. 

```CZMComputeLocalTractionTotalBaseRSF3D``` inherits from ```CZMComputeLocalTractionBaseRSF3D```.

```RateStateFrictionLaw3D``` inherits ```CZMComputeLocalTractionTotalBaseRSF3D``` and it is the object that implement the algorithm. We summarize the solving procedure as follows, please refer to [!cite](luo2018dynamics) Appendix A for detailed explanations:

(1) Compute local restoration force $R$

\begin{equation}
\begin{aligned}
\begin{array}{r} R^{l,\pm}_i(t) = R^T_{rot} R^{g,\pm}_i(t)
\end{array}
\end{aligned}
\end{equation}

Where $l,g$ indicates quantities in local or global coordinate, $R_{rot}$ is the rotation matrix for coordinate transformation. $i=s,n,d$ are three directions (strike, normal, dip) respectively. Here we add the contributions of stress divergence term and the damping term:

\begin{equation}
\begin{aligned}
\begin{array}{r} R^{l,\pm}_i(t) = R^{l,sts,\pm}_i(t) + R^{l,damp,\pm}_i(t) 
\end{array}
\end{aligned}
\end{equation}

!listing id=ratestate1 caption=RateStateFrictionLaw3D: Source File. language=cpp
//Restoration Force
//Stress Divergence Components (label as stsdivcomp)
//--------------------------------------------------------------------------------------------------//
//Define in global coordinate
//current time step 
RealVectorValue R_plus_global_stsdivcomp(-_reaction_rsf_x[_qp],-_reaction_rsf_y[_qp], -_reaction_rsf_z[_qp]);
RealVectorValue R_minus_global_stsdivcomp(-_reaction_rsf_neighbor_x[_qp],-_reaction_rsf_neighbor_y[_qp], -_reaction_rsf_neighbor_z[_qp]);
//Rotate in local coordinate
//current time step
RealVectorValue R_plus_local_stsdivcomp = _rot[_qp].transpose() * R_plus_global_stsdivcomp;
RealVectorValue R_minus_local_stsdivcomp = _rot[_qp].transpose() * R_minus_global_stsdivcomp;
//Get Components
//current time step
Real R_plus_local_normal_stsdivcomp  = R_plus_local_stsdivcomp(0);
Real R_plus_local_strike_stsdivcomp  = R_plus_local_stsdivcomp(1);
Real R_plus_local_dip_stsdivcomp     = R_plus_local_stsdivcomp(2);
Real R_minus_local_normal_stsdivcomp = R_minus_local_stsdivcomp(0);
Real R_minus_local_strike_stsdivcomp = R_minus_local_stsdivcomp(1);
Real R_minus_local_dip_stsdivcomp    = R_minus_local_stsdivcomp(2);
//--------------------------------------------------------------------------------------------------//
//Damping Components Contribution (label as dampingcomp)
///Define in global coordinate
//current time step 
RealVectorValue R_plus_global_dampingcomp(-_reaction_damp_x[_qp],-_reaction_damp_y[_qp], -_reaction_damp_z[_qp]);
RealVectorValue R_minus_global_dampingcomp(-_reaction_damp_neighbor_x[_qp],-_reaction_damp_neighbor_y[_qp], -_reaction_damp_neighbor_z[_qp]);
///Rotate in local coordinate
//current time step
RealVectorValue R_plus_local_dampingcomp = _rot[_qp].transpose() * R_plus_global_dampingcomp;
RealVectorValue R_minus_local_dampingcomp = _rot[_qp].transpose() * R_minus_global_dampingcomp;
///Get Components
//current time step
Real R_plus_local_normal_dampingcomp  = R_plus_local_dampingcomp(0);
Real R_plus_local_strike_dampingcomp  = R_plus_local_dampingcomp(1);
Real R_plus_local_dip_dampingcomp     = R_plus_local_dampingcomp(2);
Real R_minus_local_normal_dampingcomp = R_minus_local_dampingcomp(0);
Real R_minus_local_strike_dampingcomp = R_minus_local_dampingcomp(1);
Real R_minus_local_dip_dampingcomp    = R_minus_local_dampingcomp(2);
//--------------------------------------------------------------------------------------------------//
//Add restoration forces from two contributions
Real R_plus_local_normal  = R_plus_local_normal_stsdivcomp  + R_plus_local_normal_dampingcomp;
Real R_plus_local_strike  = R_plus_local_strike_stsdivcomp  + R_plus_local_strike_dampingcomp;
Real R_plus_local_dip     = R_plus_local_dip_stsdivcomp     + R_plus_local_dip_dampingcomp;
Real R_minus_local_normal = R_minus_local_normal_stsdivcomp + R_minus_local_normal_dampingcomp;
Real R_minus_local_strike = R_minus_local_strike_stsdivcomp + R_minus_local_strike_dampingcomp;  
Real R_minus_local_dip    = R_minus_local_dip_stsdivcomp    + R_minus_local_dip_dampingcomp;
//--------------------------------------------------------------------------------------------------//

(2) Compute nodal mass

\begin{equation}
\begin{aligned}
\begin{array}{r} M^{\pm} = \rho \frac{(\text{len})^3}{2} 
\end{array}
\end{aligned}
\end{equation}

Where $\rho$ is the density of material, $a$ is the element side (assume hex element).

!listing id=ratestate2 caption=RateStateFrictionLaw3D: Source File. language=cpp
//Nodal Mass
//HEX8 Element
Real M = _density[_qp] * len * len * len * 0.5;

(3) Extract old/older quantities stored as material properties in ```CZMComputeLocalTractionBaseRSF3D```.

(4) Compute trial normal traction and normal traction

\begin{equation}
\begin{aligned}
\begin{array}{r} 
\widetilde{T_n} = \frac{\Delta t ^ {-1} M^{+} M^{-}[(t-\frac{\Delta t}{2} + \Delta t^{-1} \delta^l_n(t))]+M^{-}R^{+}_n-M^{+}R^{+}_n}{(\text{len})(M^{+} + M^{-})} + T_n^o
\end{array}
\end{aligned}
\end{equation}

Where $\Delta t$ is the time step, $\delta^l_n(t)$ is the slip along the normal (n) direction, $T_n^o$ is the initial normal stress value, $M^{\pm}$ represents the nodal mass on the plus side or minus side of the interface. We assume zero traction if the fault opens.

!listing id=ratestate3 caption=RateStateFrictionLaw3D: Source File. language=cpp
//Compute Trial Normal Traction and Normal Traction
Real Tn_trial = ( -1.0 * (1.0/_dt) * M * M * ( sliprate_normal_tminusdtover2 + (1.0/_dt) * slip_normal_t) ) / ( len_len * (M + M) ) + ( M * R_minus_local_normal - M * R_plus_local_normal ) / ( len_len * (M + M) ) - Tn_o;
if (Tn_trial<0)
{
    Tn = Tn_trial;
}else{
    Tn = 0;
}
//Make Tn positive
Tn = abs(Tn);

(5) Compute trial shear traction 

\begin{equation}
\begin{aligned}
\begin{array}{r} 
\widetilde{T}_i = T_i^o + \frac{(M^+ M^-)\dot{\delta}_i^l (t-\frac{\Delta t}{2})}{(\text{len})\Delta t(M^+ + M^-)} + \frac{M^- R_i^+ (t) - M^+ R_i^- (t)}{(\text{len})(M^+ + M^-)}
\end{array}
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
\begin{array}{r} 
\widetilde{T}_s =  \widetilde{T}_s + T_s^{perturb}
\end{array}
\end{aligned}
\end{equation}

Where $i=s,d$ for strike and dip directions. $T_i^o$ is the initial shear stress. $T_s^{perturb}$ is the shear perturbation applied along the strike direction. We then compute the trial traction magnitude along the strike-slip plane:

\begin{equation}
\begin{aligned}
\begin{array}{r} 
\widetilde{T}_{mag} = \sqrt{\widetilde{T}_s ^ 2 + \widetilde{T}_d ^ 2}
\end{array}
\end{aligned}
\end{equation}

!listing id=ratestate4 caption=RateStateFrictionLaw3D: Source File. language=cpp
//Compute Trial Shear Traction Along Strike Direction at Current Time Step
Real Ts_trial = ( M * M * sliprate_strike_tminusdtover2 )/( len_len * _dt * (M + M) ) + (M * R_plus_local_strike - M * R_minus_local_strike) / ( len_len * ( M + M ) ) + Ts_o + Ts_perturb;
Real Td_trial = ( M * M * sliprate_dip_tminusdtover2    )/( len_len * _dt * (M + M) ) + (M * R_plus_local_dip    - M * R_minus_local_dip   ) / ( len_len * ( M + M ) ) + Td_o;
Real Tmag_trial = sqrt(Ts_trial*Ts_trial+Td_trial*Td_trial);

(6) Solve the nonlinear equation to find slip rate at $t+\Delta t$

Form the residual by equating the shear strength with shear stress:

\begin{equation}
\begin{aligned}
\begin{array}{r} 
\tau = \mu(\dot{\delta},\theta)\sigma_n
\end{array}
\end{aligned}
\end{equation}

The friction coefficient $\mu$ is the a function of slip rate and state variable $\theta$, which follows the form:

\begin{equation}
\begin{aligned}
\begin{array}{r} 
\mu = a \hspace{1mm} arcsinh[\frac{\dot{\delta}}{2\delta_o}exp(\frac{f_o+bln( \frac{\dot{\delta} \theta}{L})}{a})]
\end{array}
\end{aligned}
\end{equation}

Here $a,b,L,f_o$ are constant frictional coefficients, $\delta_o$ is constant reference slip.

Combine the definitions given above, the residual form is given as follows:

\begin{equation}
\begin{aligned}
\begin{array}{r} 
residual = \dot{\delta}_i(t+\frac{\Delta t}{2}) + c \sigma_n a \hspace{1mm} asinh( 0.5(\dot{\delta}_i(t+\frac{\Delta t}{2}) + \dot{\delta}_i(t-\frac{\Delta t}{2})) Z) - c \widetilde{T}_{mag} = 0
\end{array}
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
\begin{array}{r} 
Z = \frac{1}{2 \delta_o} exp(\frac{f_o + b log( \frac{\delta_o \theta(t)}{L} )}{a})
\end{array}
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
\begin{array}{r} 
c = \frac{(len)^2 dt (M^+ + M^-)}{M^+ M^-}
\end{array}
\end{aligned}
\end{equation}

We setup a while loop and use Newton's solver to solve for unknown slip rate $\dot{\delta}(t+\frac{\Delta t}{2})$.

!listing id=ratestate5 caption=RateStateFrictionLaw3D: Source File. language=cpp
//const
Real c = len_len * _dt * ( M + M ) / (M * M);
Real Z = 0.5 / delta_o * exp((f_o + rsf_b * log(delta_o * statevar_t/rsf_L))/rsf_a);    
//Setup while loop
Real iterr = 1;
Real max_iter = 10000;
Real er = 1;
Real solution; 
Real guess_i = abs(sliprate_mag_tminusdtover2); //slip rate at time t-dt/2
Real residual;
Real jacobian;
Real guess_j;
while ( er > 1e-10 && iterr < max_iter ){  
    //Compute Residual
    residual = guess_i + c * Tn * rsf_a * asinh( 0.5*(guess_i+sliprate_mag_tminusdtover2) * Z ) - c * Tmag_trial;
    //Compute Jacobian
    jacobian = 1.0 + c * Tn * rsf_a * 0.5 * Z / sqrt( 1.0 + 0.5 * 0.5 * (guess_i+sliprate_mag_tminusdtover2) * (guess_i+sliprate_mag_tminusdtover2) * Z * Z );
    //Compute New guess
    guess_j = guess_i - residual / jacobian;
    //save
    solution = guess_j;
    //Compute err
    er = abs(guess_j - guess_i)/abs(guess_j);
    //Update Old guess
    guess_i = guess_j;
    if (iterr == max_iter){
        std::cout<<"NOT CONVERGED!"<<std::endl;
    }
    //update iterr
    iterr = iterr + 1;
}

Real sliprate_mag_tplusdtover2 = abs(solution); 

(7) Update state variable $\theta(t+\Delta t)$

\begin{equation}
\begin{aligned}
\begin{array}{r} 
\theta(t+\Delta t) = \theta(t) A + \frac{L}{\dot{\delta}(t+\frac{\Delta t}{2})} ( 1 - A )
\end{array}
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
\begin{array}{r} 
A = exp(-\frac{\dot{\delta}(t+\frac{\Delta t}{2}) \Delta t}{L})
\end{array}
\end{aligned}
\end{equation}

!listing id=ratestate6 caption=RateStateFrictionLaw3D: Source File. language=cpp
//update state variable
Real coeffD = exp(-sliprate_mag_tplusdtover2*_dt/rsf_L);
Real statevar_tplusdt = statevar_t * coeffD + (rsf_L/sliprate_mag_tplusdtover2) * (1-coeffD);

(8) Update shear stress magnitude $T_{mag}$ at $t$ by averaging slip rate at $t-\frac{\Delta t}{2}$ and $t+\frac{\Delta t}{2}$:

\begin{equation}
\begin{aligned}
\begin{array}{r} 
T_{mag} = a T_n \hspace{1mm} asinh( 0.5(\dot{\delta}(t-\frac{\Delta t}{2}) + \dot{\delta}(t+\frac{\Delta t}{2})) Z ) 
\end{array}
\end{aligned}
\end{equation}

And we extract strike or dip direction component using trial values:

\begin{equation}
\begin{aligned}
\begin{array}{r} 
T_{s} = T_{mag} (\widetilde{T}_s/\widetilde{T}_{mag})
\end{array}
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
\begin{array}{r} 
T_{d} = T_{mag} (\widetilde{T}_d/\widetilde{T}_{mag})
\end{array}
\end{aligned}
\end{equation}

!listing id=ratestate7 caption=RateStateFrictionLaw3D: Source File. language=cpp
//Compute shear traction at time t
Real T_mag = Tn * rsf_a * asinh( 0.5*(sliprate_mag_tminusdtover2+sliprate_mag_tplusdtover2) * Z );
///Get Components
Ts = T_mag * ( Ts_trial / Tmag_trial );
Td = T_mag * ( Td_trial / Tmag_trial );

(9) Compute the displacement for $t + \Delta t$

We first compute the increment of displacement:

\begin{equation}
\begin{aligned}
\begin{array}{r} 
\Delta u_i^t = u_i^t - u_i^{t-\Delta t} + (\Delta t)^2 / M * ( R_i - (len)^2 (T_i - T_i^o)); \hspace{1mm} i = n,d
\end{array}
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
\begin{array}{r} 
\Delta u_s^t = u_s^t - u_s^{t-\Delta t} + (\Delta t)^2 / M * ( R_s - (len)^2 (T_s - T_s^o - T_s^{perturb}))
\end{array}
\end{aligned}
\end{equation}

We then add the increment to the displacement of $t - \Delta t$:

\begin{equation}
\begin{aligned}
\begin{array}{r} 
u_i^{t+\Delta t} = u_i^{t} + \Delta u_i^t
\end{array}
\end{aligned}
\end{equation}

!listing id=ratestate8 caption=RateStateFrictionLaw3D: Source File. language=cpp
//Compute quantities at time t + dt/2 or t + dt
//DISP
Real du_strike_plus_t  =  alongfaultdisp_strike_plus_t  - alongfaultdisp_strike_plus_tminust  + _dt * _dt / M * (R_plus_local_strike  - len_len * (Ts - Ts_o - Ts_perturb));
Real du_normal_plus_t  =  alongfaultdisp_normal_plus_t  - alongfaultdisp_normal_plus_tminust  + _dt * _dt / M * (R_plus_local_normal  - len_len * (Tn - Tn_o));
Real du_dip_plus_t     =  alongfaultdisp_dip_plus_t     - alongfaultdisp_dip_plus_tminust     + _dt * _dt / M * (R_plus_local_dip     - len_len * (Td - Td_o));
Real du_strike_minus_t =  alongfaultdisp_strike_minus_t  - alongfaultdisp_strike_minus_tminust + _dt * _dt / M * (R_minus_local_strike + len_len * (Ts - Ts_o - Ts_perturb));
Real du_normal_minus_t =  alongfaultdisp_normal_minus_t  - alongfaultdisp_normal_minus_tminust + _dt * _dt / M * (R_minus_local_normal + len_len * (Tn - Tn_o));
Real du_dip_minus_t    =  alongfaultdisp_dip_minus_t     - alongfaultdisp_dip_minus_tminust    + _dt * _dt / M * (R_minus_local_dip    + len_len * (Td - Td_o));
//
Real alongfaultdisp_strike_plus_tplusdt  = alongfaultdisp_strike_plus_t  + du_strike_plus_t;
Real alongfaultdisp_normal_plus_tplusdt  = alongfaultdisp_normal_plus_t  + du_normal_plus_t;
Real alongfaultdisp_dip_plus_tplusdt     = alongfaultdisp_dip_plus_t     + du_dip_plus_t;
Real alongfaultdisp_strike_minus_tplusdt = alongfaultdisp_strike_minus_t + du_strike_minus_t;
Real alongfaultdisp_normal_minus_tplusdt = alongfaultdisp_normal_minus_t + du_normal_minus_t;
Real alongfaultdisp_dip_minus_tplusdt    = alongfaultdisp_dip_minus_t    + du_dip_minus_t;

(10) Compute slip rate at $t + \frac{\Delta t}{2}$, slip at $t + \Delta t$

\begin{equation}
\begin{aligned}
\begin{array}{r} 
\dot{ \delta_i }(t + \frac{\Delta t}{2}) = \dot{ \delta }(t + \frac{\Delta t}{2}) (\widetilde{T}_i / \widetilde{T}_{mag} ); \hspace{1mm} i = s,d
\end{array}
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
\begin{array}{r} 
\dot{ \delta_n }(t + \frac{\Delta t}{2}) = ( \delta_n(t + \Delta t) - \delta_n(t) ) / \Delta t; \hspace{1mm}
\end{array}
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
\begin{array}{r} 
\delta_i (t + \Delta t) = \delta_i (t) + \dot{ \delta_i }(t + \frac{\Delta t}{2}) \Delta t; \hspace{1mm} i = s,d
\end{array}
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
\begin{array}{r} 
\delta_n (t + \Delta t) = u_n^{t+\Delta t, +} - u_n^{t+\Delta t, -}
\end{array}
\end{aligned}
\end{equation}

!listing id=ratestate9 caption=RateStateFrictionLaw3D: Source File. language=cpp
//Update Slip Rate and Slip at t + dt/2 or t + dt
//Slip Rate
Real sliprate_strike_tplusdtover2 = sliprate_mag_tplusdtover2 * ( Ts_trial / Tmag_trial );
Real sliprate_normal_tplusdtover2 = ( alongfaultdisp_normal_plus_tplusdt - alongfaultdisp_normal_plus_t ) / _dt - ( alongfaultdisp_normal_minus_tplusdt - alongfaultdisp_normal_minus_t ) / _dt;
Real sliprate_dip_tplusdtover2    = sliprate_mag_tplusdtover2 * ( Td_trial / Tmag_trial );
//Slip
Real slip_strike_tplusdtover2 = slip_strike_t + sliprate_strike_tplusdtover2 * _dt;
Real slip_normal_tplusdtover2 = alongfaultdisp_normal_plus_tplusdt - alongfaultdisp_normal_minus_tplusdt;
Real slip_dip_tplusdtover2    = slip_dip_t + sliprate_dip_tplusdtover2 * _dt;

(11) We update the tracked quantities with computed new values.

### Custom Interface Kernel : RateStateInterfaceKernelGlobalx (y,z)

The computed displacements along either primary or secondary interface are by default stored in the primary side of the cohesive zone interfaces. To enforce the displacements on both sides, we need interface kernel which could handle both sides of the interface.

The idea is simple, since computed displacement values from the material object in the previous side is stored as material property, we are able to call it in the interface kernel and enforce it on either primary side (```MOOSE:Element```) or secondary side (```MOOSE:Neighbor```). The code snippet is provided below.

!listing farmsquakeworx/include/interfacekernels/ratestate/RateStateInterfaceKernelGlobalx.h
caption=RateStateInterfaceKernelGlobalx: Source File*

!listing farmsquakeworx/src/interfacekernels/ratestate/RateStateInterfaceKernelGlobalx.C
caption=RateStateInterfaceKernelGlobalx: Source File*

### Custom Auxkernel: ScalarVarAux

The evaluations of the interface kernels will have to intergrate a constant value (that we provided) over the domain, which is essentially the constant value times the area of the domain. To get the values on either side, we could feed the residuals (same idea as before, use ```ResidualEvaluationUserObject``` to extract the restoration forces) into the aux kernel, which returns the values divided by the domain area, we thus obtain the displacements we would like to enforce on the interfaces.

!listing farmsquakeworx/include/auxkernels/ratestate/ScaleVarAux.h
caption=RateStateInterfaceKernelGlobalx: Source File*

!listing farmsquakeworx/src/auxkernels/ratestate/ScaleVarAux.C
caption=RateStateInterfaceKernelGlobalx: Source File*

Then the displacements are passed into ```Main App```, and feed into a weakly enforced BC (```MatchedValueBC```), which completes one time step evaluation.

## Example : TPV101-2D

The example is taken from South California Earthquake Center (SCEC) benchmark problem [!cite](Harris_Barall_Archuleta_Dunham_Aagaard_Ampuero_Bhat_Cruz-Atienza_Dalguer_Dawson) for dynamic rupture using rate-and-state friction law and aging law. To reduce the computational cost, we restrict our focus on 2D verison of the benchmark problem and use ```uguca``` code [!cite](kammer2021uguca) for verification.

### Geometry

The mesh is a square domain with length 20km, which is separated into upper and lower blocks using cohesive zone elements. We use 800 elements to resolve in each direction. We use MOOSE built-in function to build the mesh:

!listing farmsquakeworx/examples/ratestate2D/ratestate2D_main.i
         block=Mesh
         id=input-block-6
         caption=Mesh: Input File

### Parameter Table

We use the same parameters in TPV101 benchmark, we summarize the important values below:

!table id=table1 caption=Simulation Parameter Table
| Variable                                 | Value                                   | Description                |
|------------------------------------------|-----------------------------------------|----------------------------|
| $\mathbf{\rho}$                        | 2670 $kg/m^{3}$                         | Density                    |
| $\mathbf{\lambda = \mu}$               | 32.04 $GPa$                             | Lame Parameters            |
| $\mathbf{T}_{\mathbf{n}}^{\mathbf{o}}$ | 120 $MPa$                               | Initial Background Normal Stress   |
| $\mathbf{T}_{\mathbf{s}}^{\mathbf{o}}$ | 75 $MPa$                                | Initial Background Shear Stress    |
| $\mathbf{f}_{\mathbf{o}}$              | 0.4 $m$                                 | Rate-and-state coefficient      |
| $\mathbf{a}$                           | 0.008 $m$                               | Rate-and-state coefficient      |
| $\mathbf{b}$                           | 0.012 $m$                               | Rate-and-state coefficient      |
| $\mathbf{L}$                           | 0.02 $m$                                | Rate-and-state coefficient      |
| $\mathbf{\delta_o}$                    | $10^{-6}$ $m$                           | Rate-and-state coefficient      |
| $\mathbf{V}_{\mathbf{ini}}$            | $10^{-12}$ $m/s$                        | Initial Slip Rate  |
| $\mathbf{\theta}_{\mathbf{ini}}$       | $1.606238999213454 \times 10 ^ 9$ $s$   | Initial State Variable |
| $\mathbf{\mu}_{\mathbf{d}}$            | 0.525                                   | Dynamic Friction Parameter |
| $\mathbf{\Delta}\mathbf{x}$            | 100 m                                   | Mesh Size                  |

The nucleation is placed in the center $(0,0)$ follows the spatial and temporal distribution of strike shear stress perturbation given as follows:

\begin{equation}
\begin{aligned}
F(r,R) = exp(\frac{r^2}{r^2-R^2})
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
G(t,T) = exp(\frac{(t-T)^2}{t(t-2T)}); 0 < t < T
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
G(t,T) = 1; t > T
\end{aligned}
\end{equation}

\begin{equation}
\begin{aligned}
T = T_{perturb} F(r,R) G(t,T)
\end{aligned}
\end{equation}

Where $r = \sqrt{(x - x_o)^2}$, $x_o$ is the center of the perturbation, $T_{perturb} = 25 \times 10 ^ 6$ is the peak perturbation shear stress value at that location. 

In the code, we place the parameters in the ```Sub App```:

!listing farmsquakeworx/examples/ratestate2D/ratestate2D_sub.i
         block=GlobalParams
         id=input-block-7
         caption=Mesh: Input File

### Results

In the results section, we report the time history of slip, slip rate for a sets of points along the planar fault, and compare the results with ```uguca```.

!media media/examples/ratestate/sliprateslip.jpg
       id=rate state time history
       caption= Selected slip rate and slip time history for location 0km, 2.5km, 7.5km along the fault for SCEC Benchmark TPV101(Red lines are solution from uguca-2d, blue lines are from MOOSE implementation, the mesh size is 50m in both cases).
       style=width:100%;padding:20px;

## Bibliography

!bibtex bibliography
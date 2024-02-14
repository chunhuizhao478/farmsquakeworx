# InitialStrikeShearStressPerturbRSF3D

!syntax description /Functions/InitialStrikeShearStressPerturbRSF3D

## Description

Generate spatial and temporal distribution of strike shear stress perturbation:

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
T = T_o * F(r,R) * G(t,T)
\end{aligned}
\end{equation}

Where $r = \sqrt{(x - x_o)^2 + (z - z_o)^2}$, $x_o$ is the center of the perturbation along the x (strike) direction, $z_o$ is the center of the perturbation along the z (dip) direction, $T_o$ is the peak perturbation shear stress value at that location. 

## Example Input File Syntax

!! Describe and include an example of how to use the InitialStrikeShearStressPerturbRSF3D object.

!syntax parameters /Functions/InitialStrikeShearStressPerturbRSF3D

!syntax inputs /Functions/InitialStrikeShearStressPerturbRSF3D

!syntax children /Functions/InitialStrikeShearStressPerturbRSF3D

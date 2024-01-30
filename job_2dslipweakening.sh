#!/bin/bash
#SBATCH --job-name="2dslipweakening"
#SBATCH --output="2dslipweakening.%j.%N.out"
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=2
#SBATCH --mem=2G
#SBATCH --account=ddp408
#SBATCH -t 00:01:00

mpirun -n 2 /home/czhao1/farmsquakeworx/farmsquakeworx-opt -i /home/czhao1/farmsquakeworx/examples/2d_slipweakening/tpv2052D.i
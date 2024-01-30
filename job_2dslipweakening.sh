#!/bin/bash
#SBATCH --job-name="2dslipweakening"
#SBATCH --output="2dslipweakening.%j.%N.out"
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=2
#SBATCH --mem=2G
#SBATCH --account=ddp408
#SBATCH --export=ALL
#SBATCH -t 00:10:00

module load gcc/10.2.0 python/3.8.12 py-virtualenv/16.7.6 py-pip/21.1.2 openmpi/4.1.3
export CC=mpicc CXX=mpicxx FC=mpif90 F90=mpif90 F77=mpif77 MOOSE_JOBS=6 METHODS=opt METHOD=opt
make -j $MOOSE_JOBS
mpirun -n 2 /home/czhao1/farmsquakeworx/farmsquakeworx-opt -i /home/czhao1/farmsquakeworx/examples/2d_slipweakening/tpv2052D.i
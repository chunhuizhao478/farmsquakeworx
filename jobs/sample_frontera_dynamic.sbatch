#!/bin/bash
#SBATCH -J case1_static_solve        # Job name
#SBATCH -o case1_static_solve.o%j    # Name of stdout output file
#SBATCH -e case1_static_solve.e%j    # Name of stderr error file
#SBATCH -p development          # Queue (partition) name
#SBATCH -N 4              # Total # of nodes
#SBATCH -n 160             # Total # of mpi tasks
#SBATCH -t 02:00:00        # Run time (hh:mm:ss)
#SBATCH --mail-type=all    # Send email at begin and end of job
#SBATCH -A EAR20006        # Project/Allocation name (req'd if you have more than 1)
#SBATCH --mail-user=chunhui3@illinois.edu

# Load necessary modules
module swap intel gcc
#module swap impi mvapich2-x
module load cuda
export CXXFLAGS=-I/opt/apps/gcc/9.1.0/include/c++/9.1.0/
export CC=mpicc CXX=mpicxx FC=mpif90 F90=mpif90 F77=mpif77

# Set compilers and flags
export CC=mpicc
export CXX=mpicxx
export FC=mpif90
export F90=mpif90
export F77=mpif77

export CXXFLAGS=-I/opt/apps/gcc/9.1.0/include/c++/9.1.0/
export CC=mpicc CXX=mpicxx FC=mpif90 F90=mpif90 F77=mpif77

# Enable MPI debugging
export MV2_DEBUG=1
export MV2_SHOW_ENV_INFO=1

export MOOSE_JOBS=6 METHODS=opt

ibrun -n 1 /scratch2/10024/zhaochun/projects/farmsquakeworx_04022026/farmsquakeworx-opt -i /scratch2/10024/zhaochun/projects/farmsquakeworx_04022026/applications/dynamiccdbm_f_app/3d_damagebreakage_case1/dynamic_solve/dynamic_solve.i --split-mesh 160 --split-file /scratch2/10024/zhaochun/projects/farmsquakeworx_04022026/applications/dynamiccdbm_f_app/3d_damagebreakage_case1/dynamic_solve/foo.cpr --allow-unused
ibrun /scratch2/10024/zhaochun/projects/farmsquakeworx_04022026/farmsquakeworx-opt -i /scratch2/10024/zhaochun/projects/farmsquakeworx_04022026/applications/dynamiccdbm_f_app/3d_damagebreakage_case1/dynamic_solve/dynamic_solve.i --use-split --split-file /scratch2/10024/zhaochun/projects/farmsquakeworx_04022026/applications/dynamiccdbm_f_app/3d_damagebreakage_case1/dynamic_solve/foo.cpr --allow-unused

#!/bin/bash
#SBATCH --job-name="multifaults_run"
#SBATCH --output="multifaults_run.%j.%N.out"
#SBATCH --error="multifaults_run.%j.%N.err"
#SBATCH --partition=compute
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=50
##SBATCH --mem=2000M
#SBATCH --account=usc143
#SBATCH --export=ALL
#SBATCH -t 48:00:00

module purge
module load DefaultModules
module load anaconda3/2021.05

eval "$(conda shell.bash hook)"
conda activate /expanse/projects/qstore/usc143/qwxdev/apps/expanse/rocky8.8/moose_versions/farmsquakeworx_dynamicelastic2c15419/pythonenv

python3 /expanse/projects/qstore/usc143/qwxdev/apps/expanse/rocky8.8/moose_versions/farmsquakeworx_dynamicelastic2c15419/applications/dynamicelastic_app/generate_multifault.py /expanse/projects/qstore/usc143/qwxdev/apps/expanse/rocky8.8/moose_versions/farmsquakeworx_dynamicelastic2c15419/applications/dynamicelastic_app/config/example_config_multifault.json

module load gcc/10.2.0 python/3.8.12 py-virtualenv/16.7.6 py-pip/21.1.2 openmpi/4.1.3
export CC=mpicc CXX=mpicxx FC=mpif90 F90=mpif90 F77=mpif77 MOOSE_JOBS=6 METHODS=opt METHOD=opt

mpirun -np 100 ./farmsquakeworx-opt -i applications/dynamicelastic_app/2d_slipweakening_multifaults/multifault_2d.i

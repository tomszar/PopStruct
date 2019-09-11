#!/bin/bash -l
#PBS -N RemoveLowCounts
#PBS -l walltime=48:00:00
#PBS -l nodes=1:ppn=5
#PBS -l pmem=32gb
#PBS -j oe
#PBS -A jlt22_b_g_sc_default

#Working Dir
cd $PBS_O_WORKDIR

#Activate conda env
conda activate py

python Dendro_to_Mat.py

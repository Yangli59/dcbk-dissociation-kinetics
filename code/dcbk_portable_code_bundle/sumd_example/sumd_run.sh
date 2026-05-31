#!/bin/bash
#$ -S /bin/bash
#$ -l ngpus=1
#$ -q v100

#$ -cwd
#$ -e error
#$ -o output
#$ -N Amber_sumd

echo "Starting script at $(date)"
source /home/cudasoft/bin/startcuda.sh
source /home/soft/amber24/amber.sh
source /home/qiliu02/miniconda3/etc/profile.d/conda.sh
conda activate /home/qiliu02/miniconda3/envs/pyg-py36-cpu

python SuMD.py

echo "Ending script at $(date)"
source /home/cudasoft/bin/end_cuda.sh

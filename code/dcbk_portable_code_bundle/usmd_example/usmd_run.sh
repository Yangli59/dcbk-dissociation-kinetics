#!/bin/bash
#$ -S /bin/bash
#$ -l ngpus=1
#$ -q v100

#$ -cwd
#$ -e error
#$ -o outpt
#$ -N Amber_usmd

echo "Starting script at $(date)"
source /home/cudasoft/bin/startcuda.sh
source /home/soft/amber24/amber.sh
source /home/qiliu02/miniconda3/etc/profile.d/conda.sh
conda activate /home/qiliu02/miniconda3/envs/pyg-py36-cpu

./run_usmdprep.sh
./run_window_cuda.sh

echo "Ending script at $(date)"
source /home/cudasoft/bin/end_cuda.sh

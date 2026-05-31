#!/bin/bash
#$ -S /bin/bash
#$ -q lenovo
#$ -pe lenovo 1
#$ -cwd
#$ -e error
#$ -o output
#$ -N wham_run

source /home/qiliu02/miniconda3/etc/profile.d/conda.sh
conda activate /home/qiliu02/miniconda3/envs/pyg-py36-cpu

./run_wham.sh

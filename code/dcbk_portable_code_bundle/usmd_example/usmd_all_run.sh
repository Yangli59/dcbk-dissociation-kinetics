#!/bin/bash
#$ -S /bin/bash
#$ -l ngpus=1
#$ -q v100

#$ -cwd
#$ -e error
#$ -o outpt
#$ -N Amber_usmd

source /home/soft/amber24/amber.sh
echo "Using GPU device: $CUDA_VISIBLE_DEVICES"
source /home/cudasoft/bin/startcuda.sh
source /home/qiliu02/miniconda3/etc/profile.d/conda.sh
conda activate /home/qiliu02/miniconda3/envs/pyg-py36-cpu

original_dir=$(pwd)

for i in {1..4}; do
    dir="$original_dir/complex_md/lig${i}/exit_smd_rep"
    cd "$dir"     
    cp /home/yangli02/01Example_MD/usmd_example/* .  
    ./run_usmdprep.sh
    ./run_window_cuda.sh
    
    cp /home/yangli02/01Example_MD/wham_example/* .
    ./01_fix_dist.sh
    ./02_prepare_meta.sh
    ./03_run_wham.sh
    cd "$original_dir"
done

echo "Ending script at $(date)"
source /home/cudasoft/bin/end_cuda.sh

#!/bin/bash
# 主控脚本，不直接占用 GPU，只做准备和投递任务

set -e
echo "Starting main USMD script at $(date)"

source /home/soft/amber24/amber.sh
source /home/cudasoft/bin/startcuda.sh
source /home/qiliu02/miniconda3/etc/profile.d/conda.sh
conda activate /home/qiliu02/miniconda3/envs/pyg-py36-cpu

original_dir=$(pwd)
prev_jobid=""

for i in {1..4}; do
    dir="$original_dir/complex_md/lig${i}/exit_smd_rep"
    cd "$dir" || continue

    # 拷贝 USMD 模板文件并预处理
    cp /home/yangli02/01Example_MD/usmd_example/* .
    ./run_usmdprep.sh

    # 提交 GPU 任务（umbrella sampling）
    jobid=$(sbatch --parsable run_window_cuda.batch)

    # 串联 WHAM 分析，保证在 US 任务完成后才执行
    sbatch --dependency=afterok:$jobid run_wham.batch

    echo "Submitted lig${i} USMD with JobID $jobid"

    cd "$original_dir"
done

echo "Ending main USMD script at $(date)"
source /home/cudasoft/bin/end_cuda.sh

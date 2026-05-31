#!/bin/bash
#$ -S /bin/bash
#$ -l ngpus=1
#$ -q v100

# 检查是否提供了参数
if [ $# -eq 0 ]; then
    echo "错误: 请提供一个参数作为文件名前缀"
    exit 1
fi

target=$1  # 获取第一个命令行参数

#$ -cwd
#$ -e error
#$ -o outpt
#$ -N Amber_md_${target}  # 使用参数作为任务名的一部分

source /home/soft/amber24/amber.sh
echo "Using GPU device: $CUDA_VISIBLE_DEVICES"
source /home/cudasoft/bin/startcuda.sh
source /home/qiliu02/miniconda3/etc/profile.d/conda.sh
conda activate /home/qiliu02/miniconda3/envs/pyg-py36-cpu

# 使用参数构建完整的文件名
python FlexSim.py \
  -pro ${target}_protein.pdb \
  -lig ${target}_fragments.mol2 \
  -time 5

echo "Ending script at $(date)"

source /home/cudasoft/bin/end_cuda.sh
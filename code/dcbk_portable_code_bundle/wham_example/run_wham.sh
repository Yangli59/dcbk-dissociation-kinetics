#!/bin/bash
set -euo pipefail

echo "Starting WHAM workflow at $(date)"

# 当前目录就是每个 lig 的 exit_smd_rep

# 1. 修正距离或整理数据
if [ -x ./01_fix_dist.sh ]; then
    echo "Running 01_fix_dist.sh..."
    ./01_fix_dist.sh
else
    echo "Error: 01_fix_dist.sh not found or not executable"
    exit 1
fi

# 2. 准备 meta 数据
if [ -x ./02_prepare_meta.sh ]; then
    echo "Running 02_prepare_meta.sh..."
    ./02_prepare_meta.sh
else
    echo "Error: 02_prepare_meta.sh not found or not executable"
    exit 1
fi

# 3. 运行 WHAM
if [ -x ./03_run_wham.sh ]; then
    echo "Running 03_run_wham.sh..."
    ./03_run_wham.sh
else
    echo "Error: 03_run_wham.sh not found or not executable"
    exit 1
fi

echo "WHAM workflow finished at $(date)"

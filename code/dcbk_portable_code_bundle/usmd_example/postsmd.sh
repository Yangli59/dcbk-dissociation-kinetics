
source /home/qiliu02/miniconda3/etc/profile.d/conda.sh
conda activate /home/qiliu02/miniconda3/envs/pyg-py36-cpu
source /home/soft/amber24/amber.sh


# 轨迹处理脚本：每20帧保存一次并删除原文件
# 使用方法：将此脚本放在与comp_sol.prmtop和asmd.nc相同的目录下运行

# 检查必要的文件是否存在
if [ ! -f "comp_sol.prmtop" ]; then
    echo "错误: 找不到拓扑文件 comp_sol.prmtop"
    exit 1
fi

if [ ! -f "asmd.nc" ]; then
    echo "错误: 找不到轨迹文件 asmd.nc"
    exit 1
fi

# 创建cpptraj输入文件
cat > cpptraj.in <<EOF
parm comp_sol.prmtop
trajin asmd.nc 1 last 40  # 从第1帧开始，每20帧读取一次
trajout asmd_strided.nc netcdf
go
EOF

# 运行cpptraj处理轨迹
echo "正在处理轨迹文件..."
cpptraj -i cpptraj.in > cpptraj.log

# 检查处理是否成功
if [ ! -f "asmd_strided.nc" ]; then
    echo "错误: 处理失败，未生成asmd_strided.nc文件"
    exit 1
fi

# 获取处理前后的帧数信息
orig_frames=$(ncdump -h asmd.nc | grep "frame =" | awk '{print $3}')
new_frames=$(ncdump -h asmd_strided.nc | grep "frame =" | awk '{print $3}')

echo "处理完成!"
echo "原始轨迹帧数: $orig_frames"
echo "处理后轨迹帧数: $new_frames"
echo "压缩比例: 1:$(echo "scale=0; $orig_frames / $new_frames" | bc)"

# 删除原始轨迹文件
echo "正在删除原始轨迹文件 asmd.nc"
rm asmd.nc

# 清理临时文件
rm -f cpptraj.in cpptraj.log

echo "所有操作已完成!"
#!/bin/bash
input="asmd_strided.nc"
output="asmd_strided2.nc"
top="comp_sol.prmtop"
stride=2

# 检查输入文件
if [ ! -f "$input" ]; then
    echo "Error: $input 不存在"
    exit 1
fi

# 获取帧数（NetCDF 方法）
nframes=$(ncdump -h "$input" 2>/dev/null | grep -c "coordinates")

echo "$input has $nframes frames"

# 判断帧数是否大于 500
if [ "$nframes" -le 500 ]; then
    echo "帧数 <= 500，跳过抽帧"
    exit 0
fi

# 执行抽帧
cpptraj -p "$top" <<EOF
trajin $input 1 -1 $stride
trajout $output
go
EOF

if [ $? -eq 0 ] && [ -s "$output" ]; then
    mv -f "$output" "$input"
    echo "已更新 $input"
else
    echo "Error: $output 未生成或文件为空"
    rm -f "$output"
    exit 1
fi

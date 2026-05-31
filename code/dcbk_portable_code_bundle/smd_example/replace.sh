#!/bin/bash

# 显示当前内容
echo "当前配置:"
grep -E 'igr1|igr2' dist.example.RST

# 交互式输入新值
read -p "请输入新的 igr1 值（例如 1,2,3,4,）：" new_igr1
read -p "请输入新的 igr2 值（例如 52,94,110,）：" new_igr2

# 确认修改
read -p "确认将 igr1 修改为 '$new_igr1'，igr2 修改为 '$new_igr2' 吗？(y/n) " confirm

if [[ $confirm == [yY] ]]; then
    # 备份并修改文件
    sed -i.bak "s/^\(\s*igr1=\).*/\1$new_igr1/" dist.example.RST
    sed -i "s/^\(\s*igr2=\).*/\1$new_igr2/" dist.example.RST
    
    echo "修改完成，原文件已备份为 dist.example.RST.bak"
    echo "修改后内容:"
    grep -E 'igr1|igr2' dist.example.RST
else
    echo "已取消修改"
fi
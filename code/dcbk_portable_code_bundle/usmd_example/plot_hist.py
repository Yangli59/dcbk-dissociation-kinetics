import matplotlib.pyplot as plt
import numpy as np
import glob
import os

# 配置英文环境，使用系统默认字体
plt.rcParams['font.family'] = ['sans-serif']
plt.rcParams['axes.unicode_minus'] = False  # 确保负号显示

# 关闭字体警告
import warnings
warnings.filterwarnings("ignore", category=UserWarning, module="matplotlib")

# 获取所有数据文件
file_list = glob.glob('hist_*.dat')

if not file_list:
    print("Error: No hist_*.dat files found")
    exit(1)

# 创建绘图
plt.figure(figsize=(10, 6))

# 遍历文件并绘制
for file_path in file_list:
    try:
        with open(file_path, 'r') as f:
            data = []
            for line in f:
                # 彻底清洗数据行：
                # 1. 移除括号、换行符和所有空格
                # 2. 按逗号分割
                # 3. 转换为浮点数
                line = line.strip().replace('(', '').replace(')', '').replace(' ', '')
                if not line:
                    continue  # 跳过空行
                
                parts = line.split(',')
                if len(parts) != 2:
                    print(f"Warning: Invalid line format in {file_path}: {line}")
                    continue
                
                try:
                    x = float(parts[0])
                    y = float(parts[1])
                    data.append([x, y])
                except ValueError as ve:
                    print(f"Warning: Failed to convert values in {file_path}: {line} ({ve})")
        
        if not data:
            print(f"Warning: File {file_path} has no valid data")
            continue
        
        data = np.array(data)
        x, y = data.T
        plt.plot(x, y, linewidth=2, marker='o', markersize=4, alpha=0.8)
        
    except Exception as e:
        print(f"Warning: Failed to process {file_path} - {str(e)}")

# 英文图表设置
plt.title('Histogram Data Plot')
plt.xlabel('Distance (Å)')  # 更具体的X轴标签
plt.ylabel('Probability')   # 更具体的Y轴标签
plt.grid(True, linestyle='--', alpha=0.6)
plt.tight_layout()

# 保存图片
output_file = 'histograms.png'
plt.savefig(output_file, dpi=300, bbox_inches='tight')
plt.close()

print(f"Successfully saved plot to {output_file}")
#!/bin/bash

SUMMARY_FILE="./PMF/summary.txt"
PLOT_DIR="./PMF"
mkdir -p "$PLOT_DIR"

# 清空 SUMMARY_FILE，稍后按顺序写入内容
> "$SUMMARY_FILE"

# 函数：计算 ΔPMF
calc_delta_pmf() {
  local file="$1"
  awk '!/^#/ && $2 != "inf" {
    if ($1 >= 0 && $1 <= 8) {
      if (min1 == "" || $2 < min1) min1 = $2
    }
    if ($1 > 8 && $1 <= 25) {
      if (max2 == "" || $2 > max2) max2 = $2
    }
  } END {
    if (min1 != "" && max2 != "") printf "%.3f", (max2 - min1);
    else print "NA";
  }' "$file"
}

# ========== 1️⃣ 处理 SMILES 并写入第一行 ==========
smi_file=$(ls *.smi 2>/dev/null | head -n 1)
if [ -n "$smi_file" ]; then
  smiles_line=$(awk -F',' 'NR > 1 {print $1}' "$smi_file" | paste -sd "," -)
  echo "$smiles_line" > "$SUMMARY_FILE"
  echo "✅ SMILES written to first line of $SUMMARY_FILE from $smi_file"
else
  echo "⚠️ No .smi file found in current directory. Summary file will start with header."
  echo "# No SMILES found" > "$SUMMARY_FILE"
fi

# ========== 2️⃣ 写入表头 ==========
echo -e "Rep\tLig1\tLig2\tLig3\tLig4" >> "$SUMMARY_FILE"

# ========== 3️⃣ 收集 SMD 数据并复制 dat 文件 ==========
declare -A delta

for j in {1..3}; do          # rep
  for i in {1..4}; do        # lig
    SRC_FILE="./complex_md/lig${i}/exit_smd_rep${j}/plot.dat"
    DEST_FILE="${PLOT_DIR}/lig${i}_rep${j}_smd.dat"
    if [ -f "$SRC_FILE" ]; then
      cp "$SRC_FILE" "$DEST_FILE"
      DELTA_VAL=$(calc_delta_pmf "$DEST_FILE")
      delta["${j}_${i}"]="$DELTA_VAL"
    else
      delta["${j}_${i}"]="Not Found"
    fi
  done
done

# ========== 4️⃣ 按 rep 输出一行（lig1~lig4） ==========
for j in {1..3}; do
  line="$j"
  for i in {1..4}; do
    line="$line\t${delta["${j}_${i}"]}"
  done
  echo -e "$line" >> "$SUMMARY_FILE"
done

# ========== 5️⃣ 可选：单独保存 smiles_line.txt ==========
if [ -n "$smi_file" ]; then
  echo "$smiles_line" > "${PLOT_DIR}/smiles_line.txt"
  echo "✅ Also saved standalone smiles_line.txt"
fi

# ========== 6️⃣ 生成单个曲线图 (PNG) - 只针对 SMD ==========
for datfile in ${PLOT_DIR}/lig*_rep*_smd.dat; do
  if [ -f "$datfile" ] && [ -s "$datfile" ]; then
    if awk 'NF>=2 && $2!="inf" && $2!="nan" {valid=1; exit} END {exit !valid}' "$datfile"; then
      pngfile="${datfile%.dat}.png"
      title_label=$(basename "${datfile%.dat}")
      gnuplot <<- EOF
        set terminal pngcairo size 800,600 enhanced font 'Arial,14'
        set output '${pngfile}'
        set title 'PMF Curve: ${title_label}'
        set xlabel 'Distance (Å)'
        set ylabel 'PMF (kcal/mol)'
        set grid
        plot '${datfile}' using 1:2 with lines lw 2 lc rgb 'blue' title '${title_label}'
EOF
      echo "✅ Plot generated: ${pngfile}"
    else
      echo "⚠️ Skipping ${datfile}: no valid data points"
    fi
  else
    echo "⚠️ Skipping ${datfile}: file not found or empty"
  fi
done

# ========== 7️⃣ 生成汇总图 (所有 SMD 曲线叠加，PNG) ==========
combined_plot="${PLOT_DIR}/PMF_all_SMD.png"
valid_files=()
for f in ${PLOT_DIR}/lig*_rep*_smd.dat; do
  if [ -s "$f" ] && awk 'NF>=2 && $2!="inf" && $2!="nan" {valid=1; exit} END {exit !valid}' "$f"; then
    valid_files+=("$f")
  fi
done

if [ ${#valid_files[@]} -gt 0 ]; then
  plot_cmd="plot "
  for idx in "${!valid_files[@]}"; do
    f="${valid_files[$idx]}"
    title=$(basename "$f" .dat)
    if [ $idx -gt 0 ]; then
      plot_cmd="${plot_cmd}, "
    fi
    plot_cmd="${plot_cmd}'$f' using 1:2 with lines lw 2 title '$title'"
  done
  
  gnuplot <<- EOF
    set terminal pngcairo size 1000,700 enhanced font 'Arial,14'
    set output '${combined_plot}'
    set title 'All SMD PMF Curves'
    set xlabel 'Distance (Å)'
    set ylabel 'PMF (kcal/mol)'
    set grid
    ${plot_cmd}
EOF
  echo "✅ Combined SMD plot generated: ${combined_plot}"
else
  echo "⚠️ No valid SMD data files for combined plot"
fi

echo "🎉 All SMD PMF plots generated in ${PLOT_DIR}/ (PNG format)"
echo "📊 Summary written to ${SUMMARY_FILE} (SMD only, by replicate)"
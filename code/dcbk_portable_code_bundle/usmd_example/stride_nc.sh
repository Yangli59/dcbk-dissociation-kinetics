#!/bin/bash

top=comp_sol.prmtop

for d in dist*; do
  [ -d "$d" ] || continue
  echo "Processing $d"
  cd "$d" || exit

  for f in 06_Prod_comp_*.nc; do
    [ -f "$f" ] || continue

    # 用 cpptraj 读取轨迹并提取帧数
    nframes=$(cpptraj -p "../$top" <<EOF | grep "Read " | awk '{print $2}'
trajin $f
go
EOF
)

    echo "  $f has $nframes frames"

    # 判断是否为数字且大于 500
    if [[ "$nframes" =~ ^[0-9]+$ ]] && [ "$nframes" -gt 500 ]; then
      echo "  Striding $f (frames > 500)"
      tmp="${f%.nc}_stride.nc"

      cpptraj -p "../$top" <<EOF
trajin $f 1 -1 10
trajout $tmp
go
EOF
      mv "$tmp" "$f"
    else
      echo "  Skipping $f (frames <= 500)"
    fi
  done

  cd ..
done

# 删除 dist31.0 - dist35.0 文件夹（如果存在）
for d in dist{31..35}.0; do
  [ -d "$d" ] && { echo "Deleting $d"; rm -rf "$d"; }
done

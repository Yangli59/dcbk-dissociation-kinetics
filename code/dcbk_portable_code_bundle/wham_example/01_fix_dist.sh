#!/usr/bin/env bash
set -euo pipefail

: "${DCBK_US_WINDOW_START:=25.0}"
: "${DCBK_US_WINDOW_END:=1.0}"
: "${DCBK_US_WINDOW_STEP:=-1.0}"

for distance in $(seq "${DCBK_US_WINDOW_START}" "${DCBK_US_WINDOW_STEP}" "${DCBK_US_WINDOW_END}"); do
    cd "dist_${distance}"

    rm -f 02_heat_comp_*.nc 03_density_comp_*.nc 04_eq_comp_*.nc
    sed '1d' 06_Prod_dist.dat | awk '{print $1,"",$2}' > prod_dist.dat

    cd ..
done

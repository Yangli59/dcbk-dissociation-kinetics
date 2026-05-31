#!/usr/bin/env bash
set -euo pipefail

: "${DCBK_MD_ENGINE:=pmemd.cuda}"
: "${DCBK_US_WINDOW_START:=25.0}"
: "${DCBK_US_WINDOW_END:=1.0}"
: "${DCBK_US_WINDOW_STEP:=-1.0}"

prmtop="../comp_sol.prmtop"
name="comp"

for distance in $(seq "${DCBK_US_WINDOW_START}" "${DCBK_US_WINDOW_STEP}" "${DCBK_US_WINDOW_END}"); do
    mkdir -p "dist_${distance}"
    cd "dist_${distance}"

    cp ../COM_dist.RST .
    sed -i "s/DISTHERE/${distance}/g" COM_dist.RST

    "${DCBK_MD_ENGINE}" -O -i ../01_min.in -o "01_min_${name}_${distance}.out" -p "${prmtop}" -c "../frame_${distance}.rst" -r "01_min_${name}_${distance}.rst"
    "${DCBK_MD_ENGINE}" -O -i ../02_heat.in -o "02_heat_${name}_${distance}.out" -p "${prmtop}" -c "01_min_${name}_${distance}.rst" -r "02_heat_${name}_${distance}.rst" -x "02_heat_${name}_${distance}.nc" -ref "01_min_${name}_${distance}.rst"
    "${DCBK_MD_ENGINE}" -O -i ../03_density.in -o "03_density_${name}_${distance}.out" -p "${prmtop}" -c "02_heat_${name}_${distance}.rst" -r "03_density_${name}_${distance}.rst" -x "03_density_${name}_${distance}.nc" -ref "02_heat_${name}_${distance}.rst"
    "${DCBK_MD_ENGINE}" -O -i ../04_eq.in -o "04_eq_${name}_${distance}.out" -p "${prmtop}" -c "03_density_${name}_${distance}.rst" -r "04_eq_${name}_${distance}.rst" -x "04_eq_${name}_${distance}.nc" -ref "03_density_${name}_${distance}.rst"
    "${DCBK_MD_ENGINE}" -O -i ../06_Prod.in -o "06_Prod_${name}_${distance}.out" -p "${prmtop}" -c "04_eq_${name}_${distance}.rst" -r "06_Prod_${name}_${distance}.rst" -x "06_Prod_${name}_${distance}.nc" -inf "06_Prod_${name}_${distance}.mdinfo"

    cd ..
done

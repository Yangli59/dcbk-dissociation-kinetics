#!/bin/bash

for i in $(seq 25.0 -1.0 1.0)
do

echo "$i"

cd ./dist_${i}

rm 02_heat_comp_*.nc
rm 03_density_comp_*.nc
rm 04_eq_comp_*.nc

sed '1d' 06_Prod_dist.dat | awk '{print $1,"",$2}' > prod_dist.dat

cd ../

done

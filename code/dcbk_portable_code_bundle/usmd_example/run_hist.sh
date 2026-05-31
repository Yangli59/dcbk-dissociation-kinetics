#!/bin/bash

for i in $(seq 32.0 -1.0 1.0)
do

echo "$i"
./generate_hist.py -i ./dist_${i}/prod_dist.dat > hist_${i}.dat

done

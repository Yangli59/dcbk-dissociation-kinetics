#!/bin/bash

touch master
for i in $(seq 25.0 -1.0 3.0)
do

echo "./dist_${i}/prod_dist.dat ${i} 10.0" >> master

done

mv master metadata.dat

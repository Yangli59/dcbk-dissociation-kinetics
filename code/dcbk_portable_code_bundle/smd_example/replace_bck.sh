#!/bin/bash

new_igr1=$1
new_igr2=$2

sed -i.bak "s/^\(\s*igr1=\).*/\1$new_igr1/" dist.example.RST
sed -i "s/^\(\s*igr2=\).*/\1$new_igr2/" dist.example.RST
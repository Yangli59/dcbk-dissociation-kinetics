wham 0 25 260 0.00000001 300 0 metadata.dat out.pmf

sed '1d' out.pmf | awk '{print $1,"",$2}' > plot.dat

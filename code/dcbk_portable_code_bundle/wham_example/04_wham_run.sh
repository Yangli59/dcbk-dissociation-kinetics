#$ -cwd
#$ -e error
#$ -o output
#$ -N extact_window

source /home/qiliu02/miniconda3/etc/profile.d/conda.sh
conda activate /home/qiliu02/miniconda3/envs/pyg-py36-cpu

./01_fix_dist.sh
./02_prepare_meta.sh
./03_run_wham.sh

#source /home/soft/amber24/amber.sh

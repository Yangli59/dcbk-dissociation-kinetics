#$ -cwd
#$ -e error
#$ -o output
#$ -N extact_window

source /home/qiliu02/miniconda3/etc/profile.d/conda.sh
conda activate /home/qiliu02/miniconda3/envs/pyg-py36-cpu
source /home/soft/amber24/amber.sh

./run_smdtraj.sh

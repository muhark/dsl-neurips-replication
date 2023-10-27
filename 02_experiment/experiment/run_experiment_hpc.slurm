#!/bin/bash
#SBATCH --job-name=simulation
#SBATCH --output=logs/slurm-%A.%a.out # stdout file
#SBATCH --error=logs/slurm-%A.%a.err  # stderr file
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G
#SBATCH --array=1-1500
#SBATCH --time=23:30:00
#SBATCH --mail-type=begin
#SBATCH --mail-type=all
#SBATCH --mail-type=end
#SBATCH --mail-user=username@email.address

echo "SLURM_ARRAY_TASK_ID is $SLURM_ARRAY_TASK_ID"
echo "Executing on the machine:" $(hostname)

module purge
module load R

# project directory on HPC
cd <PATH>/<TO>/<REPO>/replication/02_experiment/experiment

Rscript run_experiment_HPC.R

echo "Completed task $SLURM_ARRAY_TASK_ID"

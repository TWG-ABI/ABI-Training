#!/bin/bash
#SBATCH --job-name=day5_func
#SBATCH --output=day5_func-%j.out
#SBATCH --error=day5_func-%j.err
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --nodes=1
# Submit from week2/metagenomics/:  sbatch scripts/sbatch_day5.sh

set -euo pipefail
source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DAY3_DIR="${COURSE_WORK_DIR}/day3_results"
export DAY4_DIR="${COURSE_WORK_DIR}/day4_results"
export OUT_DIR="${COURSE_WORK_DIR}/day5_results"
export THREADS="${SLURM_CPUS_PER_TASK:-8}"

# Load HUMAnN module on ACE if available, e.g.:
# module load q2-humann3/2026.10.0.dev0-52a5eae0

bash "${ROOT}/scripts/day5_functional.sh"

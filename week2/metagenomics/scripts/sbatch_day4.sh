#!/bin/bash
#SBATCH --job-name=day4_mags
#SBATCH --output=day4_mags-%j.out
#SBATCH --error=day4_mags-%j.err
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --nodes=1
# Submit from week2/metagenomics/:  sbatch scripts/sbatch_day4.sh

set -euo pipefail
source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DAY3_DIR="${COURSE_WORK_DIR}/day3_results"
export OUT_DIR="${COURSE_WORK_DIR}/day4_results"
export THREADS="${SLURM_CPUS_PER_TASK:-8}"

bash "${ROOT}/scripts/day4_mags.sh"

#!/bin/bash
#SBATCH --job-name=day3_shotgun
#SBATCH --output=day3_shotgun-%j.out
#SBATCH --error=day3_shotgun-%j.err
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --nodes=1
# =============================================================================
# Submit from week2/metagenomics/:
#   sbatch scripts/sbatch_day3.sh
# =============================================================================

set -euo pipefail

source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh

# Resolve repo root even if submitted from elsewhere
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export OUT_DIR="${COURSE_WORK_DIR}/day3_results"
export THREADS="${SLURM_CPUS_PER_TASK:-8}"

bash "${ROOT}/scripts/day3_shotgun.sh"

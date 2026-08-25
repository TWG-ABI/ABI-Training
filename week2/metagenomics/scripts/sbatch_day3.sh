#!/bin/bash
#SBATCH --job-name=day3_shotgun
#SBATCH --output=day3_shotgun-%j.out
#SBATCH --error=day3_shotgun-%j.err
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --nodes=1
#SBATCH --ntasks=1
# =============================================================================
# Optional all-in-one Day 3 runner (steps 01→06).
# Preferred teaching path: submit scripts/01_raw_qc.sh … 06_assembly.sh separately
#   so each stage can be inspected before the next.
# Usage: sbatch scripts/sbatch_day3.sh
# =============================================================================
set -euo pipefail

source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-8}}"

bash "${ROOT}/scripts/01_raw_qc.sh"
bash "${ROOT}/scripts/02_qc-trim.sh"
bash "${ROOT}/scripts/03_host-read_removal.sh"
bash "${ROOT}/scripts/04_kraken2.sh"
bash "${ROOT}/scripts/05_species_abundance.sh"
bash "${ROOT}/scripts/06_assembly.sh"

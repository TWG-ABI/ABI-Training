#!/bin/bash
# Day 3 — optional interactive all-in-one (prefer step scripts 01–06).
# Teaching notes: ../practicals/day3_shotgun-metagenomics.md
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Strip #SBATCH lines if someone bash'es an sbatch script directly — run bodies only
export THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-8}}"
source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh 2>/dev/null || \
  source "${ROOT}/course_env.sh"

echo "Running Day 3 steps 01→06 (THREADS=${THREADS})"
bash "${ROOT}/scripts/01_raw_qc.sh"
bash "${ROOT}/scripts/02_qc-trim.sh"
bash "${ROOT}/scripts/03_host-read_removal.sh"
bash "${ROOT}/scripts/04_kraken2.sh"
bash "${ROOT}/scripts/05_species_abundance.sh"
bash "${ROOT}/scripts/06_assembly.sh"

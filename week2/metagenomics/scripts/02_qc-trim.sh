#!/bin/bash
#SBATCH --job-name=day3-02-trim
#SBATCH --output=day3-02-trim-%j.out
#SBATCH --error=day3-02-trim-%j.err
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
# =============================================================================
# Day 3 §2 — fastp trim + MultiQC
# Outputs: ${OUT_DIR}/02_trimmed/${SAMPLE}_R1_trimmed.fastq.gz (and _R2_)
# =============================================================================
set -euo pipefail

source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-8}}"
OUT_DIR="${COURSE_WORK_DIR}/day3_results"

module load fastp
module load multiqc

mkdir -p "${OUT_DIR}/02_trimmed"

echo "Trim | IN=${GUT_DIR} | OUT=${OUT_DIR}/02_trimmed | THREADS=${THREADS}"

for R1 in "${GUT_DIR}"/*_1.fastq.gz; do
  SAMPLE=$(basename "${R1}" _1.fastq.gz)
  R2="${GUT_DIR}/${SAMPLE}_2.fastq.gz"
  if [ ! -f "${R2}" ]; then
    echo "WARNING: missing R2 for ${SAMPLE}, skipping"
    continue
  fi
  echo "  ${SAMPLE}"
  fastp \
    -i "${R1}" \
    -I "${R2}" \
    -o "${OUT_DIR}/02_trimmed/${SAMPLE}_R1_trimmed.fastq.gz" \
    -O "${OUT_DIR}/02_trimmed/${SAMPLE}_R2_trimmed.fastq.gz" \
    --detect_adapter_for_pe \
    -M 25 -5 -r --correction \
    -w "${THREADS}" \
    -j "${OUT_DIR}/02_trimmed/${SAMPLE}_fastp.json" \
    -h "${OUT_DIR}/02_trimmed/${SAMPLE}_fastp.html"
done

multiqc "${OUT_DIR}/02_trimmed" -o "${OUT_DIR}/02_trimmed" --quiet
echo "Done. Trimmed FASTQs + MultiQC under ${OUT_DIR}/02_trimmed/"

#!/bin/bash
#SBATCH --job-name=day3-04-kraken
#SBATCH --output=day3-04-kraken-%j.out
#SBATCH --error=day3-04-kraken-%j.err
#SBATCH --time=08:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
# =============================================================================
# Day 3 §4 — Kraken2 (+ Bracken if available)
# =============================================================================
set -euo pipefail

source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-8}}"
OUT_DIR="${COURSE_WORK_DIR}/day3_results"
IMAGES_DIR="${IMAGES_DIR:-${COURSE_DBS}/images}"

module load kraken2

mkdir -p "${OUT_DIR}/04_kraken2"

if [ ! -d "${KRAKEN_DB}" ]; then
  echo "ERROR: KRAKEN_DB not found at ${KRAKEN_DB}"
  exit 1
fi

echo "Kraken2 | DB=${KRAKEN_DB} | THREADS=${THREADS}"

for R1 in "${OUT_DIR}/03_host_removed/"*_clean_1.fastq.gz; do
  SAMPLE=$(basename "${R1}" _clean_1.fastq.gz)
  R2="${OUT_DIR}/03_host_removed/${SAMPLE}_clean_2.fastq.gz"
  echo "  ${SAMPLE}"
  kraken2 \
    --db "${KRAKEN_DB}" \
    --paired "${R1}" "${R2}" \
    --threads "${THREADS}" \
    --report "${OUT_DIR}/04_kraken2/${SAMPLE}.report" \
    --output "${OUT_DIR}/04_kraken2/${SAMPLE}.out" \
    --gzip-compressed \
    2>"${OUT_DIR}/04_kraken2/${SAMPLE}_kraken2.log"

  if [ -f "${IMAGES_DIR}/bracken_3.1.simg" ]; then
    singularity exec "${IMAGES_DIR}/bracken_3.1.simg" bracken \
      -d "${KRAKEN_DB}" \
      -i "${OUT_DIR}/04_kraken2/${SAMPLE}.report" \
      -o "${OUT_DIR}/04_kraken2/${SAMPLE}_bracken.txt" \
      -r 150 -l S 2>/dev/null || true
  elif command -v bracken >/dev/null 2>&1; then
    bracken \
      -d "${KRAKEN_DB}" \
      -i "${OUT_DIR}/04_kraken2/${SAMPLE}.report" \
      -o "${OUT_DIR}/04_kraken2/${SAMPLE}_bracken.txt" \
      -r 150 -l S 2>/dev/null || true
  fi
done

echo "Done. Reports under ${OUT_DIR}/04_kraken2/"

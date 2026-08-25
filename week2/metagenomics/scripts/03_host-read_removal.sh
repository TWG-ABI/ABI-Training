#!/bin/bash
#SBATCH --job-name=day3-03-host
#SBATCH --output=day3-03-host-%j.out
#SBATCH --error=day3-03-host-%j.err
#SBATCH --time=08:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
# =============================================================================
# Day 3 §3 — Bowtie2 host removal (GRCh38)
# Keeps non-host pairs: ${OUT_DIR}/03_host_removed/${SAMPLE}_clean_{1,2}.fastq.gz
# =============================================================================
set -euo pipefail

source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-8}}"
OUT_DIR="${COURSE_WORK_DIR}/day3_results"

module load bowtie2
module load samtools

mkdir -p "${OUT_DIR}/03_host_removed"

if [ ! -f "${HOST_IDX}.1.bt2" ] && [ ! -f "${HOST_IDX}.1.bt2l" ]; then
  echo "ERROR: bowtie2 index not found at ${HOST_IDX}"
  exit 1
fi

echo "Host removal | IDX=${HOST_IDX} | THREADS=${THREADS}"

for R1 in "${OUT_DIR}/02_trimmed/"*_R1_trimmed.fastq.gz; do
  SAMPLE=$(basename "${R1}" _R1_trimmed.fastq.gz)
  R2="${OUT_DIR}/02_trimmed/${SAMPLE}_R2_trimmed.fastq.gz"
  if [ ! -f "${R2}" ]; then
    echo "WARNING: missing R2 for ${SAMPLE}, skipping"
    continue
  fi
  echo "  ${SAMPLE}"
  bowtie2 \
    -x "${HOST_IDX}" \
    -1 "${R1}" \
    -2 "${R2}" \
    --un-conc-gz "${OUT_DIR}/03_host_removed/${SAMPLE}_clean_%.fastq.gz" \
    --threads "${THREADS}" \
    --very-sensitive \
    2>"${OUT_DIR}/03_host_removed/${SAMPLE}_bowtie2.log" \
    | samtools sort -@ "${THREADS}" -o "${OUT_DIR}/03_host_removed/${SAMPLE}_host.bam" -
  samtools index "${OUT_DIR}/03_host_removed/${SAMPLE}_host.bam"
done

grep "overall alignment rate" "${OUT_DIR}/03_host_removed/"*_bowtie2.log \
  > "${OUT_DIR}/03_host_removed/sample-specific_host.txt" || true
echo "Host rates written to ${OUT_DIR}/03_host_removed/sample-specific_host.txt"

#!/bin/bash
#SBATCH --job-name=day3-01-qc
#SBATCH --output=day3-01-qc-%j.out
#SBATCH --error=day3-01-qc-%j.err
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
# =============================================================================
# Day 3 §1 — FastQC + MultiQC on raw gut FASTQs
# Submit from week2/metagenomics/:  sbatch scripts/01_raw_qc.sh
# =============================================================================
set -euo pipefail

source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-8}}"
OUT_DIR="${COURSE_WORK_DIR}/day3_results"

module load fastqc
module load multiqc

mkdir -p "${OUT_DIR}/01_qc"

echo "Raw QC | IN=${GUT_DIR} | OUT=${OUT_DIR}/01_qc | THREADS=${THREADS}"

for R1 in "${GUT_DIR}"/*_1.fastq.gz; do
  SAMPLE=$(basename "${R1}" _1.fastq.gz)
  R2="${GUT_DIR}/${SAMPLE}_2.fastq.gz"
  fastqc --outdir "${OUT_DIR}/01_qc" --threads "${THREADS}" --quiet "${R1}" "${R2}"
done

multiqc "${OUT_DIR}/01_qc/" --outdir "${OUT_DIR}/01_qc/multiqc" --quiet
echo "Done. Open ${OUT_DIR}/01_qc/multiqc/multiqc_report.html"

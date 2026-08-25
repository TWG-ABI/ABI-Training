#!/bin/bash
#SBATCH --job-name=day3-06-asm
#SBATCH --output=day3-06-asm-%j.out
#SBATCH --error=day3-06-asm-%j.err
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
# =============================================================================
# Day 3 §6 — MEGAHIT + seqkit filter + QUAST (all cleaned samples, or DEMO_SAMPLE=)
# =============================================================================
set -euo pipefail

source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-8}}"
OUT_DIR="${COURSE_WORK_DIR}/day3_results"
export MPLCONFIGDIR="${TMPDIR:-/tmp}/${USER}-matplotlib"
mkdir -p "${MPLCONFIGDIR}"

module load megahit
module load seqkit
module load quast

mkdir -p "${OUT_DIR}/06_assembly" "${OUT_DIR}/06_quast"

shopt -s nullglob
if [ -n "${DEMO_SAMPLE:-}" ]; then
  R1_FILES=("${OUT_DIR}/03_host_removed/${DEMO_SAMPLE}_clean_1.fastq.gz")
else
  R1_FILES=("${OUT_DIR}/03_host_removed/"*_clean_1.fastq.gz)
fi

if [ ${#R1_FILES[@]} -eq 0 ] || [ ! -f "${R1_FILES[0]}" ]; then
  echo "ERROR: no cleaned reads to assemble under ${OUT_DIR}/03_host_removed/"
  exit 1
fi

LAST_SAMPLE=""
for R1 in "${R1_FILES[@]}"; do
  SAMPLE=$(basename "${R1}" _clean_1.fastq.gz)
  R2="${OUT_DIR}/03_host_removed/${SAMPLE}_clean_2.fastq.gz"
  LAST_SAMPLE="${SAMPLE}"
  echo "Assembling ${SAMPLE} with THREADS=${THREADS}"
  rm -rf "${OUT_DIR}/06_assembly/${SAMPLE}"
  megahit \
    -1 "${R1}" -2 "${R2}" \
    -o "${OUT_DIR}/06_assembly/${SAMPLE}" \
    --num-cpu-threads "${THREADS}" \
    --min-contig-len 1000 \
    --memory 0.5

  seqkit seq --min-len 1500 \
    "${OUT_DIR}/06_assembly/${SAMPLE}/final.contigs.fa" \
    -o "${OUT_DIR}/06_assembly/${SAMPLE}/contigs_min1500.fa"

  quast \
    "${OUT_DIR}/06_assembly/${SAMPLE}/contigs_min1500.fa" \
    -o "${OUT_DIR}/06_quast/${SAMPLE}" \
    -t "${THREADS}"
done

echo "Assembly sample(s) for Day 4 — last finished: ${LAST_SAMPLE}"
echo "  Contigs: ${OUT_DIR}/06_assembly/${LAST_SAMPLE}/contigs_min1500.fa"

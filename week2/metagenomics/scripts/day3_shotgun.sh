#!/bin/bash
# Day 3 — shotgun pipeline (participant runnable)
# Teaching notes / rationale: ../practicals/day3_shotgun-metagenomics.md
# =============================================================================
# Usage (interactive):
#   source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
#   bash scripts/day3_shotgun.sh
#
# Or via SLURM: sbatch scripts/sbatch_day3.sh
# =============================================================================

set -euo pipefail

_COURSE_ENV="${COURSE_ENV:-/etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh}"
if [ -f "${_COURSE_ENV}" ]; then
  # shellcheck source=/dev/null
  source "${_COURSE_ENV}"
elif [ -f "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../course_env.sh" ]; then
  # shellcheck source=/dev/null
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../course_env.sh"
fi

# Day 3 modules only
module load fastqc 2>/dev/null || true
module load multiqc 2>/dev/null || true
module load fastp 2>/dev/null || true
module load bowtie2 2>/dev/null || true
module load kraken2 2>/dev/null || true
module load megahit 2>/dev/null || true
module load quast 2>/dev/null || true
module load seqkit 2>/dev/null || true

IN_DIR="${GUT_DIR}"
OUT_DIR="${OUT_DIR:-${COURSE_WORK_DIR}/day3_results}"
kraken_DB="${KRAKEN_DB}"
IMAGES_DIR="${IMAGES_DIR:-${COURSE_DBS}/images}"
THREADS="${THREADS:-8}"

mkdir -p "${OUT_DIR}"/{qc,trimmed,host_removed,kraken2,metaphlan,tables,assembly,quast}

echo "============================================="
echo " Day 3 | Shotgun metagenomics"
echo " IN:  ${IN_DIR}"
echo " OUT: ${OUT_DIR}"
echo "============================================="

if [ ! -d "${IN_DIR}" ]; then
  echo "ERROR: gut_sample not found at ${IN_DIR}"
  exit 1
fi

# ── 1. QC ─────────────────────────────────────────────────────────────────────
echo "[1/5] FastQC + MultiQC"
fastqc --outdir "${OUT_DIR}/qc/" --threads "${THREADS}" --quiet "${IN_DIR}"/*.gz
multiqc "${OUT_DIR}/qc/" --filename "metagenomes_multiqc" --quiet -o "${OUT_DIR}/qc/"

# ── 2. Trim ───────────────────────────────────────────────────────────────────
echo "[2/5] fastp"
for file in "${IN_DIR}"/*_1.fastq.gz; do
  sample=$(basename "${file}" _1.fastq.gz)
  fastp \
    --in1 "${IN_DIR}/${sample}_1.fastq.gz" \
    --in2 "${IN_DIR}/${sample}_2.fastq.gz" \
    --out1 "${OUT_DIR}/trimmed/${sample}_trimmed_1.fastq.gz" \
    --out2 "${OUT_DIR}/trimmed/${sample}_trimmed_2.fastq.gz" \
    --qualified_quality_phred 20 \
    --length_required 50 \
    --detect_adapter_for_pe \
    --thread "${THREADS}" \
    --json "${OUT_DIR}/trimmed/${sample}_fastp.json" \
    --html "${OUT_DIR}/trimmed/${sample}_fastp.html"
done

# ── 3. Host removal ───────────────────────────────────────────────────────────
echo "[3/5] Host removal (Bowtie2)"
if [ -f "${HOST_IDX}.1.bt2" ] || [ -f "${HOST_IDX}.1.bt2l" ]; then
  for R1 in "${OUT_DIR}"/trimmed/*_trimmed_1.fastq.gz; do
    SAMPLE=$(basename "${R1}" _trimmed_1.fastq.gz)
    R2="${OUT_DIR}/trimmed/${SAMPLE}_trimmed_2.fastq.gz"
    echo "  ${SAMPLE}"
    bowtie2 \
      -x "${HOST_IDX}" \
      -1 "${R1}" -2 "${R2}" \
      --un-conc-gz "${OUT_DIR}/host_removed/${SAMPLE}_clean_%.fastq.gz" \
      --threads "${THREADS}" \
      --very-sensitive \
      -S /dev/null \
      2>"${OUT_DIR}/host_removed/${SAMPLE}_bowtie2.log"
    grep "overall alignment rate" "${OUT_DIR}/host_removed/${SAMPLE}_bowtie2.log" || true
  done
else
  echo "  WARNING: HOST_IDX not found (${HOST_IDX}) — copying trimmed reads"
  for R1 in "${OUT_DIR}"/trimmed/*_trimmed_1.fastq.gz; do
    SAMPLE=$(basename "${R1}" _trimmed_1.fastq.gz)
    cp "${R1}" "${OUT_DIR}/host_removed/${SAMPLE}_clean_1.fastq.gz"
    cp "${OUT_DIR}/trimmed/${SAMPLE}_trimmed_2.fastq.gz" \
       "${OUT_DIR}/host_removed/${SAMPLE}_clean_2.fastq.gz"
  done
fi

# ── 4. Kraken2 (+ Bracken if image present) ───────────────────────────────────
echo "[4/5] Kraken2"
if [ -d "${kraken_DB}" ]; then
  for R1 in "${OUT_DIR}"/host_removed/*_clean_1.fastq.gz; do
    SAMPLE=$(basename "${R1}" _clean_1.fastq.gz)
    R2="${OUT_DIR}/host_removed/${SAMPLE}_clean_2.fastq.gz"
    echo "  ${SAMPLE}"
    kraken2 \
      --db "${kraken_DB}" \
      --paired "${R1}" "${R2}" \
      --threads "${THREADS}" \
      --report "${OUT_DIR}/kraken2/${SAMPLE}.report" \
      --output "${OUT_DIR}/kraken2/${SAMPLE}.out" \
      --gzip-compressed \
      2>"${OUT_DIR}/kraken2/${SAMPLE}_kraken2.log"

    if [ -f "${IMAGES_DIR}/bracken_3.1.simg" ]; then
      singularity exec "${IMAGES_DIR}/bracken_3.1.simg" bracken \
        -d "${kraken_DB}" \
        -i "${OUT_DIR}/kraken2/${SAMPLE}.report" \
        -o "${OUT_DIR}/kraken2/${SAMPLE}_bracken.txt" \
        -r 150 -l S 2>/dev/null || true
    elif command -v bracken >/dev/null 2>&1; then
      bracken \
        -d "${kraken_DB}" \
        -i "${OUT_DIR}/kraken2/${SAMPLE}.report" \
        -o "${OUT_DIR}/kraken2/${SAMPLE}_bracken.txt" \
        -r 150 -l S 2>/dev/null || true
    fi
  done
else
  echo "  WARNING: KRAKEN_DB not found at ${kraken_DB}"
fi

# ── 5. Assembly demo (first sample) ───────────────────────────────────────────
echo "[5/5] MEGAHIT + QUAST (one sample)"
DEMO=$(ls "${OUT_DIR}"/host_removed/*_clean_1.fastq.gz 2>/dev/null | head -1)
if [ -n "${DEMO}" ]; then
  SAMPLE=$(basename "${DEMO}" _clean_1.fastq.gz)
  R2="${OUT_DIR}/host_removed/${SAMPLE}_clean_2.fastq.gz"
  echo "  Assembling: ${SAMPLE}"
  megahit \
    -1 "${DEMO}" -2 "${R2}" \
    -o "${OUT_DIR}/assembly/${SAMPLE}" \
    --threads "${THREADS}" \
    --min-contig-len 1000 \
    --memory 0.5
  seqkit seq --min-len 1500 \
    "${OUT_DIR}/assembly/${SAMPLE}/final.contigs.fa" \
    > "${OUT_DIR}/assembly/${SAMPLE}/contigs_min1500.fa"
  quast.py \
    "${OUT_DIR}/assembly/${SAMPLE}/contigs_min1500.fa" \
    --output-dir "${OUT_DIR}/quast/${SAMPLE}" \
    --threads "${THREADS}" \
    --no-check-install 2>/dev/null || true
  echo "  Assembly sample for Day 4: ${SAMPLE}"
fi

echo "============================================="
echo " Day 3 complete → ${OUT_DIR}"
echo " Remember the assembled sample name for Day 4."
echo " Teaching notes: practicals/day3_shotgun-metagenomics.md"
echo "============================================="

#!/bin/bash
# Day 4 — MAG pipeline (participant runnable)
# Teaching notes: ../practicals/day4_metagenome-assembled-genomes.md
# =============================================================================
# Usage:
#   source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
#   bash scripts/day4_mags.sh
#   # or: sbatch scripts/sbatch_day4.sh
#
# Optional overrides:
#   DEMO_SAMPLE=SRR27027504 DAY3_DIR=... OUT_DIR=... bash scripts/day4_mags.sh
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

# Day 4 tools (module names may differ on ACE — adjust if needed)
module load bowtie2 2>/dev/null || true
module load samtools 2>/dev/null || true
module load seqkit 2>/dev/null || true
# MetaBAT2 / MaxBin2 / DAS_Tool / CheckM2 / GTDB-Tk: modules, conda, or Apptainer wrappers

DAY3_DIR="${DAY3_DIR:-${COURSE_WORK_DIR}/day3_results}"
OUT_DIR="${OUT_DIR:-${COURSE_WORK_DIR}/day4_results}"
THREADS="${THREADS:-8}"
GTDBTK_DATA="${GTDBTK_DATA_PATH:-${COURSE_DBS}/gtdbtk/release226}"
CHECKM2DB="${CHECKM2DB:-${COURSE_DBS}/checkm2/CheckM2_database/uniref100.KO.1.dmnd}"

# Auto-pick Day 3 assembly sample unless DEMO_SAMPLE is set
if [ -z "${DEMO_SAMPLE:-}" ]; then
  if [ -d "${DAY3_DIR}/assembly" ]; then
    DEMO_SAMPLE=$(ls -1 "${DAY3_DIR}/assembly" 2>/dev/null | head -1 || true)
  fi
fi
DEMO_SAMPLE="${DEMO_SAMPLE:-SRR27027606}"

ASSEMBLY="${DAY3_DIR}/assembly/${DEMO_SAMPLE}/contigs_min1500.fa"
if [ ! -f "${ASSEMBLY}" ]; then
  ASSEMBLY="${DAY3_DIR}/assembly/${DEMO_SAMPLE}/final.contigs.fa"
fi
READS_R1="${DAY3_DIR}/host_removed/${DEMO_SAMPLE}_clean_1.fastq.gz"
READS_R2="${DAY3_DIR}/host_removed/${DEMO_SAMPLE}_clean_2.fastq.gz"

mkdir -p "${OUT_DIR}"/{mapping,metabat2,maxbin2,das_tool,checkm2,gtdbtk}

echo "============================================="
echo " Day 4 | MAG pipeline"
echo " DAY3: ${DAY3_DIR}"
echo " DEMO: ${DEMO_SAMPLE}"
echo " OUT:  ${OUT_DIR}"
echo "============================================="

if [ ! -f "${ASSEMBLY}" ]; then
  echo "ERROR: Assembly not found: ${ASSEMBLY}"
  echo "Run Day 3 first, or set DEMO_SAMPLE / DAY3_DIR."
  ls -la "${DAY3_DIR}/assembly" 2>/dev/null || true
  exit 1
fi
if [ ! -f "${READS_R1}" ] || [ ! -f "${READS_R2}" ]; then
  echo "ERROR: Clean reads not found for ${DEMO_SAMPLE}"
  exit 1
fi

echo "Assembly stats:"
seqkit stats "${ASSEMBLY}" | column -t
echo ""

# ── 1. Map reads → coverage ───────────────────────────────────────────────────
echo "[1/6] Mapping → coverage"
bowtie2-build --threads "${THREADS}" "${ASSEMBLY}" "${OUT_DIR}/mapping/assembly_idx" \
  2>"${OUT_DIR}/mapping/bowtie2_build.log"

bowtie2 \
  -x "${OUT_DIR}/mapping/assembly_idx" \
  -1 "${READS_R1}" -2 "${READS_R2}" \
  --threads "${THREADS}" \
  2>"${OUT_DIR}/mapping/bowtie2_map.log" | \
  samtools sort -@ "${THREADS}" -o "${OUT_DIR}/mapping/reads_sorted.bam"

samtools index "${OUT_DIR}/mapping/reads_sorted.bam"
samtools flagstat "${OUT_DIR}/mapping/reads_sorted.bam" | grep -E "mapped|total" | head -5

jgi_summarize_bam_contig_depths \
  --outputDepth "${OUT_DIR}/mapping/depth.txt" \
  "${OUT_DIR}/mapping/reads_sorted.bam"

# ── 2. MetaBAT2 ───────────────────────────────────────────────────────────────
echo "[2/6] MetaBAT2"
mkdir -p "${OUT_DIR}/metabat2/bins"
metabat2 \
  -i "${ASSEMBLY}" \
  -a "${OUT_DIR}/mapping/depth.txt" \
  -o "${OUT_DIR}/metabat2/bins/bin" \
  --minContig 1500 \
  --numThreads "${THREADS}" \
  --saveCls \
  2>"${OUT_DIR}/metabat2/metabat2.log"

N_BINS=$(ls "${OUT_DIR}"/metabat2/bins/bin.*.fa 2>/dev/null | wc -l)
echo "  MetaBAT2 bins: ${N_BINS}"

# ── 3. MaxBin2 (optional) ─────────────────────────────────────────────────────
echo "[3/6] MaxBin2"
if command -v run_MaxBin.pl &>/dev/null; then
  mkdir -p "${OUT_DIR}/maxbin2/bins"
  awk 'NR>1{print $1"\t"$3}' "${OUT_DIR}/mapping/depth.txt" > \
    "${OUT_DIR}/mapping/abundance.txt"
  run_MaxBin.pl \
    -contig "${ASSEMBLY}" \
    -abund "${OUT_DIR}/mapping/abundance.txt" \
    -out "${OUT_DIR}/maxbin2/bins/bin" \
    -thread "${THREADS}" \
    2>"${OUT_DIR}/maxbin2/maxbin2.log" || true
else
  echo "  MaxBin2 not on PATH — skipping"
fi

# ── 4. DAS_Tool ───────────────────────────────────────────────────────────────
echo "[4/6] DAS_Tool"
if command -v Fasta_to_Contig2Bin.sh &>/dev/null; then
  Fasta_to_Contig2Bin.sh -i "${OUT_DIR}/metabat2/bins/" -e fa \
    > "${OUT_DIR}/das_tool/metabat2_s2b.tsv" 2>/dev/null || true
else
  # fallback contig→bin table
  : > "${OUT_DIR}/das_tool/metabat2_s2b.tsv"
  for f in "${OUT_DIR}"/metabat2/bins/bin.*.fa; do
    [ -f "$f" ] || continue
    b=$(basename "$f" .fa)
    grep "^>" "$f" | sed "s/^>//;s/ .*//" | awk -v b="$b" '{print $1"\t"b}' \
      >> "${OUT_DIR}/das_tool/metabat2_s2b.tsv"
  done
fi

BINNER_FILES="${OUT_DIR}/das_tool/metabat2_s2b.tsv"
BINNER_NAMES="metabat2"
if [ -d "${OUT_DIR}/maxbin2/bins" ] && ls "${OUT_DIR}"/maxbin2/bins/*.fasta &>/dev/null; then
  if command -v Fasta_to_Contig2Bin.sh &>/dev/null; then
    Fasta_to_Contig2Bin.sh -i "${OUT_DIR}/maxbin2/bins/" -e fasta \
      > "${OUT_DIR}/das_tool/maxbin2_s2b.tsv" 2>/dev/null || true
  fi
  if [ -s "${OUT_DIR}/das_tool/maxbin2_s2b.tsv" ]; then
    BINNER_FILES="${BINNER_FILES},${OUT_DIR}/das_tool/maxbin2_s2b.tsv"
    BINNER_NAMES="${BINNER_NAMES},maxbin2"
  fi
fi

if command -v DAS_Tool &>/dev/null; then
  DAS_Tool \
    -i "${BINNER_FILES}" \
    -l "${BINNER_NAMES}" \
    -c "${ASSEMBLY}" \
    -o "${OUT_DIR}/das_tool/DAS_output" \
    --search_engine diamond \
    --write_bins 1 \
    --write_unbinned 0 \
    --threads "${THREADS}" \
    2>"${OUT_DIR}/das_tool/dastool.log" || true
else
  echo "  DAS_Tool not on PATH — using MetaBAT2 bins only"
fi

# ── 5. CheckM2 ────────────────────────────────────────────────────────────────
echo "[5/6] CheckM2"
BIN_DIR="${OUT_DIR}/das_tool/DAS_output_DASTool_bins"
if [ ! -d "${BIN_DIR}" ] || [ -z "$(ls "${BIN_DIR}"/*.fa 2>/dev/null)" ]; then
  BIN_DIR="${OUT_DIR}/metabat2/bins"
fi

if command -v checkm2 &>/dev/null; then
  CHECKM2_DB_ARGS=()
  if [ -n "${CHECKM2DB:-}" ] && [ -r "${CHECKM2DB}" ]; then
    CHECKM2_DB_ARGS+=(--database_path "${CHECKM2DB}")
  fi
  # MetaBAT bins are often bin.*.fa — CheckM2 --extension fa
  EXT=fa
  checkm2 predict \
    --input "${BIN_DIR}" \
    --output-directory "${OUT_DIR}/checkm2" \
    --extension "${EXT}" \
    --threads "${THREADS}" \
    "${CHECKM2_DB_ARGS[@]}" \
    2>"${OUT_DIR}/checkm2/checkm2.log" || true

  if [ -f "${OUT_DIR}/checkm2/quality_report.tsv" ]; then
    echo "  MIMAG summary:"
    awk -F'\t' 'NR>1{
      if ($2>=90 && $3<5) hq++
      else if ($2>=50 && $3<10) mq++
      else lq++
    } END {
      printf "  HQ=%d  MQ=%d  LQ=%d\n", hq+0, mq+0, lq+0
    }' "${OUT_DIR}/checkm2/quality_report.tsv"
  fi
else
  echo "  WARNING: checkm2 not on PATH"
fi

# ── 6. GTDB-Tk ────────────────────────────────────────────────────────────────
echo "[6/6] GTDB-Tk"
if command -v gtdbtk &>/dev/null && [ -d "${GTDBTK_DATA}" ]; then
  export GTDBTK_DATA_PATH="${GTDBTK_DATA}"
  gtdbtk classify_wf \
    --genome_dir "${BIN_DIR}" \
    --out_dir "${OUT_DIR}/gtdbtk" \
    --cpus "${THREADS}" \
    --extension fa \
    --skip_ani_screen \
    2>"${OUT_DIR}/gtdbtk/gtdbtk.log" || true
else
  echo "  WARNING: gtdbtk / GTDBTK_DATA_PATH not ready (${GTDBTK_DATA})"
fi

echo "============================================="
echo " Day 4 complete → ${OUT_DIR}"
echo " Bins used: ${BIN_DIR}"
echo " Teaching notes: practicals/day4_metagenome-assembled-genomes.md"
echo "============================================="

#!/bin/bash
# Day 5 — functional analysis (participant runnable)
# Teaching notes: ../practicals/day5_functional-analysis.md
# Visualisation: ../practicals/day5_functional-analysis-visualisation.md
# =============================================================================
# Usage:
#   source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
#   bash scripts/day5_functional.sh
#   # or: sbatch scripts/sbatch_day5.sh
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

# Day 5 tools (modules / wrappers — adjust names on ACE)
module load prokka 2>/dev/null || true
# eggnog-mapper / humann / amrfinder via modules or Apptainer wrappers

DAY3_DIR="${DAY3_DIR:-${COURSE_WORK_DIR}/day3_results}"
DAY4_DIR="${DAY4_DIR:-${COURSE_WORK_DIR}/day4_results}"
OUT_DIR="${OUT_DIR:-${COURSE_WORK_DIR}/day5_results}"
THREADS="${THREADS:-8}"

HUMANN_DB="${HUMANN_DB_PATH:-${COURSE_DBS}/humann3}"
METAPHLAN_DB="${METAPHLAN_DB:-${COURSE_DBS}/metaphlanDB}"
if [ ! -d "${METAPHLAN_DB}" ] && [ -d "${HUMANN_DB}/metaphlan_db" ]; then
  METAPHLAN_DB="${HUMANN_DB}/metaphlan_db"
fi
EGGNOG_DATA_DIR="${EGGNOG_DATA_DIR:-${COURSE_DBS}/eggnog}"
AMRFINDER_DB="${AMRFINDER_DB:-${COURSE_DBS}/amrfinder/latest}"
export EGGNOG_DATA_DIR

MAG_DIR="${DAY4_DIR}/das_tool/DAS_output_DASTool_bins"
if [ ! -d "${MAG_DIR}" ] || [ -z "$(ls "${MAG_DIR}"/*.fa 2>/dev/null)" ]; then
  MAG_DIR="${DAY4_DIR}/metabat2/bins"
fi

mkdir -p "${OUT_DIR}"/{prokka,eggnog,humann3,amr}

echo "============================================="
echo " Day 5 | Functional analysis"
echo " DAY3: ${DAY3_DIR}"
echo " DAY4: ${DAY4_DIR}  (MAGs: ${MAG_DIR})"
echo " OUT:  ${OUT_DIR}"
echo "============================================="

# ── 1. Prokka (≤3 MAGs) ───────────────────────────────────────────────────────
echo "[1/4] Prokka"
N_MAGS=0
shopt -s nullglob
MAG_FILES=("${MAG_DIR}"/*.fa)
if [ ${#MAG_FILES[@]} -eq 0 ]; then
  echo "ERROR: no MAG .fa files in ${MAG_DIR}"
  exit 1
fi

for MAG in "${MAG_FILES[@]}"; do
  MAG_NAME=$(basename "${MAG}" .fa)
  N_MAGS=$((N_MAGS + 1))
  if [ "${N_MAGS}" -gt 3 ]; then
    echo "  (Limiting to 3 MAGs for course time)"
    break
  fi
  echo "  Annotating: ${MAG_NAME}"
  if command -v prokka &>/dev/null; then
    prokka \
      --outdir "${OUT_DIR}/prokka/${MAG_NAME}" \
      --prefix "${MAG_NAME}" \
      --cpus "${THREADS}" \
      --kingdom Bacteria \
      --quiet \
      "${MAG}"
  else
    echo "  WARNING: prokka not on PATH"
    break
  fi
done

cat "${OUT_DIR}"/prokka/*/*/*.faa > "${OUT_DIR}/prokka/all_MAGs.faa" 2>/dev/null || \
  cat "${OUT_DIR}"/prokka/*/*.faa > "${OUT_DIR}/prokka/all_MAGs.faa" 2>/dev/null || true

TOTAL_GENES=$(grep -c "^>" "${OUT_DIR}/prokka/all_MAGs.faa" 2>/dev/null || echo 0)
echo "  Total predicted genes: ${TOTAL_GENES}"

# ── 2. eggNOG-mapper ──────────────────────────────────────────────────────────
echo "[2/4] eggNOG-mapper"
if [ -f "${OUT_DIR}/prokka/all_MAGs.faa" ] && [ "${TOTAL_GENES}" -gt 0 ] && command -v emapper.py &>/dev/null; then
  emapper.py \
    -i "${OUT_DIR}/prokka/all_MAGs.faa" \
    -o all_MAGs_eggnog \
    --output_dir "${OUT_DIR}/eggnog" \
    --data_dir "${EGGNOG_DATA_DIR}" \
    --cpu "${THREADS}" \
    2>"${OUT_DIR}/eggnog/eggnog.log" || true
  echo "  eggNOG → ${OUT_DIR}/eggnog/"
else
  echo "  SKIP eggNOG (no proteins or emapper.py missing)"
fi

# ── 3. HUMAnN3 (one demo sample) ──────────────────────────────────────────────
echo "[3/4] HUMAnN3"
DEMO_READS=$(ls "${DAY3_DIR}"/host_removed/*_clean_1.fastq.gz 2>/dev/null | head -1 || true)
if [ -z "${DEMO_READS}" ]; then
  DEMO_READS=$(ls "${DAY3_DIR}"/trimmed/*_trimmed_1.fastq.gz 2>/dev/null | head -1 || true)
fi

if command -v humann &>/dev/null && [ -n "${DEMO_READS}" ]; then
  SAMPLE_NAME=$(basename "${DEMO_READS}" _clean_1.fastq.gz)
  SAMPLE_NAME=${SAMPLE_NAME%_trimmed_1.fastq.gz}
  echo "  Input: ${DEMO_READS}"
  humann \
    --input "${DEMO_READS}" \
    --output "${OUT_DIR}/humann3/${SAMPLE_NAME}" \
    --threads "${THREADS}" \
    --metaphlan-options "--db_dir ${METAPHLAN_DB}" \
    --nucleotide-database "${HUMANN_DB}/chocophlan" \
    --protein-database "${HUMANN_DB}/uniref" \
    2>"${OUT_DIR}/humann3/${SAMPLE_NAME}.log" || true

  if ls "${OUT_DIR}/humann3/${SAMPLE_NAME}"/*_genefamilies.tsv &>/dev/null; then
    humann_renorm_table \
      --input "${OUT_DIR}/humann3/${SAMPLE_NAME}"/*_genefamilies.tsv \
      --output "${OUT_DIR}/humann3/${SAMPLE_NAME}_genefamilies_relab.tsv" \
      --units relab || true
  fi
else
  echo "  SKIP HUMAnN (humann not on PATH or no Day 3 reads)"
fi

# ── 4. AMR ────────────────────────────────────────────────────────────────────
echo "[4/4] AMR"
if command -v rgi &>/dev/null && [ -f "${OUT_DIR}/prokka/all_MAGs.faa" ]; then
  rgi main \
    -i "${OUT_DIR}/prokka/all_MAGs.faa" \
    -o "${OUT_DIR}/amr/rgi_output" \
    -t protein --clean --num_threads "${THREADS}" 2>/dev/null || true
elif command -v amrfinder &>/dev/null && [ -f "${OUT_DIR}/prokka/all_MAGs.faa" ]; then
  amrfinder \
    -p "${OUT_DIR}/prokka/all_MAGs.faa" \
    -d "${AMRFINDER_DB}" \
    -o "${OUT_DIR}/amr/amrfinder_output.tsv" \
    --plus --threads "${THREADS}" || true
  echo "  AMRFinder → ${OUT_DIR}/amr/amrfinder_output.tsv"
else
  echo "  SKIP AMR (rgi/amrfinder not found)"
fi

echo "============================================="
echo " Day 5 complete → ${OUT_DIR}"
echo " Next: practicals/day5_functional-analysis-visualisation.md"
echo " Teaching notes: practicals/day5_functional-analysis.md"
echo "============================================="

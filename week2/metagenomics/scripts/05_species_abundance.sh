#!/bin/bash
#SBATCH --job-name=day3-05-metaphlan
#SBATCH --output=day3-05-metaphlan-%j.out
#SBATCH --error=day3-05-metaphlan-%j.err
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
# =============================================================================
# Day 3 §5 — MetaPhlAn4 species profiles + merge tables
# =============================================================================
set -euo pipefail

source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-8}}"
OUT_DIR="${COURSE_WORK_DIR}/day3_results"
IMAGES_DIR="${IMAGES_DIR:-${COURSE_DBS}/images}"
INDEX="mpa_vJun23_CHOCOPhlAnSGB_202403"
SIF="${IMAGES_DIR}/metaphlan_4.2.6.simg"

mkdir -p "${OUT_DIR}/05_species_abundance"

if [ ! -f "${SIF}" ]; then
  echo "ERROR: MetaPhlAn image not found at ${SIF}"
  exit 1
fi

PROFILE_LIST="${OUT_DIR}/05_species_abundance/profile_list.txt"
: > "${PROFILE_LIST}"

shopt -s nullglob
R1_FILES=("${OUT_DIR}/03_host_removed/"*_clean_1.fastq.gz)
if [ ${#R1_FILES[@]} -eq 0 ]; then
  echo "ERROR: no cleaned reads in ${OUT_DIR}/03_host_removed/"
  exit 1
fi

echo "MetaPhlAn | DB=${METAPHLAN_DB} | INDEX=${INDEX} | THREADS=${THREADS}"

for R1 in "${R1_FILES[@]}"; do
  SAMPLE=$(basename "${R1}" _clean_1.fastq.gz)
  R2="${OUT_DIR}/03_host_removed/${SAMPLE}_clean_2.fastq.gz"
  if [ ! -f "${R2}" ]; then
    echo "WARNING: missing R2 for ${SAMPLE}, skipping"
    continue
  fi
  echo "  ${SAMPLE}"
  singularity exec \
    -B "${OUT_DIR}:${OUT_DIR}" \
    -B "${METAPHLAN_DB}:${METAPHLAN_DB}" \
    "${SIF}" \
    metaphlan \
      "${R1},${R2}" \
      --input_type fastq \
      --nproc "${THREADS}" \
      --db_dir "${METAPHLAN_DB}" \
      -x "${INDEX}" \
      --mapout "${OUT_DIR}/05_species_abundance/${SAMPLE}.bowtie2.bz2" \
      -o "${OUT_DIR}/05_species_abundance/${SAMPLE}_profile.txt"
  echo -e "${SAMPLE}\t${OUT_DIR}/05_species_abundance/${SAMPLE}_profile.txt" >> "${PROFILE_LIST}"
done

echo "Merging MetaPhlAn profiles"
singularity exec \
  -B "${OUT_DIR}:${OUT_DIR}" \
  -B "${METAPHLAN_DB}:${METAPHLAN_DB}" \
  "${SIF}" \
  merge_metaphlan_tables.py \
  "${OUT_DIR}/05_species_abundance/"*_profile.txt \
  > "${OUT_DIR}/05_species_abundance/metaphlan_merged_all_levels.tsv"

awk -F'\t' 'NR==1 || $1 ~ /s__/' \
  "${OUT_DIR}/05_species_abundance/metaphlan_merged_all_levels.tsv" \
  > "${OUT_DIR}/05_species_abundance/metaphlan_species_relab.tsv"

echo "Done."
echo "  All levels: ${OUT_DIR}/05_species_abundance/metaphlan_merged_all_levels.tsv"
echo "  Species:    ${OUT_DIR}/05_species_abundance/metaphlan_species_relab.tsv"

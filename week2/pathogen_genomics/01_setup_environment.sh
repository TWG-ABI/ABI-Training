#!/bin/bash
#SBATCH --job-name=setup_environment
#SBATCH --output=setup_%j.out
#SBATCH --error=setup_%j.err
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:10:00

set -euo pipefail

# ============================================================
# 01_setup_environment.sh
# Bacterial Genomics Practical Training
#
# Purpose:
#   1. Create the analysis directory structure
#   2. Link the shared sequencing-data folder
#   3. Generate a unique sample list
#   4. Check that paired-end reads are present
#
# Expected dataset:
#   40 samples
#   80 FASTQ files
#
# Expected naming:
#   SAMPLE_trim1.fastq.gz
#   SAMPLE_trim2.fastq.gz
# ============================================================


# ------------------------------------------------------------
# 1. Move to the directory from which the job was submitted
# ------------------------------------------------------------

cd "${SLURM_SUBMIT_DIR:-$PWD}"

echo "============================================================"
echo " BACTERIAL GENOMICS TRAINING - ENVIRONMENT SETUP"
echo "============================================================"
echo
echo "Working directory: $(pwd)"
echo


# ------------------------------------------------------------
# 2. Define shared central dataset
# ------------------------------------------------------------

CENTRAL_DATA="/etc/ace-data/ABI-SummerSchool-26/pathogen-genomics/data"

echo "Central dataset:"
echo "${CENTRAL_DATA}"
echo


# ------------------------------------------------------------
# 3. Check that central data directory exists
# ------------------------------------------------------------

echo "=== Step 1: Checking shared dataset ==="

if [[ ! -d "${CENTRAL_DATA}" ]]; then
    echo "ERROR: Central data directory does not exist:"
    echo "${CENTRAL_DATA}" >&2
    exit 1
fi

if [[ ! -r "${CENTRAL_DATA}" ]]; then
    echo "ERROR: Central data directory is not readable:"
    echo "${CENTRAL_DATA}" >&2
    exit 1
fi

echo "Shared dataset is accessible."


# ------------------------------------------------------------
# 4. Create analysis directories
# ------------------------------------------------------------

echo
echo "=== Step 2: Creating analysis directories ==="

mkdir -p \
    fastqc_files \
    clean_data \
    assembly \
    quality_assembly \
    annotation \
    mlsts \
    resistome \
    reports \
    phylogenetics \
    snps

echo "Analysis directories created successfully."


# ------------------------------------------------------------
# 5. Create symbolic link to shared raw data
# ------------------------------------------------------------

echo
echo "=== Step 3: Linking raw sequencing data ==="

ln -sfn "${CENTRAL_DATA}" raw_data

echo "Created:"
echo "raw_data -> ${CENTRAL_DATA}"


# ------------------------------------------------------------
# 6. Identify FASTQ files
# ------------------------------------------------------------

echo
echo "=== Step 4: Identifying FASTQ files ==="

shopt -s nullglob

FASTQ_FILES=("${CENTRAL_DATA}"/*.fastq.gz)

NFASTQ=${#FASTQ_FILES[@]}

if (( NFASTQ == 0 )); then
    echo "ERROR: No FASTQ files found in:"
    echo "${CENTRAL_DATA}" >&2
    exit 1
fi

echo "FASTQ files found: ${NFASTQ}"


# ------------------------------------------------------------
# 7. Generate unique sample list
# ------------------------------------------------------------

echo
echo "=== Step 5: Generating sample list ==="

> list.txt

for file in "${FASTQ_FILES[@]}"; do

    filename=$(basename "${file}")

    if [[ "${filename}" =~ ^(.+)_(trim1|trim2)\.fastq\.gz$ ]]; then

        echo "${BASH_REMATCH[1]}"

    else

        echo "WARNING: Ignoring unexpected filename:"
        echo "${filename}" >&2

    fi

done | sort -u > list.txt


# ------------------------------------------------------------
# 8. Count samples
# ------------------------------------------------------------

if [[ ! -s list.txt ]]; then
    echo "ERROR: list.txt is empty." >&2
    echo "Expected filenames such as:" >&2
    echo "SAMPLE_trim1.fastq.gz" >&2
    echo "SAMPLE_trim2.fastq.gz" >&2
    exit 1
fi

NSAMPLES=$(wc -l < list.txt)

echo
echo "Sample list created successfully."
echo
echo "Number of FASTQ files : ${NFASTQ}"
echo "Number of samples     : ${NSAMPLES}"


# ------------------------------------------------------------
# 9. Check expected training dataset size
# ------------------------------------------------------------

echo
echo "=== Step 6: Checking expected dataset size ==="

if [[ "${NSAMPLES}" -ne 40 ]]; then
    echo "WARNING: Expected 40 samples but found ${NSAMPLES}." >&2
else
    echo "Correct number of samples detected: 40"
fi

if [[ "${NFASTQ}" -ne 80 ]]; then
    echo "WARNING: Expected 80 FASTQ files but found ${NFASTQ}." >&2
else
    echo "Correct number of FASTQ files detected: 80"
fi


# ------------------------------------------------------------
# 10. Check paired-end reads
# ------------------------------------------------------------

echo
echo "=== Step 7: Checking paired-end files ==="

MISSING_PAIRS=0

while read -r SAMPLE; do

    R1="${CENTRAL_DATA}/${SAMPLE}_trim1.fastq.gz"
    R2="${CENTRAL_DATA}/${SAMPLE}_trim2.fastq.gz"

    if [[ ! -f "${R1}" ]]; then
        echo "ERROR: Missing trim1 file for ${SAMPLE}" >&2
        MISSING_PAIRS=$((MISSING_PAIRS + 1))
    fi

    if [[ ! -f "${R2}" ]]; then
        echo "ERROR: Missing trim2 file for ${SAMPLE}" >&2
        MISSING_PAIRS=$((MISSING_PAIRS + 1))
    fi

done < list.txt


if [[ "${MISSING_PAIRS}" -gt 0 ]]; then

    echo
    echo "ERROR: ${MISSING_PAIRS} paired-end FASTQ file(s) are missing."
    echo "Please check the shared dataset before continuing." >&2
    exit 1

fi

echo "All ${NSAMPLES} samples have paired-end FASTQ files."


# ------------------------------------------------------------
# 11. Display sample list
# ------------------------------------------------------------

echo
echo "=== Step 8: Samples detected ==="
echo

nl -w2 -s'. ' list.txt


# ------------------------------------------------------------
# 12. Final summary
# ------------------------------------------------------------

echo
echo "============================================================"
echo " SETUP COMPLETED SUCCESSFULLY"
echo "============================================================"
echo
echo "Working directory : $(pwd)"
echo "Raw data          : raw_data/"
echo "FASTQ files       : ${NFASTQ}"
echo "Samples           : ${NSAMPLES}"
echo "Sample list       : list.txt"
echo
echo "Directories created:"
echo "  fastqc_files/"
echo "  clean_data/"
echo "  assembly/"
echo "  quality_assembly/"
echo "  annotation/"
echo "  mlsts/"
echo "  resistome/"
echo "  reports/"
echo "  phylogenetics/"
echo "  snps/"
echo
echo "Ready for:"
echo "Step 02 - Raw Read Quality Control"
echo "============================================================"

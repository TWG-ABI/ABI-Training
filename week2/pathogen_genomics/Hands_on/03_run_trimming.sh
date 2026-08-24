#!/bin/bash
#SBATCH --job-name=trimming
#SBATCH --output=reports/trimming_%j.out
#SBATCH --error=reports/trimming_%j.err
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=8G
#SBATCH --time=04:00:00

set -euo pipefail

# ============================================================
# 03_run_trimming.sh
# Bacterial Genomics Practical Training
#
# Purpose:
#   Perform adapter removal and quality trimming using
#   Trimmomatic.
#
# Input:
#   raw_data/SAMPLE_trim1.fastq.gz
#   raw_data/SAMPLE_trim2.fastq.gz
#   list.txt
#
# Output:
#   clean_data/SAMPLE_R1_paired.fastq.gz
#   clean_data/SAMPLE_R1_unpaired.fastq.gz
#   clean_data/SAMPLE_R2_paired.fastq.gz
#   clean_data/SAMPLE_R2_unpaired.fastq.gz
#
# Expected:
#   40 samples
# ============================================================


# ------------------------------------------------------------
# 1. Move to the directory where sbatch was submitted
# ------------------------------------------------------------

cd "${SLURM_SUBMIT_DIR:-$PWD}"

echo "============================================================"
echo " BACTERIAL GENOMICS TRAINING - READ TRIMMING"
echo "============================================================"
echo
echo "Working directory : $(pwd)"
echo "Node              : $(hostname)"
echo "SLURM Job ID      : ${SLURM_JOB_ID}"
echo "CPUs allocated    : ${SLURM_CPUS_PER_TASK}"
echo


# ------------------------------------------------------------
# 2. Load required software
# ------------------------------------------------------------

echo "=== Step 1: Loading Trimmomatic ==="

module load trimmomatic/0.40--hdfd78af_0

echo "Trimmomatic:"
which trimmomatic

echo


# ------------------------------------------------------------
# 3. Define paths
# ------------------------------------------------------------

RAW_DATA="raw_data"
OUTDIR="clean_data"

ADAPTERS="/etc/ace-data/ABI-SummerSchool-26/pathogen-genomics/adapters/TruSeq3-PE.fa"


# ------------------------------------------------------------
# 4. Check required inputs
# ------------------------------------------------------------

echo "=== Step 2: Checking input files ==="

if [[ ! -d "${RAW_DATA}" ]]; then
    echo "ERROR: ${RAW_DATA}/ does not exist." >&2
    echo "Run 01_setup_environment.sh first." >&2
    exit 1
fi

if [[ ! -f "list.txt" ]]; then
    echo "ERROR: list.txt not found." >&2
    echo "Run 01_setup_environment.sh first." >&2
    exit 1
fi

if [[ ! -f "${ADAPTERS}" ]]; then
    echo "ERROR: Adapter file not found:" >&2
    echo "${ADAPTERS}" >&2
    exit 1
fi

mkdir -p "${OUTDIR}"


# ------------------------------------------------------------
# 5. Check sample count
# ------------------------------------------------------------

NSAMPLES=$(wc -l < list.txt)

echo "Samples in list.txt : ${NSAMPLES}"

if [[ "${NSAMPLES}" -ne 40 ]]; then
    echo "WARNING: Expected 40 samples but found ${NSAMPLES}." >&2
fi


# ------------------------------------------------------------
# 6. Check all paired-end FASTQ files before trimming
# ------------------------------------------------------------

echo
echo "=== Step 3: Checking paired-end input files ==="

MISSING=0

while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue

    R1="${RAW_DATA}/${SAMPLE}_trim1.fastq.gz"
    R2="${RAW_DATA}/${SAMPLE}_trim2.fastq.gz"

    if [[ ! -f "${R1}" ]]; then
        echo "ERROR: Missing R1 for ${SAMPLE}" >&2
        MISSING=$((MISSING + 1))
    fi

    if [[ ! -f "${R2}" ]]; then
        echo "ERROR: Missing R2 for ${SAMPLE}" >&2
        MISSING=$((MISSING + 1))
    fi

done < list.txt


if [[ "${MISSING}" -gt 0 ]]; then
    echo
    echo "ERROR: ${MISSING} FASTQ file(s) are missing." >&2
    echo "Trimming will not start." >&2
    exit 1
fi

echo "All ${NSAMPLES} samples have paired-end input files."


# ------------------------------------------------------------
# 7. Run Trimmomatic
# ------------------------------------------------------------

echo
echo "=== Step 4: Running Trimmomatic ==="
echo

CURRENT=0

while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue

    CURRENT=$((CURRENT + 1))

    echo "------------------------------------------------------------"
    echo "Sample ${CURRENT}/${NSAMPLES}: ${SAMPLE}"
    echo "------------------------------------------------------------"

    R1="${RAW_DATA}/${SAMPLE}_trim1.fastq.gz"
    R2="${RAW_DATA}/${SAMPLE}_trim2.fastq.gz"

    trimmomatic PE \
        -threads "${SLURM_CPUS_PER_TASK}" \
        "${R1}" \
        "${R2}" \
        "${OUTDIR}/${SAMPLE}_R1_paired.fastq.gz" \
        "${OUTDIR}/${SAMPLE}_R1_unpaired.fastq.gz" \
        "${OUTDIR}/${SAMPLE}_R2_paired.fastq.gz" \
        "${OUTDIR}/${SAMPLE}_R2_unpaired.fastq.gz" \
        ILLUMINACLIP:"${ADAPTERS}":2:30:10 \
        LEADING:3 \
        TRAILING:3 \
        SLIDINGWINDOW:4:20 \
        MINLEN:36

    echo "Completed: ${SAMPLE}"
    echo

done < list.txt


# ------------------------------------------------------------
# 8. Verify trimmed output
# ------------------------------------------------------------

echo
echo "=== Step 5: Checking trimmed reads ==="

shopt -s nullglob

R1_PAIRED=("${OUTDIR}"/*_R1_paired.fastq.gz)
R2_PAIRED=("${OUTDIR}"/*_R2_paired.fastq.gz)

NR1=${#R1_PAIRED[@]}
NR2=${#R2_PAIRED[@]}

echo "R1 paired files : ${NR1}"
echo "R2 paired files : ${NR2}"


if [[ "${NR1}" -ne "${NSAMPLES}" ]]; then
    echo "ERROR: Expected ${NSAMPLES} paired R1 files but found ${NR1}." >&2
    exit 1
fi

if [[ "${NR2}" -ne "${NSAMPLES}" ]]; then
    echo "ERROR: Expected ${NSAMPLES} paired R2 files but found ${NR2}." >&2
    exit 1
fi


# ------------------------------------------------------------
# 9. Check that output files are not empty
# ------------------------------------------------------------

echo
echo "=== Step 6: Checking output file sizes ==="

EMPTY=0

while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue

    R1="${OUTDIR}/${SAMPLE}_R1_paired.fastq.gz"
    R2="${OUTDIR}/${SAMPLE}_R2_paired.fastq.gz"

    if [[ ! -s "${R1}" ]]; then
        echo "ERROR: Empty R1 output for ${SAMPLE}" >&2
        EMPTY=$((EMPTY + 1))
    fi

    if [[ ! -s "${R2}" ]]; then
        echo "ERROR: Empty R2 output for ${SAMPLE}" >&2
        EMPTY=$((EMPTY + 1))
    fi

done < list.txt


if [[ "${EMPTY}" -gt 0 ]]; then
    echo "ERROR: ${EMPTY} paired trimmed file(s) are empty." >&2
    exit 1
fi


# ------------------------------------------------------------
# 10. Final summary
# ------------------------------------------------------------

echo
echo "============================================================"
echo " READ TRIMMING COMPLETED SUCCESSFULLY"
echo "============================================================"
echo
echo "Samples processed : ${NSAMPLES}"
echo "Paired R1 files   : ${NR1}"
echo "Paired R2 files   : ${NR2}"
echo
echo "Trimmed reads:"
echo "  ${OUTDIR}/"
echo
echo "Naming convention:"
echo "  SAMPLE_R1_paired.fastq.gz"
echo "  SAMPLE_R2_paired.fastq.gz"
echo
echo "Unpaired reads are also retained in ${OUTDIR}/."
echo
echo "Ready for:"
echo "Step 04 - Genome Assembly"
echo "============================================================"

#!/bin/bash
#SBATCH --job-name=raw_qc
#SBATCH --output=reports/qc_%j.out
#SBATCH --error=reports/qc_%j.err
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=8G
#SBATCH --time=02:00:00

set -euo pipefail

# ============================================================
# 02_run_qc.sh
# Bacterial Genomics Practical Training
#
# Purpose:
#   Perform quality assessment of raw paired-end FASTQ files
#   using FastQC and summarize results using MultiQC.
#
# Input:
#   raw_data/*.fastq.gz
#
# Output:
#   fastqc_files/
# ============================================================


# ------------------------------------------------------------
# 1. Move to the directory where sbatch was submitted
# ------------------------------------------------------------

cd "${SLURM_SUBMIT_DIR:-$PWD}"

echo "============================================================"
echo " BACTERIAL GENOMICS TRAINING - RAW READ QC"
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

echo "=== Step 1: Loading software ==="

module load fastqc/v0.11.9_cv8
module load multiqc/1.35--pyhdfd78af_1

echo "FastQC:"
which fastqc

echo "MultiQC:"
which multiqc

echo


# ------------------------------------------------------------
# 3. Define paths
# ------------------------------------------------------------

RAW_DATA="raw_data"
OUTDIR="fastqc_files"


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
    echo "ERROR: list.txt does not exist." >&2
    echo "Run 01_setup_environment.sh first." >&2
    exit 1
fi

mkdir -p "${OUTDIR}"

shopt -s nullglob
FASTQ_FILES=("${RAW_DATA}"/*.fastq.gz)

NFASTQ=${#FASTQ_FILES[@]}

if (( NFASTQ == 0 )); then
    echo "ERROR: No FASTQ files found in ${RAW_DATA}/" >&2
    exit 1
fi

NSAMPLES=$(wc -l < list.txt)

echo "Samples detected : ${NSAMPLES}"
echo "FASTQ files      : ${NFASTQ}"


# ------------------------------------------------------------
# 5. Validate expected training dataset
# ------------------------------------------------------------

if [[ "${NSAMPLES}" -ne 40 ]]; then
    echo "WARNING: Expected 40 samples but found ${NSAMPLES}." >&2
fi

if [[ "${NFASTQ}" -ne 80 ]]; then
    echo "WARNING: Expected 80 FASTQ files but found ${NFASTQ}." >&2
fi


# ------------------------------------------------------------
# 6. Run FastQC
# ------------------------------------------------------------

echo
echo "=== Step 3: Running FastQC ==="

fastqc \
    "${FASTQ_FILES[@]}" \
    --outdir "${OUTDIR}" \
    --threads "${SLURM_CPUS_PER_TASK}"

echo
echo "FastQC completed successfully."


# ------------------------------------------------------------
# 7. Run MultiQC
# ------------------------------------------------------------

echo
echo "=== Step 4: Running MultiQC ==="

multiqc \
    "${OUTDIR}" \
    --force \
    --outdir "${OUTDIR}" \
    --filename "raw_reads_multiqc_report.html"

echo
echo "MultiQC completed successfully."


# ------------------------------------------------------------
# 8. Remove FastQC ZIP files
# ------------------------------------------------------------

echo
echo "=== Step 5: Cleaning FastQC ZIP files ==="

rm -f "${OUTDIR}"/*_fastqc.zip

echo "FastQC ZIP files removed."


# ------------------------------------------------------------
# 9. Check expected outputs
# ------------------------------------------------------------

echo
echo "=== Step 6: Checking QC outputs ==="

HTML_FILES=("${OUTDIR}"/*_fastqc.html)
NHTML=${#HTML_FILES[@]}

echo "FastQC HTML reports generated: ${NHTML}"

if [[ "${NHTML}" -ne "${NFASTQ}" ]]; then
    echo "WARNING: ${NFASTQ} FASTQ files were analysed but only"
    echo "${NHTML} FastQC HTML reports were found." >&2
fi

if [[ ! -f "${OUTDIR}/raw_reads_multiqc_report.html" ]]; then
    echo "ERROR: MultiQC report was not generated." >&2
    exit 1
fi


# ------------------------------------------------------------
# 10. Final summary
# ------------------------------------------------------------

echo
echo "============================================================"
echo " RAW READ QC COMPLETED SUCCESSFULLY"
echo "============================================================"
echo
echo "Samples analysed       : ${NSAMPLES}"
echo "FASTQ files analysed   : ${NFASTQ}"
echo "FastQC reports         : ${NHTML}"
echo
echo "Results directory:"
echo "  ${OUTDIR}/"
echo
echo "Main summary report:"
echo "  ${OUTDIR}/raw_reads_multiqc_report.html"
echo
echo "Ready for:"
echo "Step 03 - Read Trimming"
echo "============================================================"

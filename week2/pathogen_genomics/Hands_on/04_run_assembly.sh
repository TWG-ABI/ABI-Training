#!/bin/bash
#SBATCH --job-name=assembly
#SBATCH --output=reports/assembly_%j.out
#SBATCH --error=reports/assembly_%j.err
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=15:00:00

set -euo pipefail

# ============================================================
# 04_run_assembly.sh
# Bacterial Genomics Practical Training
#
# Purpose:
#   1. Perform de novo genome assembly using Shovill
#   2. Assess assembly quality using QUAST
#
# Input:
#   clean_data/SAMPLE_R1_paired.fastq.gz
#   clean_data/SAMPLE_R2_paired.fastq.gz
#   list.txt
#
# Output:
#   assembly/SAMPLE/contigs.fa
#   assembly/SAMPLE/SAMPLE.fasta
#
#   quality_assembly/SAMPLE_stats/
#   quality_assembly/combined/
#
# Expected dataset:
#   40 E. coli isolates
#
# HPC NOTE:
#   Shovill and QUAST are executed directly from Singularity
#   containers to avoid problems with the cluster module
#   wrappers/modulefiles.
# ============================================================


# ------------------------------------------------------------
# 1. Move to submission directory
# ------------------------------------------------------------

cd "${SLURM_SUBMIT_DIR:-$PWD}"

echo "============================================================"
echo " BACTERIAL GENOMICS TRAINING"
echo " DE NOVO ASSEMBLY AND QUALITY ASSESSMENT"
echo "============================================================"
echo

echo "Working directory : $(pwd)"
echo "Node              : $(hostname)"
echo "SLURM Job ID      : ${SLURM_JOB_ID:-NA}"
echo "CPUs allocated    : ${SLURM_CPUS_PER_TASK}"
echo "Memory allocated  : 16 GB"
echo


# ------------------------------------------------------------
# 2. Define Singularity containers
# ------------------------------------------------------------

SHOVILL_SIF="/etc/ace-data/rgc/containers/shovill/shovill-1.4.2--hdfd78af_0.sif"

QUAST_SIF="/etc/ace-data/rgc/containers/quast/quast-5.3.0--py313pl5321h5ca1c30_2.sif"


# ------------------------------------------------------------
# 3. Check Singularity
# ------------------------------------------------------------

echo "=== Step 1: Checking Singularity ==="

if ! command -v singularity >/dev/null 2>&1; then
    echo "ERROR: Singularity is not available." >&2
    exit 1
fi

echo "Singularity:"
command -v singularity
echo


# ------------------------------------------------------------
# 4. Check containers
# ------------------------------------------------------------

echo "=== Step 2: Checking software containers ==="


if [[ ! -s "${SHOVILL_SIF}" ]]; then
    echo "ERROR: Shovill container not found:" >&2
    echo "       ${SHOVILL_SIF}" >&2
    exit 1
fi


if [[ ! -s "${QUAST_SIF}" ]]; then
    echo "ERROR: QUAST container not found:" >&2
    echo "       ${QUAST_SIF}" >&2
    exit 1
fi


echo "Shovill container:"
echo "  ${SHOVILL_SIF}"

echo

echo "QUAST container:"
echo "  ${QUAST_SIF}"

echo


# ------------------------------------------------------------
# 5. Check software versions
# ------------------------------------------------------------

echo "=== Step 3: Checking software versions ==="

echo "Shovill:"
singularity exec "${SHOVILL_SIF}" shovill --version

echo

echo "QUAST:"

# QUAST 5.3.0 may print harmless Python SyntaxWarnings.
PYTHONWARNINGS="ignore::SyntaxWarning" \
singularity exec "${QUAST_SIF}" quast --version

echo


# ------------------------------------------------------------
# 6. Check Shovill dependencies
# ------------------------------------------------------------

echo "=== Step 4: Checking Shovill dependencies ==="

singularity exec \
    "${SHOVILL_SIF}" \
    shovill --check

echo

echo "Shovill dependency check completed."
echo


# ------------------------------------------------------------
# 7. Define paths
# ------------------------------------------------------------

INDIR="clean_data"

ASSEMBLY_DIR="assembly"

QUAST_DIR="quality_assembly"


mkdir -p \
    "${ASSEMBLY_DIR}" \
    "${QUAST_DIR}" \
    reports


# ------------------------------------------------------------
# 8. Check list.txt
# ------------------------------------------------------------

echo "=== Step 5: Checking sample list ==="

if [[ ! -s "list.txt" ]]; then

    echo "ERROR: list.txt not found or empty." >&2
    echo "Run 01_setup_environment.sh first." >&2

    exit 1

fi


NSAMPLES=$(grep -cve '^[[:space:]]*$' list.txt)


echo "Samples detected: ${NSAMPLES}"


if [[ "${NSAMPLES}" -ne 40 ]]; then

    echo "WARNING: Expected 40 samples but found ${NSAMPLES}." >&2

fi


# ------------------------------------------------------------
# 9. Check trimmed reads
# ------------------------------------------------------------

echo
echo "=== Step 6: Checking trimmed paired-end reads ==="

MISSING=0


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue


    R1="${INDIR}/${SAMPLE}_R1_paired.fastq.gz"

    R2="${INDIR}/${SAMPLE}_R2_paired.fastq.gz"


    if [[ ! -s "${R1}" ]]; then

        echo "ERROR: Missing or empty R1:" >&2
        echo "       ${R1}" >&2

        MISSING=$((MISSING + 1))

    fi


    if [[ ! -s "${R2}" ]]; then

        echo "ERROR: Missing or empty R2:" >&2
        echo "       ${R2}" >&2

        MISSING=$((MISSING + 1))

    fi


done < list.txt


if [[ "${MISSING}" -gt 0 ]]; then

    echo
    echo "ERROR: ${MISSING} FASTQ file(s) are missing or empty." >&2
    exit 1

fi


echo "All ${NSAMPLES} samples have paired trimmed reads."


# ============================================================
# 10. RUN SHOVILL
# ============================================================

echo
echo "============================================================"
echo " Step 7: Running Shovill assemblies"
echo "============================================================"
echo


CURRENT=0
ASSEMBLY_COUNT=0
SKIPPED_ASSEMBLIES=0


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue


    CURRENT=$((CURRENT + 1))


    R1="${INDIR}/${SAMPLE}_R1_paired.fastq.gz"

    R2="${INDIR}/${SAMPLE}_R2_paired.fastq.gz"

    SAMPLE_DIR="${ASSEMBLY_DIR}/${SAMPLE}"

    CONTIGS="${SAMPLE_DIR}/contigs.fa"

    SAMPLE_FASTA="${SAMPLE_DIR}/${SAMPLE}.fasta"


    echo "------------------------------------------------------------"
    echo "Sample ${CURRENT}/${NSAMPLES}: ${SAMPLE}"
    echo "------------------------------------------------------------"


    # --------------------------------------------------------
    # Restart-aware behaviour
    # --------------------------------------------------------

    if [[ -s "${SAMPLE_FASTA}" ]]; then

        echo "Existing assembly detected."
        echo "Skipping Shovill: ${SAMPLE_FASTA}"

        SKIPPED_ASSEMBLIES=$((SKIPPED_ASSEMBLIES + 1))

    else

        echo "Running Shovill..."

        # Remove an incomplete previous directory.
        if [[ -d "${SAMPLE_DIR}" ]]; then

            echo "Removing incomplete previous assembly directory:"
            echo "  ${SAMPLE_DIR}"

            rm -rf "${SAMPLE_DIR}"

        fi


        singularity exec \
            "${SHOVILL_SIF}" \
            shovill \
            --R1 "${R1}" \
            --R2 "${R2}" \
            --outdir "${SAMPLE_DIR}" \
            --cpus "${SLURM_CPUS_PER_TASK}" \
            --ram 14 \
            --gsize 5M \
            --force


        # ----------------------------------------------------
        # Check Shovill output
        # ----------------------------------------------------

        if [[ ! -s "${CONTIGS}" ]]; then

            echo "ERROR: Shovill failed to generate:" >&2
            echo "       ${CONTIGS}" >&2

            exit 1

        fi


        # Preserve the standard Shovill output contigs.fa
        # and create a sample-labelled FASTA.

        cp \
            "${CONTIGS}" \
            "${SAMPLE_FASTA}"


        if [[ ! -s "${SAMPLE_FASTA}" ]]; then

            echo "ERROR: Could not create:" >&2
            echo "       ${SAMPLE_FASTA}" >&2

            exit 1

        fi


        echo "Assembly completed: ${SAMPLE}"

    fi


    ASSEMBLY_COUNT=$((ASSEMBLY_COUNT + 1))

    echo


done < list.txt


# ------------------------------------------------------------
# 11. Verify all assemblies
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Step 8: Checking final assemblies"
echo "============================================================"

VALID_ASSEMBLIES=0


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue


    FASTA="${ASSEMBLY_DIR}/${SAMPLE}/${SAMPLE}.fasta"


    if [[ -s "${FASTA}" ]]; then

        VALID_ASSEMBLIES=$((VALID_ASSEMBLIES + 1))

    else

        echo "ERROR: Assembly missing:" >&2
        echo "       ${FASTA}" >&2

    fi


done < list.txt


echo "Valid assemblies: ${VALID_ASSEMBLIES}/${NSAMPLES}"


if [[ "${VALID_ASSEMBLIES}" -ne "${NSAMPLES}" ]]; then

    echo "ERROR: Not all assemblies are available." >&2
    exit 1

fi


# ============================================================
# 12. PER-SAMPLE QUAST
# ============================================================

echo
echo "============================================================"
echo " Step 9: Running individual QUAST assessments"
echo "============================================================"
echo


CURRENT=0
QUAST_COUNT=0
SKIPPED_QUAST=0


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue


    CURRENT=$((CURRENT + 1))


    FASTA="${ASSEMBLY_DIR}/${SAMPLE}/${SAMPLE}.fasta"

    SAMPLE_QUAST_DIR="${QUAST_DIR}/${SAMPLE}_stats"

    QUAST_REPORT="${SAMPLE_QUAST_DIR}/report.tsv"


    echo "------------------------------------------------------------"
    echo "QUAST ${CURRENT}/${NSAMPLES}: ${SAMPLE}"
    echo "------------------------------------------------------------"


    # Restart-aware QUAST behaviour.

    if [[ -s "${QUAST_REPORT}" ]]; then

        echo "Existing QUAST report detected."
        echo "Skipping QUAST: ${QUAST_REPORT}"

        SKIPPED_QUAST=$((SKIPPED_QUAST + 1))

    else

        # Remove a partial previous QUAST directory.

        if [[ -d "${SAMPLE_QUAST_DIR}" ]]; then
            rm -rf "${SAMPLE_QUAST_DIR}"
        fi


        PYTHONWARNINGS="ignore::SyntaxWarning" \
        singularity exec \
            "${QUAST_SIF}" \
            quast \
            "${FASTA}" \
            --output-dir "${SAMPLE_QUAST_DIR}" \
            --threads "${SLURM_CPUS_PER_TASK}" \
            --min-contig 200 \
            --silent


        if [[ ! -s "${QUAST_REPORT}" ]]; then

            echo "ERROR: QUAST report not generated for ${SAMPLE}" >&2
            exit 1

        fi


        echo "QUAST completed: ${SAMPLE}"

    fi


    QUAST_COUNT=$((QUAST_COUNT + 1))

    echo


done < list.txt


# ------------------------------------------------------------
# 13. Verify individual QUAST results
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Step 10: Checking individual QUAST results"
echo "============================================================"


VALID_QUAST=0


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue


    REPORT="${QUAST_DIR}/${SAMPLE}_stats/report.tsv"


    if [[ -s "${REPORT}" ]]; then

        VALID_QUAST=$((VALID_QUAST + 1))

    fi


done < list.txt


echo "Valid individual QUAST reports: ${VALID_QUAST}/${NSAMPLES}"


if [[ "${VALID_QUAST}" -ne "${NSAMPLES}" ]]; then

    echo "ERROR: Not all individual QUAST reports were generated." >&2
    exit 1

fi


# ============================================================
# 14. COMBINED QUAST
# ============================================================

echo
echo "============================================================"
echo " Step 11: Running combined QUAST comparison"
echo "============================================================"


ASSEMBLIES=()


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue


    ASSEMBLIES+=(
        "${ASSEMBLY_DIR}/${SAMPLE}/${SAMPLE}.fasta"
    )


done < list.txt


echo "Assemblies included: ${#ASSEMBLIES[@]}"


if [[ "${#ASSEMBLIES[@]}" -ne "${NSAMPLES}" ]]; then

    echo "ERROR: Expected ${NSAMPLES} assemblies but found ${#ASSEMBLIES[@]}." >&2

    exit 1

fi


COMBINED_DIR="${QUAST_DIR}/combined"

COMBINED_REPORT="${COMBINED_DIR}/report.tsv"


# Re-create combined report each time because it is inexpensive
# and ensures that the report represents the current complete set.

rm -rf "${COMBINED_DIR}"


PYTHONWARNINGS="ignore::SyntaxWarning" \
singularity exec \
    "${QUAST_SIF}" \
    quast \
    "${ASSEMBLIES[@]}" \
    --output-dir "${COMBINED_DIR}" \
    --threads "${SLURM_CPUS_PER_TASK}" \
    --min-contig 200 \
    --silent


# ------------------------------------------------------------
# 15. Validate combined QUAST
# ------------------------------------------------------------

echo
echo "=== Step 12: Checking combined QUAST report ==="


if [[ ! -s "${COMBINED_REPORT}" ]]; then

    echo "ERROR: Combined QUAST report was not generated:" >&2
    echo "       ${COMBINED_REPORT}" >&2

    exit 1

fi


echo "Combined QUAST report generated successfully."


# ------------------------------------------------------------
# 16. Show combined summary
# ------------------------------------------------------------

if [[ -s "${COMBINED_DIR}/report.txt" ]]; then

    echo
    echo "============================================================"
    echo " COMBINED QUAST SUMMARY"
    echo "============================================================"
    echo

    cat "${COMBINED_DIR}/report.txt"

fi


# ------------------------------------------------------------
# 17. Final summary
# ------------------------------------------------------------

echo
echo "============================================================"
echo " ASSEMBLY AND QUALITY ASSESSMENT COMPLETED SUCCESSFULLY"
echo "============================================================"
echo

echo "Samples                   : ${NSAMPLES}"
echo "Valid assemblies          : ${VALID_ASSEMBLIES}"
echo "Assemblies skipped        : ${SKIPPED_ASSEMBLIES}"
echo "Valid QUAST reports       : ${VALID_QUAST}"
echo "QUAST analyses skipped    : ${SKIPPED_QUAST}"

echo

echo "Assembly directory:"
echo "  ${ASSEMBLY_DIR}/"

echo

echo "Example:"
echo "  assembly/SAMPLE/contigs.fa"
echo "  assembly/SAMPLE/SAMPLE.fasta"

echo

echo "Individual QUAST results:"
echo "  ${QUAST_DIR}/SAMPLE_stats/"

echo

echo "Combined QUAST report:"
echo "  ${COMBINED_DIR}/report.html"
echo "  ${COMBINED_DIR}/report.tsv"
echo "  ${COMBINED_DIR}/report.txt"

echo

echo "Shovill container:"
echo "  ${SHOVILL_SIF}"

echo

echo "QUAST container:"
echo "  ${QUAST_SIF}"

echo

echo "Ready for:"
echo "Step 05 - Alignment and Variant Calling"

echo
echo "============================================================"

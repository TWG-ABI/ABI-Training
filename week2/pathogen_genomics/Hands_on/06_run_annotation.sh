#!/bin/bash
#SBATCH --job-name=prokka_annotation
#SBATCH --output=reports/annotation_%j.out
#SBATCH --error=reports/annotation_%j.err
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=24G
#SBATCH --time=16:00:00

set -euo pipefail

# ============================================================
# 06_run_annotation.sh
#
# Bacterial Genomics Practical Training
#
# Purpose:
#   Perform whole-genome functional annotation of assembled
#   Escherichia coli genomes using Prokka.
#
# Input:
#   assembly/<SAMPLE>/<SAMPLE>.fasta
#   list.txt
#
# Output:
#   annotation/<SAMPLE>/
#
# Important output for downstream Roary analysis:
#   annotation/<SAMPLE>/<SAMPLE>.gff
#
# HPC NOTE:
#   The Prokka modulefile on this cluster is currently broken.
#   Prokka is therefore executed directly from its confirmed
#   Singularity container.
# ============================================================


# ------------------------------------------------------------
# 1. Move to directory from which job was submitted
# ------------------------------------------------------------

cd "${SLURM_SUBMIT_DIR:-$PWD}"

echo "============================================================"
echo " BACTERIAL GENOMICS TRAINING"
echo " WHOLE-GENOME FUNCTIONAL ANNOTATION"
echo "============================================================"
echo
echo "Working directory : $(pwd)"
echo "Node              : $(hostname)"
echo "SLURM Job ID      : ${SLURM_JOB_ID}"
echo "CPUs allocated    : ${SLURM_CPUS_PER_TASK}"
echo "Memory requested  : 16 GB"
echo


# ============================================================
# A. CONFIGURE PROKKA CONTAINER
# ============================================================

echo "============================================================"
echo " A. Configuring Prokka Singularity container"
echo "============================================================"
echo


# ------------------------------------------------------------
# Check Singularity
# ------------------------------------------------------------

if ! command -v singularity >/dev/null 2>&1; then
    echo "ERROR: Singularity is not available." >&2
    exit 1
fi

echo "Singularity:"
command -v singularity
echo


# ------------------------------------------------------------
# Prokka container
# ------------------------------------------------------------

PROKKA_SIF="/etc/ace-data/rgc/containers/prokka/prokka-1.15.6--pl5321hdfd78af_0.sif"


if [[ ! -s "${PROKKA_SIF}" ]]; then
    echo "ERROR: Prokka container not found:" >&2
    echo "       ${PROKKA_SIF}" >&2
    exit 1
fi


echo "Prokka container:"
echo "  ${PROKKA_SIF}"
echo


# ------------------------------------------------------------
# Local Prokka command wrapper
#
# DO NOT use 'export -f'.
# ------------------------------------------------------------

prokka() {
    singularity exec "${PROKKA_SIF}" prokka "$@"
}


# ------------------------------------------------------------
# Check Prokka
# ------------------------------------------------------------

echo "Prokka version:"
prokka --version

echo
echo "Prokka container configured successfully."
echo


# ============================================================
# B. DEFINE INPUT AND OUTPUT DIRECTORIES
# ============================================================

ASM_DIR="assembly"
ANNOT_DIR="annotation"

mkdir -p "${ANNOT_DIR}" reports


echo "Input assembly directory:"
echo "  ${ASM_DIR}/"
echo

echo "Output annotation directory:"
echo "  ${ANNOT_DIR}/"
echo


# ============================================================
# C. CHECK SAMPLE LIST
# ============================================================

echo "============================================================"
echo " B. Checking sample list"
echo "============================================================"
echo


if [[ ! -s "list.txt" ]]; then
    echo "ERROR: list.txt not found or empty." >&2
    echo "Please run 01_setup_environment.sh first." >&2
    exit 1
fi


NSAMPLES=$(grep -cve '^[[:space:]]*$' list.txt)


echo "Samples detected: ${NSAMPLES}"


if [[ "${NSAMPLES}" -ne 40 ]]; then
    echo "WARNING: Expected 40 samples but found ${NSAMPLES}." >&2
fi


echo


# ============================================================
# D. CHECK ASSEMBLY INPUTS
# ============================================================

echo "============================================================"
echo " C. Checking assembled genomes"
echo "============================================================"
echo


MISSING=0


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue

    FASTA="${ASM_DIR}/${SAMPLE}/${SAMPLE}.fasta"

    if [[ ! -s "${FASTA}" ]]; then

        echo "ERROR: Assembly missing for ${SAMPLE}" >&2
        echo "       ${FASTA}" >&2

        MISSING=$((MISSING + 1))

    fi

done < list.txt


if [[ "${MISSING}" -gt 0 ]]; then

    echo
    echo "ERROR: ${MISSING} assembly file(s) are missing." >&2
    echo "Run or check 04_run_assembly.sh before annotation." >&2

    exit 1

fi


echo "All ${NSAMPLES} assembly FASTA files are available."
echo


# ============================================================
# E. RUN PROKKA
# ============================================================

echo "============================================================"
echo " D. Running Prokka genome annotation"
echo "============================================================"
echo


CURRENT=0


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue

    CURRENT=$((CURRENT + 1))


    # --------------------------------------------------------
    # Input/output paths
    # --------------------------------------------------------

    FASTA="${ASM_DIR}/${SAMPLE}/${SAMPLE}.fasta"

    OUT_SAMPLE="${ANNOT_DIR}/${SAMPLE}"


    # --------------------------------------------------------
    # Generate a safe unique locus tag
    #
    # EC001
    # EC002
    # ...
    # EC040
    #
    # This avoids using sample names containing hyphens or
    # other characters as locus tags.
    # --------------------------------------------------------

    LOCUSTAG=$(printf "EC%03d" "${CURRENT}")


    echo
    echo "------------------------------------------------------------"
    echo "Processing sample ${CURRENT}/${NSAMPLES}"
    echo "Sample    : ${SAMPLE}"
    echo "Locus tag : ${LOCUSTAG}"
    echo "Assembly  : ${FASTA}"
    echo "Output    : ${OUT_SAMPLE}"
    echo "------------------------------------------------------------"
    echo


    # --------------------------------------------------------
    # Remove any incomplete annotation from a previous run.
    #
    # This is important because earlier failed jobs may have
    # created partially populated Prokka directories.
    # --------------------------------------------------------

    if [[ -d "${OUT_SAMPLE}" ]]; then

        echo "Removing existing annotation directory:"
        echo "  ${OUT_SAMPLE}"

        rm -rf "${OUT_SAMPLE}"

    fi


    # --------------------------------------------------------
    # Run Prokka
    # --------------------------------------------------------

    prokka \
        --outdir "${OUT_SAMPLE}" \
        --prefix "${SAMPLE}" \
        --locustag "${LOCUSTAG}" \
        --kingdom Bacteria \
        --genus Escherichia \
        --species coli \
        --cpus "${SLURM_CPUS_PER_TASK}" \
        --force \
        "${FASTA}"


    # --------------------------------------------------------
    # Verify essential outputs
    # --------------------------------------------------------

    GFF="${OUT_SAMPLE}/${SAMPLE}.gff"

    FAA="${OUT_SAMPLE}/${SAMPLE}.faa"

    FFN="${OUT_SAMPLE}/${SAMPLE}.ffn"

    GBK="${OUT_SAMPLE}/${SAMPLE}.gbk"

    TXT="${OUT_SAMPLE}/${SAMPLE}.txt"


    if [[ ! -s "${GFF}" ]]; then

        echo
        echo "ERROR: Prokka did not produce GFF output for ${SAMPLE}." >&2
        exit 1

    fi


    if [[ ! -s "${FAA}" ]]; then

        echo
        echo "ERROR: Prokka did not produce protein FASTA for ${SAMPLE}." >&2
        exit 1

    fi


    if [[ ! -s "${FFN}" ]]; then

        echo
        echo "ERROR: Prokka did not produce nucleotide CDS file for ${SAMPLE}." >&2
        exit 1

    fi


    if [[ ! -s "${GBK}" ]]; then

        echo
        echo "ERROR: Prokka did not produce GenBank output for ${SAMPLE}." >&2
        exit 1

    fi


    echo
    echo "Completed annotation: ${SAMPLE}"

done < list.txt


# ============================================================
# F. VERIFY ALL ANNOTATIONS
# ============================================================

echo
echo "============================================================"
echo " E. Verifying Prokka outputs"
echo "============================================================"
echo


GFF_COUNT=0
FAA_COUNT=0
FFN_COUNT=0
GBK_COUNT=0
TXT_COUNT=0


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue


    [[ -s "${ANNOT_DIR}/${SAMPLE}/${SAMPLE}.gff" ]] \
        && GFF_COUNT=$((GFF_COUNT + 1))


    [[ -s "${ANNOT_DIR}/${SAMPLE}/${SAMPLE}.faa" ]] \
        && FAA_COUNT=$((FAA_COUNT + 1))


    [[ -s "${ANNOT_DIR}/${SAMPLE}/${SAMPLE}.ffn" ]] \
        && FFN_COUNT=$((FFN_COUNT + 1))


    [[ -s "${ANNOT_DIR}/${SAMPLE}/${SAMPLE}.gbk" ]] \
        && GBK_COUNT=$((GBK_COUNT + 1))


    [[ -s "${ANNOT_DIR}/${SAMPLE}/${SAMPLE}.txt" ]] \
        && TXT_COUNT=$((TXT_COUNT + 1))


done < list.txt


echo "GFF annotations       : ${GFF_COUNT}/${NSAMPLES}"
echo "Protein FASTA (.faa)  : ${FAA_COUNT}/${NSAMPLES}"
echo "CDS nucleotide (.ffn) : ${FFN_COUNT}/${NSAMPLES}"
echo "GenBank files (.gbk)  : ${GBK_COUNT}/${NSAMPLES}"
echo "Summary files (.txt)  : ${TXT_COUNT}/${NSAMPLES}"


# ------------------------------------------------------------
# Fail if any essential output is missing
# ------------------------------------------------------------

if [[ "${GFF_COUNT}" -ne "${NSAMPLES}" ]] ||
   [[ "${FAA_COUNT}" -ne "${NSAMPLES}" ]] ||
   [[ "${FFN_COUNT}" -ne "${NSAMPLES}" ]] ||
   [[ "${GBK_COUNT}" -ne "${NSAMPLES}" ]]; then

    echo
    echo "ERROR: One or more Prokka annotations are incomplete." >&2

    exit 1

fi


# ============================================================
# G. CREATE ANNOTATION SUMMARY TABLE
# ============================================================

echo
echo "============================================================"
echo " F. Creating annotation summary"
echo "============================================================"
echo


SUMMARY_FILE="${ANNOT_DIR}/annotation_summary.tsv"


printf "Sample\tLocus_tag\tCDS\ttRNA\trRNA\n" \
    > "${SUMMARY_FILE}"


CURRENT=0


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue

    CURRENT=$((CURRENT + 1))

    LOCUSTAG=$(printf "EC%03d" "${CURRENT}")

    GFF="${ANNOT_DIR}/${SAMPLE}/${SAMPLE}.gff"


    # --------------------------------------------------------
    # Count annotation feature types
    # --------------------------------------------------------

    CDS_COUNT=$(awk -F '\t' '
        $0 !~ /^#/ && $3 == "CDS" {
            count++
        }
        END {
            print count+0
        }
    ' "${GFF}")


    TRNA_COUNT=$(awk -F '\t' '
        $0 !~ /^#/ && $3 == "tRNA" {
            count++
        }
        END {
            print count+0
        }
    ' "${GFF}")


    RRNA_COUNT=$(awk -F '\t' '
        $0 !~ /^#/ && $3 == "rRNA" {
            count++
        }
        END {
            print count+0
        }
    ' "${GFF}")


    printf "%s\t%s\t%s\t%s\t%s\n" \
        "${SAMPLE}" \
        "${LOCUSTAG}" \
        "${CDS_COUNT}" \
        "${TRNA_COUNT}" \
        "${RRNA_COUNT}" \
        >> "${SUMMARY_FILE}"


done < list.txt


echo "Annotation summary created:"
echo "  ${SUMMARY_FILE}"
echo


# ------------------------------------------------------------
# Preview summary
# ------------------------------------------------------------

echo "Annotation summary preview:"
head "${SUMMARY_FILE}"
echo


# ============================================================
# H. FINAL STATUS
# ============================================================

echo "============================================================"
echo " PROKKA GENOME ANNOTATION COMPLETED SUCCESSFULLY"
echo "============================================================"
echo

echo "Samples annotated:"
echo "  ${NSAMPLES}"
echo

echo "GFF files:"
echo "  ${GFF_COUNT}/${NSAMPLES}"
echo

echo "Protein FASTA files:"
echo "  ${FAA_COUNT}/${NSAMPLES}"
echo

echo "GenBank files:"
echo "  ${GBK_COUNT}/${NSAMPLES}"
echo

echo "Main annotation directory:"
echo "  ${ANNOT_DIR}/"
echo

echo "Summary table:"
echo "  ${SUMMARY_FILE}"
echo

echo "Important downstream files:"
echo "  annotation/<SAMPLE>/<SAMPLE>.gff"
echo

echo "Ready for:"
echo "  Step 07 - Roary Pan-genome Analysis"
echo

echo "============================================================"

#!/bin/bash
#SBATCH --job-name=roary_pangenome
#SBATCH --output=reports/pangenome_%j.out
#SBATCH --error=reports/pangenome_%j.err
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=06:00:00

set -euo pipefail

# ============================================================
# 07_run_pangenome.sh
#
# Bacterial Genomics Practical Training
#
# Purpose:
#   Perform core/pan-genome analysis using Roary.
#
# Input:
#   annotation/<SAMPLE>/<SAMPLE>.gff
#   list.txt
#
# Output:
#   pangenome/
#
# Important outputs:
#   gene_presence_absence.csv
#   gene_presence_absence.Rtab
#   summary_statistics.txt
#   core_gene_alignment.aln
#
# Expected dataset:
#   40 E. coli isolates
#
# HPC NOTE:
#   Roary is executed directly from its Singularity container
#   because the cluster modulefile is unreliable.
# ============================================================


# ------------------------------------------------------------
# 1. Move to submission directory
# ------------------------------------------------------------

cd "${SLURM_SUBMIT_DIR:-$PWD}"

echo "============================================================"
echo " BACTERIAL GENOMICS TRAINING - PAN-GENOME ANALYSIS"
echo "============================================================"
echo
echo "Working directory : $(pwd)"
echo "Node              : $(hostname)"
echo "SLURM Job ID      : ${SLURM_JOB_ID}"
echo "CPUs allocated    : ${SLURM_CPUS_PER_TASK}"
echo


# ============================================================
# A. SET SAFE LOCALE
# ============================================================

# Prevent Perl/MAFFT locale warnings on compute nodes.
export LANG=C
export LC_ALL=C
export LANGUAGE=C


# ============================================================
# B. CONFIGURE ROARY CONTAINER
# ============================================================

echo "============================================================"
echo " A. Configuring Roary Singularity container"
echo "============================================================"
echo


if ! command -v singularity >/dev/null 2>&1; then
    echo "ERROR: Singularity is not available." >&2
    exit 1
fi


echo "Singularity:"
command -v singularity
echo


ROARY_SIF="/etc/ace-data/rgc/containers/roary/roary-3.7.0--0.sif"


if [[ ! -s "${ROARY_SIF}" ]]; then

    echo "ERROR: Roary container not found:" >&2
    echo "       ${ROARY_SIF}" >&2

    echo
    echo "Available Roary containers:" >&2

    ls -lh /etc/ace-data/rgc/containers/roary/ \
        2>/dev/null || true

    exit 1
fi


echo "Roary container:"
echo "  ${ROARY_SIF}"
echo


# ------------------------------------------------------------
# Local Roary wrapper
#
# Do NOT export this function.
# ------------------------------------------------------------

roary() {
    singularity exec "${ROARY_SIF}" roary "$@"
}


echo "Checking Roary:"
roary -w 2>&1 | head -n 5 || true

echo
echo "Roary container configured successfully."
echo


# ============================================================
# C. DEFINE PATHS
# ============================================================

ANNOT_DIR="annotation"

GFF_LIST="${ANNOT_DIR}/gff_files.txt"

PANGENOME_DIR="pangenome"

PANGENOME_ABS="$(pwd)/${PANGENOME_DIR}"

SVG_SCRIPT="scripts/roary2svg.pl"


mkdir -p reports


# ============================================================
# D. CHECK REQUIRED INPUTS
# ============================================================

echo "============================================================"
echo " B. Checking required inputs"
echo "============================================================"
echo


if [[ ! -s "list.txt" ]]; then

    echo "ERROR: list.txt not found or empty." >&2
    echo "Run 01_setup_environment.sh first." >&2

    exit 1
fi


if [[ ! -d "${ANNOT_DIR}" ]]; then

    echo "ERROR: ${ANNOT_DIR}/ does not exist." >&2
    echo "Run 06_run_annotation.sh first." >&2

    exit 1
fi


NSAMPLES=$(grep -cve '^[[:space:]]*$' list.txt)


echo "Samples in list.txt : ${NSAMPLES}"


if [[ "${NSAMPLES}" -ne 40 ]]; then

    echo "WARNING: Expected 40 samples but found ${NSAMPLES}." >&2

fi


# ============================================================
# E. GENERATE AND CHECK GFF LIST
# ============================================================

echo
echo "============================================================"
echo " C. Generating Prokka GFF input list"
echo "============================================================"
echo


: > "${GFF_LIST}"

MISSING=0

GFF_FILES=()


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue


    GFF_FILE="${ANNOT_DIR}/${SAMPLE}/${SAMPLE}.gff"


    if [[ ! -s "${GFF_FILE}" ]]; then

        echo "ERROR: Missing or empty GFF for ${SAMPLE}:" >&2
        echo "       ${GFF_FILE}" >&2

        MISSING=$((MISSING + 1))

    else

        # Store absolute paths to avoid ambiguity inside Singularity.
        GFF_ABS="$(readlink -f "${GFF_FILE}")"

        echo "${GFF_ABS}" >> "${GFF_LIST}"

        GFF_FILES+=("${GFF_ABS}")

    fi


done < list.txt


if [[ "${MISSING}" -gt 0 ]]; then

    echo
    echo "ERROR: ${MISSING} GFF file(s) are missing." >&2
    echo "Roary will not start." >&2

    exit 1
fi


NGFF_LIST=${#GFF_FILES[@]}


echo "GFF files found : ${NGFF_LIST}"


if [[ "${NGFF_LIST}" -ne "${NSAMPLES}" ]]; then

    echo
    echo "ERROR: Expected ${NSAMPLES} GFF files but found" >&2
    echo "       ${NGFF_LIST}." >&2

    exit 1
fi


echo
echo "All ${NGFF_LIST} Prokka GFF files are available."

echo
echo "GFF input list:"
echo "  ${GFF_LIST}"
echo


# ============================================================
# F. BASIC GFF VALIDATION
# ============================================================

echo "============================================================"
echo " D. Checking GFF contents"
echo "============================================================"
echo


INVALID_GFF=0


for GFF_FILE in "${GFF_FILES[@]}"; do

    CDS_COUNT=$(awk -F '\t' '
        $0 !~ /^#/ && $3 == "CDS" {
            count++
        }
        END {
            print count+0
        }
    ' "${GFF_FILE}")


    if [[ "${CDS_COUNT}" -eq 0 ]]; then

        echo "ERROR: No CDS features detected in:" >&2
        echo "       ${GFF_FILE}" >&2

        INVALID_GFF=$((INVALID_GFF + 1))

    fi

done


if [[ "${INVALID_GFF}" -gt 0 ]]; then

    echo
    echo "ERROR: ${INVALID_GFF} GFF file(s) appear invalid." >&2

    exit 1
fi


echo "All GFF files contain CDS annotations."
echo


# ============================================================
# G. CHECK OPTIONAL SVG SCRIPT
# ============================================================

echo "============================================================"
echo " E. Checking visualization script"
echo "============================================================"
echo


if [[ -f "${SVG_SCRIPT}" ]]; then

    echo "Found:"
    echo "  ${SVG_SCRIPT}"

else

    echo "WARNING: ${SVG_SCRIPT} was not found." >&2
    echo "Roary will run normally, but SVG generation will" >&2
    echo "be skipped." >&2

fi


# ============================================================
# H. PREPARE ROARY OUTPUT
# ============================================================

echo
echo "============================================================"
echo " F. Preparing Roary output"
echo "============================================================"
echo


# ------------------------------------------------------------
# IMPORTANT:
#
# Do NOT create pangenome/ before running Roary.
#
# Roary expects to create its output directory itself.
# Pre-creating the directory caused Roary to generate a
# timestamped directory such as:
#
#   pangenome_1786378141/
#
# while the script later checked:
#
#   pangenome/
#
# ------------------------------------------------------------

rm -rf "${PANGENOME_DIR}"


# ------------------------------------------------------------
# Record any existing timestamped Roary directories.
#
# This allows us to identify a newly generated fallback
# directory if Roary does not use the requested name.
# ------------------------------------------------------------

BEFORE_DIRS=$(mktemp)

find "$(pwd)" \
    -maxdepth 1 \
    -type d \
    -name 'pangenome_*' \
    -printf '%f\n' \
    | sort \
    > "${BEFORE_DIRS}"


echo "Requested output directory:"
echo "  ${PANGENOME_ABS}"
echo


# ============================================================
# I. RUN ROARY
# ============================================================

echo "============================================================"
echo " G. Running Roary"
echo "============================================================"
echo


echo "Parameters:"
echo "  Isolates                 : ${NSAMPLES}"
echo "  BLASTP identity threshold: 90%"
echo "  Core genome threshold    : 90%"
echo "  Core alignment           : enabled"
echo "  Alignment method         : MAFFT"
echo "  CPUs                     : ${SLURM_CPUS_PER_TASK}"
echo


# ------------------------------------------------------------
# Roary options
#
# -e       Create core gene alignment
# -n       Use MAFFT instead of PRANK
# -v       Verbose
# -i 90    Minimum BLASTP percentage identity
# -cd 90   Core gene present in >=90% isolates
# -p       Number of CPUs
# -f       Output directory
# ------------------------------------------------------------

roary \
    -e \
    -n \
    -v \
    -i 90 \
    -cd 90 \
    -p "${SLURM_CPUS_PER_TASK}" \
    -f "${PANGENOME_ABS}" \
    "${GFF_FILES[@]}"


echo
echo "Roary execution completed."
echo


# ============================================================
# J. LOCATE ACTUAL ROARY OUTPUT DIRECTORY
# ============================================================

echo "============================================================"
echo " H. Locating Roary output directory"
echo "============================================================"
echo


if [[ -s "${PANGENOME_DIR}/gene_presence_absence.csv" ]]; then

    echo "Roary used the requested output directory:"
    echo "  ${PANGENOME_DIR}/"

else

    echo "Requested directory was not populated."
    echo "Searching for a new timestamped Roary directory..."
    echo


    AFTER_DIRS=$(mktemp)


    find "$(pwd)" \
        -maxdepth 1 \
        -type d \
        -name 'pangenome_*' \
        -printf '%f\n' \
        | sort \
        > "${AFTER_DIRS}"


    NEW_DIR=$(
        comm -13 "${BEFORE_DIRS}" "${AFTER_DIRS}" \
        | tail -n 1
    )


    if [[ -z "${NEW_DIR}" ]]; then

        echo "ERROR: Could not locate Roary output directory." >&2

        rm -f "${BEFORE_DIRS}" "${AFTER_DIRS}"

        exit 1
    fi


    if [[ ! -s "${NEW_DIR}/gene_presence_absence.csv" ]]; then

        echo "ERROR: Candidate Roary directory does not contain" >&2
        echo "       gene_presence_absence.csv:" >&2
        echo "       ${NEW_DIR}" >&2

        rm -f "${BEFORE_DIRS}" "${AFTER_DIRS}"

        exit 1
    fi


    echo "Roary created:"
    echo "  ${NEW_DIR}/"

    echo
    echo "Renaming to:"
    echo "  ${PANGENOME_DIR}/"


    rm -rf "${PANGENOME_DIR}"

    mv "${NEW_DIR}" "${PANGENOME_DIR}"


    rm -f "${AFTER_DIRS}"

fi


rm -f "${BEFORE_DIRS}"


# ============================================================
# K. VERIFY MAIN ROARY OUTPUTS
# ============================================================

echo
echo "============================================================"
echo " I. Checking Roary outputs"
echo "============================================================"
echo


REQUIRED_OUTPUTS=(
    "${PANGENOME_DIR}/gene_presence_absence.csv"
    "${PANGENOME_DIR}/gene_presence_absence.Rtab"
    "${PANGENOME_DIR}/summary_statistics.txt"
    "${PANGENOME_DIR}/core_gene_alignment.aln"
)


for FILE in "${REQUIRED_OUTPUTS[@]}"; do

    if [[ ! -s "${FILE}" ]]; then

        echo "ERROR: Required Roary output missing:" >&2
        echo "       ${FILE}" >&2

        exit 1

    fi


    echo "Found:"
    echo "  ${FILE}"

done


echo
echo "All required Roary outputs were generated."
echo


# ============================================================
# L. OPTIONAL ACCESSORY GENE TREE
# ============================================================

TREE_FILE="${PANGENOME_DIR}/accessory_binary_genes.fa.newick"


if [[ -s "${TREE_FILE}" ]]; then

    echo "Accessory gene tree:"
    echo "  ${TREE_FILE}"

else

    echo "WARNING: Accessory gene tree was not generated." >&2

fi


# ============================================================
# M. DISPLAY PAN-GENOME SUMMARY
# ============================================================

echo
echo "============================================================"
echo " J. Pan-genome summary"
echo "============================================================"
echo


cat "${PANGENOME_DIR}/summary_statistics.txt"


# ============================================================
# N. GENERATE SVG VISUALIZATION
# ============================================================

echo
echo "============================================================"
echo " K. Generating presence/absence SVG"
echo "============================================================"
echo


if [[ -f "${SVG_SCRIPT}" ]]; then

    if command -v perl >/dev/null 2>&1; then

        perl "${SVG_SCRIPT}" \
            "${PANGENOME_DIR}/gene_presence_absence.csv" \
            > "${PANGENOME_DIR}/pangenome.svg" \
            || true


        if [[ -s "${PANGENOME_DIR}/pangenome.svg" ]]; then

            echo "SVG plot generated:"
            echo "  ${PANGENOME_DIR}/pangenome.svg"

        else

            echo "WARNING: SVG plot was not successfully generated." >&2

            rm -f "${PANGENOME_DIR}/pangenome.svg"

        fi

    else

        echo "WARNING: Perl is not available outside the container." >&2
        echo "SVG plot skipped." >&2

    fi

else

    echo "SVG plot skipped."

fi


# ============================================================
# O. CHECK CORE GENE ALIGNMENT
# ============================================================

echo
echo "============================================================"
echo " L. Checking core gene alignment"
echo "============================================================"
echo


CORE_ALIGNMENT="${PANGENOME_DIR}/core_gene_alignment.aln"


NSEQ=$(grep -c '^>' "${CORE_ALIGNMENT}" || true)


ALIGNMENT_LENGTH=$(awk '
    /^>/ {
        if (seen_sequence) {
            print length(seq)
            exit
        }

        seq=""
        seen_sequence=1
        next
    }

    {
        seq=seq $0
    }

    END {
        if (seen_sequence && seq != "") {
            print length(seq)
        }
    }
' "${CORE_ALIGNMENT}" | head -n1)


ALIGNMENT_LENGTH=${ALIGNMENT_LENGTH:-0}


echo "Sequences in core alignment : ${NSEQ}"
echo "Core alignment length        : ${ALIGNMENT_LENGTH} bp"


if [[ "${NSEQ}" -ne "${NSAMPLES}" ]]; then

    echo
    echo "WARNING: Expected ${NSAMPLES} sequences in the core" >&2
    echo "alignment but found ${NSEQ}." >&2

fi


# ============================================================
# P. COUNT PAN-GENOME GENE CLUSTERS
# ============================================================

echo
echo "============================================================"
echo " M. Counting pan-genome gene clusters"
echo "============================================================"
echo


# gene_presence_absence.Rtab contains one header row.

PAN_GENE_COUNT=$(awk '
    NR > 1 {
        count++
    }

    END {
        print count+0
    }
' "${PANGENOME_DIR}/gene_presence_absence.Rtab")


echo "Total pan-genome gene clusters : ${PAN_GENE_COUNT}"
echo


# ============================================================
# Q. FINAL SUMMARY
# ============================================================

echo "============================================================"
echo " PAN-GENOME ANALYSIS COMPLETED SUCCESSFULLY"
echo "============================================================"
echo


echo "Isolates analysed:"
echo "  ${NSAMPLES}"
echo


echo "GFF files analysed:"
echo "  ${NGFF_LIST}"
echo


echo "Pan-genome gene clusters:"
echo "  ${PAN_GENE_COUNT}"
echo


echo "Core alignment:"
echo "  ${NSEQ} sequences"
echo "  ${ALIGNMENT_LENGTH} bp"
echo


echo "Results directory:"
echo "  ${PANGENOME_DIR}/"
echo


echo "Important outputs:"
echo "  ${PANGENOME_DIR}/summary_statistics.txt"
echo "  ${PANGENOME_DIR}/gene_presence_absence.csv"
echo "  ${PANGENOME_DIR}/gene_presence_absence.Rtab"
echo "  ${PANGENOME_DIR}/core_gene_alignment.aln"


if [[ -s "${TREE_FILE}" ]]; then
    echo "  ${TREE_FILE}"
fi


if [[ -s "${PANGENOME_DIR}/pangenome.svg" ]]; then
    echo "  ${PANGENOME_DIR}/pangenome.svg"
fi


echo
echo "Ready for:"
echo "  Step 08 - MLST"
echo

echo "============================================================"

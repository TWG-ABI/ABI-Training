#!/bin/bash
#SBATCH --job-name=parsnp_phylo
#SBATCH --output=reports/phylo_%j.out
#SBATCH --error=reports/phylo_%j.err
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=20G
#SBATCH --time=12:00:00

set -euo pipefail

# ============================================================
# 10_run_phylogenetics.sh
#
# Bacterial Genomics Practical Training
#
# Purpose:
#   Perform core-genome alignment and phylogenetic analysis
#   of assembled E. coli genomes using Parsnp.
#
# Input:
#   assembly/<SAMPLE>/<SAMPLE>.fasta
#   Reference/Ecoli_Ref.fasta
#   list.txt
#
# Output:
#   phylogenetics/input_genomes/
#   phylogenetics/Phylogenetic_Tree/
#
# Expected dataset:
#   40 E. coli isolates
#
# HPC NOTE:
#   Parsnp is executed directly from its Singularity
#   container rather than through the cluster modulefile.
#
# RERUN NOTE:
#   Previous Parsnp outputs are removed before analysis and
#   --force-overwrite is also used to make reruns robust.
# ============================================================


# ------------------------------------------------------------
# 1. Move to submission directory
# ------------------------------------------------------------

cd "${SLURM_SUBMIT_DIR:-$PWD}"

echo "============================================================"
echo " BACTERIAL GENOMICS TRAINING"
echo " CORE-GENOME PHYLOGENETIC ANALYSIS"
echo "============================================================"
echo
echo "Working directory : $(pwd)"
echo "Node              : $(hostname)"
echo "SLURM Job ID      : ${SLURM_JOB_ID}"
echo "CPUs allocated    : ${SLURM_CPUS_PER_TASK}"
echo


# ============================================================
# A. CONFIGURE PARSNP CONTAINER
# ============================================================

echo "============================================================"
echo " A. Configuring Parsnp Singularity container"
echo "============================================================"
echo

if ! command -v singularity >/dev/null 2>&1; then
    echo "ERROR: Singularity is not available." >&2
    exit 1
fi

echo "Singularity:"
command -v singularity
echo


PARSNP_SIF="/etc/ace-data/rgc/containers/parsnp/parsnp-2.1.5--h077b44d_0.sif"

if [[ ! -s "${PARSNP_SIF}" ]]; then
    echo "ERROR: Parsnp container not found:" >&2
    echo "       ${PARSNP_SIF}" >&2
    exit 1
fi

echo "Parsnp container:"
echo "  ${PARSNP_SIF}"
echo


# ------------------------------------------------------------
# Local Parsnp wrapper
# ------------------------------------------------------------

parsnp() {
    singularity exec "${PARSNP_SIF}" parsnp "$@"
}


echo "Parsnp version:"
parsnp --version 2>&1 | head -n 5 || true

echo
echo "Parsnp container configured successfully."
echo


# ============================================================
# B. DEFINE PATHS
# ============================================================

ASM_DIR="assembly"

PHYLO_DIR="phylogenetics"

GENOMES_DIR="${PHYLO_DIR}/input_genomes"

TREE_OUT_DIR="${PHYLO_DIR}/Phylogenetic_Tree"

REFERENCE="Reference/Ecoli_Ref.fasta"

mkdir -p "${PHYLO_DIR}" reports


# ============================================================
# C. CHECK REQUIRED INPUTS
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

if [[ ! -d "${ASM_DIR}" ]]; then
    echo "ERROR: ${ASM_DIR}/ does not exist." >&2
    echo "Run 04_run_assembly.sh first." >&2
    exit 1
fi

if [[ ! -s "${REFERENCE}" ]]; then
    echo "ERROR: Reference genome not found or empty:" >&2
    echo "       ${REFERENCE}" >&2
    exit 1
fi


NSAMPLES=$(grep -cve '^[[:space:]]*$' list.txt)

echo "Samples detected : ${NSAMPLES}"
echo "Reference genome : ${REFERENCE}"

if [[ "${NSAMPLES}" -ne 40 ]]; then
    echo "WARNING: Expected 40 samples but found ${NSAMPLES}." >&2
fi


# ============================================================
# D. CHECK ALL ASSEMBLIES
# ============================================================

echo
echo "============================================================"
echo " C. Checking genome assemblies"
echo "============================================================"
echo

MISSING=0

while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue

    FASTA="${ASM_DIR}/${SAMPLE}/${SAMPLE}.fasta"

    if [[ ! -s "${FASTA}" ]]; then
        echo "ERROR: Assembly missing or empty for ${SAMPLE}" >&2
        echo "       ${FASTA}" >&2
        MISSING=$((MISSING + 1))
    fi

done < list.txt


if [[ "${MISSING}" -gt 0 ]]; then
    echo
    echo "ERROR: ${MISSING} assembly file(s) are missing or empty." >&2
    echo "Parsnp analysis will not start." >&2
    exit 1
fi


echo "All ${NSAMPLES} assemblies are available."
echo


# ============================================================
# E. PREPARE CLEAN WORKING DIRECTORIES
# ============================================================

echo "============================================================"
echo " D. Preparing phylogenetic directories"
echo "============================================================"
echo


# ------------------------------------------------------------
# Remove stale input genome copies
# ------------------------------------------------------------

if [[ -d "${GENOMES_DIR}" ]]; then
    echo "Removing previous input genome directory:"
    echo "  ${GENOMES_DIR}"
    rm -rf "${GENOMES_DIR}"
fi


# ------------------------------------------------------------
# Remove stale Parsnp output
# ------------------------------------------------------------

if [[ -d "${TREE_OUT_DIR}" ]]; then
    echo "Removing previous Parsnp output directory:"
    echo "  ${TREE_OUT_DIR}"
    rm -rf "${TREE_OUT_DIR}"
fi


mkdir -p "${GENOMES_DIR}"


echo
echo "Input genome directory:"
echo "  ${GENOMES_DIR}/"

echo
echo "Parsnp output directory:"
echo "  ${TREE_OUT_DIR}/"
echo


# ============================================================
# F. GATHER ASSEMBLIES
# ============================================================

echo "============================================================"
echo " E. Gathering genome assemblies"
echo "============================================================"
echo

COPIED=0

while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue

    FASTA="${ASM_DIR}/${SAMPLE}/${SAMPLE}.fasta"

    TARGET="${GENOMES_DIR}/${SAMPLE}.fasta"

    cp "${FASTA}" "${TARGET}"

    if [[ ! -s "${TARGET}" ]]; then
        echo "ERROR: Failed to copy assembly for ${SAMPLE}." >&2
        exit 1
    fi

    COPIED=$((COPIED + 1))

done < list.txt


echo "Assemblies copied: ${COPIED}"


if [[ "${COPIED}" -ne "${NSAMPLES}" ]]; then
    echo "ERROR: Expected ${NSAMPLES} assemblies but copied" >&2
    echo "       ${COPIED}." >&2
    exit 1
fi


GENOME_FILE_COUNT=$(
    find "${GENOMES_DIR}" \
        -maxdepth 1 \
        -type f \
        -name '*.fasta' \
        | wc -l
)


echo "Genome FASTA files in input directory:"
echo "  ${GENOME_FILE_COUNT}"


if [[ "${GENOME_FILE_COUNT}" -ne "${NSAMPLES}" ]]; then
    echo "ERROR: Input genome directory contains" >&2
    echo "       ${GENOME_FILE_COUNT} FASTA files;" >&2
    echo "       expected ${NSAMPLES}." >&2
    exit 1
fi


# ============================================================
# G. FINAL PRE-RUN CLEANUP
# ============================================================

echo
echo "============================================================"
echo " F. Final Parsnp output-directory check"
echo "============================================================"
echo


# ------------------------------------------------------------
# Important:
# Do NOT pre-create TREE_OUT_DIR before Parsnp.
#
# Parsnp creates this directory itself.
# This avoids:
#
#   CRITICAL - Output directory ... exists
#
# We nevertheless use --force-overwrite for additional safety.
# ------------------------------------------------------------

if [[ -e "${TREE_OUT_DIR}" ]]; then
    echo "Removing stale Parsnp output immediately before execution:"
    echo "  ${TREE_OUT_DIR}"
    rm -rf "${TREE_OUT_DIR}"
fi


if [[ -e "${TREE_OUT_DIR}" ]]; then
    echo "ERROR: Unable to remove previous Parsnp output directory." >&2
    exit 1
fi


echo "Parsnp output path is clear."
echo


# ============================================================
# H. RUN PARSNP
# ============================================================

echo "============================================================"
echo " G. Running Parsnp"
echo "============================================================"
echo


echo "Reference:"
echo "  ${REFERENCE}"

echo
echo "Query genomes:"
echo "  ${GENOMES_DIR}/"

echo
echo "Parameters:"
echo "  ANI filtering      : enabled"
echo "  Minimum ANI        : 95%"
echo "  Alignment program  : MAFFT"
echo "  CPUs               : ${SLURM_CPUS_PER_TASK}"
echo "  Force overwrite    : enabled"
echo


parsnp \
    -r "${REFERENCE}" \
    -d "${GENOMES_DIR}" \
    -p "${SLURM_CPUS_PER_TASK}" \
    --use-ani \
    --min-ani 95 \
    -n mafft \
    -o "${TREE_OUT_DIR}" \
    --force-overwrite


echo
echo "Parsnp execution completed."
echo


# ============================================================
# I. CHECK PARSNP OUTPUT DIRECTORY
# ============================================================

echo "============================================================"
echo " H. Checking Parsnp outputs"
echo "============================================================"
echo


if [[ ! -d "${TREE_OUT_DIR}" ]]; then
    echo "ERROR: Parsnp output directory was not created." >&2
    exit 1
fi


OUTPUT_COUNT=$(
    find "${TREE_OUT_DIR}" \
        -maxdepth 1 \
        -type f \
        | wc -l
)


echo "Files produced by Parsnp: ${OUTPUT_COUNT}"


if [[ "${OUTPUT_COUNT}" -eq 0 ]]; then
    echo "ERROR: Parsnp produced no output files." >&2
    exit 1
fi


echo
echo "Parsnp output files:"
echo


find "${TREE_OUT_DIR}" \
    -maxdepth 1 \
    -type f \
    -printf "  %f\n" \
    | sort


# ============================================================
# J. CHECK EXPECTED PARSNP OUTPUTS
# ============================================================

echo
echo "============================================================"
echo " I. Checking expected Parsnp files"
echo "============================================================"
echo


PARSNP_XMFA="${TREE_OUT_DIR}/parsnp.xmfa"

PARSNP_TREE="${TREE_OUT_DIR}/parsnp.tree"

PARSNP_GGR="${TREE_OUT_DIR}/parsnp.ggr"

PARSNP_LOG="${TREE_OUT_DIR}/parsnpAligner.log"


if [[ ! -s "${PARSNP_XMFA}" ]]; then
    echo "WARNING: Expected core alignment file not found:" >&2
    echo "         ${PARSNP_XMFA}" >&2
fi


if [[ ! -s "${PARSNP_TREE}" ]]; then
    echo "WARNING: Expected Parsnp tree not found:" >&2
    echo "         ${PARSNP_TREE}" >&2
fi


# ============================================================
# K. LOCATE TREE FILES
# ============================================================

echo
echo "============================================================"
echo " J. Locating phylogenetic tree files"
echo "============================================================"
echo


TREE_FILES=()

while IFS= read -r FILE; do

    [[ -z "${FILE}" ]] && continue

    TREE_FILES+=("${FILE}")

done < <(
    find "${TREE_OUT_DIR}" \
        -maxdepth 1 \
        -type f \
        \( \
            -name '*.tree' \
            -o -name '*.treefile' \
            -o -name '*.nwk' \
            -o -name '*.newick' \
        \) \
        | sort
)


if (( ${#TREE_FILES[@]} == 0 )); then

    echo "WARNING: No obvious tree file was found." >&2
    echo "Inspect the Parsnp output directory manually." >&2

else

    echo "Tree file(s):"

    for TREE in "${TREE_FILES[@]}"; do
        echo "  ${TREE}"
    done

fi


# ============================================================
# L. LOCATE CORE ALIGNMENT FILES
# ============================================================

echo
echo "============================================================"
echo " K. Locating core-genome alignment files"
echo "============================================================"
echo


ALIGNMENT_FILES=()

while IFS= read -r FILE; do

    [[ -z "${FILE}" ]] && continue

    ALIGNMENT_FILES+=("${FILE}")

done < <(
    find "${TREE_OUT_DIR}" \
        -maxdepth 1 \
        -type f \
        \( \
            -name '*.xmfa' \
            -o -name '*.aln' \
            -o -name '*.fasta' \
            -o -name '*.fa' \
        \) \
        | sort
)


if (( ${#ALIGNMENT_FILES[@]} > 0 )); then

    echo "Alignment-related files:"

    for ALN in "${ALIGNMENT_FILES[@]}"; do
        echo "  ${ALN}"
    done

else

    echo "WARNING: No obvious alignment file was detected." >&2

fi


# ============================================================
# M. CHECK TREE CONTENT
# ============================================================

echo
echo "============================================================"
echo " L. Checking phylogenetic tree"
echo "============================================================"
echo


if [[ -s "${PARSNP_TREE}" ]]; then

    echo "Parsnp tree:"
    echo "  ${PARSNP_TREE}"
    echo

    echo "Tree preview:"
    head -c 500 "${PARSNP_TREE}"
    echo
    echo

else

    echo "Parsnp standard tree file is unavailable."

fi


# ============================================================
# N. VERIFY TREE IS NON-EMPTY
# ============================================================

echo "============================================================"
echo " M. Verifying phylogenetic result"
echo "============================================================"
echo


if [[ -s "${PARSNP_TREE}" ]]; then

    TREE_SIZE=$(wc -c < "${PARSNP_TREE}")

    echo "Parsnp tree size:"
    echo "  ${TREE_SIZE} bytes"

    if [[ "${TREE_SIZE}" -le 5 ]]; then
        echo "WARNING: Parsnp tree appears unusually small." >&2
    fi

else

    echo "WARNING: Standard Parsnp tree could not be verified." >&2

fi


# ============================================================
# O. PRESERVE INPUT GENOME SET
# ============================================================

echo
echo "============================================================"
echo " N. Preserving input genome set"
echo "============================================================"
echo


echo "The genome copies used by Parsnp are retained in:"
echo "  ${GENOMES_DIR}/"

echo
echo "This allows trainees to verify exactly which genomes"
echo "were supplied to the phylogenetic analysis."
echo


# ============================================================
# P. FINAL SUMMARY
# ============================================================

echo "============================================================"
echo " PHYLOGENETIC ANALYSIS COMPLETED SUCCESSFULLY"
echo "============================================================"
echo


echo "Input samples:"
echo "  ${NSAMPLES}"
echo

echo "Assemblies supplied:"
echo "  ${COPIED}"
echo

echo "Reference genome:"
echo "  ${REFERENCE}"
echo

echo "Minimum ANI:"
echo "  95%"
echo

echo "Alignment method:"
echo "  MAFFT"
echo

echo "Parsnp results:"
echo "  ${TREE_OUT_DIR}/"
echo

echo "Input genome copies:"
echo "  ${GENOMES_DIR}/"


if [[ -s "${PARSNP_TREE}" ]]; then
    echo
    echo "Phylogenetic tree:"
    echo "  ${PARSNP_TREE}"
fi


if [[ -s "${PARSNP_XMFA}" ]]; then
    echo
    echo "Core-genome alignment:"
    echo "  ${PARSNP_XMFA}"
fi


echo
echo "============================================================"
echo " BACTERIAL GENOMICS TRAINING PIPELINE COMPLETE"
echo "============================================================"

#!/bin/bash
#SBATCH --job-name=abricate_profiling
#SBATCH --output=reports/abricate_%j.out
#SBATCH --error=reports/abricate_%j.err
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=24G
#SBATCH --time=08:00:00

set -euo pipefail

# ============================================================
# 09_run_amr_plasmids_virulence.sh
#
# Bacterial Genomics Practical Training
#
# Purpose:
#   Screen assembled E. coli genomes for:
#
#   1. Antimicrobial resistance genes
#      - ResFinder
#      - CARD
#      - ARG-ANNOT
#      - NCBI AMR
#
#   2. Virulence-associated genes
#      - VFDB
#      - E. coli-specific virulence database
#
#   3. Plasmid replicons
#      - PlasmidFinder
#
# Input:
#   assembly/<SAMPLE>/<SAMPLE>.fasta
#   list.txt
#
# Output:
#   resistome/ABRICATE/
#   resistome/virulence_factors/
#   resistome/plasmids/
#
# Expected dataset:
#   40 E. coli isolates
#
# HPC NOTE:
#   ABRicate is executed directly from its Singularity
#   container instead of through the cluster modulefile.
# ============================================================


# ------------------------------------------------------------
# 1. Move to submission directory
# ------------------------------------------------------------

cd "${SLURM_SUBMIT_DIR:-$PWD}"

echo "============================================================"
echo " BACTERIAL GENOMICS TRAINING"
echo " AMR, VIRULENCE AND PLASMID PROFILING"
echo "============================================================"
echo
echo "Working directory : $(pwd)"
echo "Node              : $(hostname)"
echo "SLURM Job ID      : ${SLURM_JOB_ID}"
echo "CPUs allocated    : ${SLURM_CPUS_PER_TASK}"
echo


# ============================================================
# A. CONFIGURE ABRICATE CONTAINER
# ============================================================

echo "============================================================"
echo " A. Configuring ABRicate Singularity container"
echo "============================================================"
echo


if ! command -v singularity >/dev/null 2>&1; then
    echo "ERROR: Singularity is not available." >&2
    exit 1
fi


echo "Singularity:"
command -v singularity
echo


ABRICATE_SIF="/etc/ace-data/rgc/containers/abricate/abricate-1.4.0--h05cac1d_0.sif"


if [[ ! -s "${ABRICATE_SIF}" ]]; then
    echo "ERROR: ABRicate container not found:" >&2
    echo "       ${ABRICATE_SIF}" >&2
    exit 1
fi


echo "ABRicate container:"
echo "  ${ABRICATE_SIF}"
echo


# ------------------------------------------------------------
# Local ABRicate wrapper.
#
# Do NOT export this function.
# ------------------------------------------------------------

abricate() {
    singularity exec "${ABRICATE_SIF}" abricate "$@"
}


echo "ABRicate version:"
abricate --version

echo
echo "ABRicate container configured successfully."
echo


# ============================================================
# B. DEFINE PATHS
# ============================================================

ASM_DIR="assembly"

RES_DIR="resistome"

AMR_DIR="${RES_DIR}/ABRICATE"

VIR_DIR="${RES_DIR}/virulence_factors"

PLS_DIR="${RES_DIR}/plasmids"


mkdir -p \
    "${AMR_DIR}" \
    "${VIR_DIR}" \
    "${PLS_DIR}" \
    reports


# ============================================================
# C. DEFINE SCREENING THRESHOLDS
# ============================================================

MIN_ID=80

MIN_COV=80


echo "ABRicate screening thresholds:"
echo "  Minimum identity : ${MIN_ID}%"
echo "  Minimum coverage : ${MIN_COV}%"
echo


# ============================================================
# D. DEFINE DATABASES
# ============================================================

AMR_DATABASES=(
    "resfinder"
    "card"
    "argannot"
    "ncbi"
)


VIR_DATABASES=(
    "vfdb"
    "ecoli_vf"
)


PLASMID_DATABASE="plasmidfinder"


# ============================================================
# E. CHECK REQUIRED INPUTS
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


NSAMPLES=$(grep -cve '^[[:space:]]*$' list.txt)


echo "Samples detected: ${NSAMPLES}"


if [[ "${NSAMPLES}" -ne 40 ]]; then
    echo "WARNING: Expected 40 samples but found ${NSAMPLES}." >&2
fi


# ============================================================
# F. CHECK ALL GENOME ASSEMBLIES
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
    echo "ABRicate analysis will not start." >&2

    exit 1

fi


echo "All ${NSAMPLES} assemblies are available."
echo


# ============================================================
# G. CHECK ABRICATE DATABASES
# ============================================================

echo "============================================================"
echo " D. Checking ABRicate databases"
echo "============================================================"
echo


DB_LIST=$(mktemp)

trap 'rm -f "${DB_LIST}"' EXIT


abricate --list > "${DB_LIST}"


echo "Available databases:"
echo

cat "${DB_LIST}"

echo


REQUIRED_DATABASES=(
    "resfinder"
    "card"
    "argannot"
    "ncbi"
    "vfdb"
    "ecoli_vf"
    "plasmidfinder"
)


for DB in "${REQUIRED_DATABASES[@]}"; do

    if ! awk 'NR > 1 {print $1}' "${DB_LIST}" \
        | grep -qx "${DB}"
    then

        echo "ERROR: Required ABRicate database '${DB}'" >&2
        echo "is unavailable in the current container." >&2

        exit 1

    fi

done


echo
echo "All required ABRicate databases are available."
echo


# ============================================================
# H. PREPARE CLEAN OUTPUT DIRECTORIES
# ============================================================

echo "============================================================"
echo " E. Preparing output directories"
echo "============================================================"
echo


# ------------------------------------------------------------
# Recreate only ABRicate output directories.
# ------------------------------------------------------------

rm -rf "${AMR_DIR}"
rm -rf "${VIR_DIR}"
rm -rf "${PLS_DIR}"


mkdir -p \
    "${AMR_DIR}" \
    "${VIR_DIR}" \
    "${PLS_DIR}"


echo "Output directories ready."
echo


# ============================================================
# I. AMR GENE SCREENING
# ============================================================

echo "============================================================"
echo " F. Screening antimicrobial resistance genes"
echo "============================================================"
echo


CURRENT=0


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue

    CURRENT=$((CURRENT + 1))


    FASTA="${ASM_DIR}/${SAMPLE}/${SAMPLE}.fasta"

    SAMPLE_AMR_DIR="${AMR_DIR}/${SAMPLE}"

    mkdir -p "${SAMPLE_AMR_DIR}"


    echo "------------------------------------------------------------"
    echo "AMR screening ${CURRENT}/${NSAMPLES}: ${SAMPLE}"
    echo "------------------------------------------------------------"


    for DB in "${AMR_DATABASES[@]}"; do

        echo "Database: ${DB}"


        OUTPUT="${SAMPLE_AMR_DIR}/${SAMPLE}_${DB}.tab"


        abricate \
            --db "${DB}" \
            --minid "${MIN_ID}" \
            --mincov "${MIN_COV}" \
            --threads "${SLURM_CPUS_PER_TASK}" \
            --nopath \
            "${FASTA}" \
            > "${OUTPUT}"


        # ----------------------------------------------------
        # ABRicate output normally contains a header even when
        # no gene hit is detected, so an existing file is the
        # appropriate execution check.
        # ----------------------------------------------------

        if [[ ! -f "${OUTPUT}" ]]; then

            echo "ERROR: ABRicate output not generated:" >&2
            echo "       ${OUTPUT}" >&2

            exit 1

        fi

    done


    # --------------------------------------------------------
    # Sample-level combined AMR summary
    # --------------------------------------------------------

    abricate --summary \
        "${SAMPLE_AMR_DIR}/${SAMPLE}_resfinder.tab" \
        "${SAMPLE_AMR_DIR}/${SAMPLE}_card.tab" \
        "${SAMPLE_AMR_DIR}/${SAMPLE}_argannot.tab" \
        "${SAMPLE_AMR_DIR}/${SAMPLE}_ncbi.tab" \
        > "${SAMPLE_AMR_DIR}/${SAMPLE}_AMR_summary.tab"


    echo
    echo "Completed AMR screening: ${SAMPLE}"
    echo


done < list.txt


# ============================================================
# J. CREATE AMR DATABASE-SPECIFIC SUMMARIES
# ============================================================

echo "============================================================"
echo " G. Creating AMR summary tables"
echo "============================================================"
echo


for DB in "${AMR_DATABASES[@]}"; do

    AMR_FILES=()


    while read -r SAMPLE; do

        [[ -z "${SAMPLE}" ]] && continue


        AMR_FILES+=(
            "${AMR_DIR}/${SAMPLE}/${SAMPLE}_${DB}.tab"
        )


    done < list.txt


    abricate --summary \
        "${AMR_FILES[@]}" \
        > "${AMR_DIR}/summary_${DB}.tab"


done


echo "AMR summary tables created."
echo


# ============================================================
# K. VIRULENCE GENE SCREENING
# ============================================================

echo "============================================================"
echo " H. Screening virulence-associated genes"
echo "============================================================"
echo


CURRENT=0


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue

    CURRENT=$((CURRENT + 1))


    FASTA="${ASM_DIR}/${SAMPLE}/${SAMPLE}.fasta"


    echo "------------------------------------------------------------"
    echo "Virulence screening ${CURRENT}/${NSAMPLES}: ${SAMPLE}"
    echo "------------------------------------------------------------"


    for DB in "${VIR_DATABASES[@]}"; do

        echo "Database: ${DB}"


        OUTPUT="${VIR_DIR}/${SAMPLE}_${DB}.tab"


        abricate \
            --db "${DB}" \
            --minid "${MIN_ID}" \
            --mincov "${MIN_COV}" \
            --threads "${SLURM_CPUS_PER_TASK}" \
            --nopath \
            "${FASTA}" \
            > "${OUTPUT}"


        if [[ ! -f "${OUTPUT}" ]]; then

            echo "ERROR: Virulence output not generated:" >&2
            echo "       ${OUTPUT}" >&2

            exit 1

        fi

    done


    echo "Completed virulence screening: ${SAMPLE}"
    echo


done < list.txt


# ============================================================
# L. CREATE VIRULENCE SUMMARIES
# ============================================================

echo "============================================================"
echo " I. Creating virulence summary tables"
echo "============================================================"
echo


for DB in "${VIR_DATABASES[@]}"; do

    VIR_FILES=()


    while read -r SAMPLE; do

        [[ -z "${SAMPLE}" ]] && continue


        VIR_FILES+=(
            "${VIR_DIR}/${SAMPLE}_${DB}.tab"
        )


    done < list.txt


    abricate --summary \
        "${VIR_FILES[@]}" \
        > "${VIR_DIR}/summary_${DB}.tab"


done


echo "Virulence summary tables created."
echo


# ============================================================
# M. PLASMID REPLICON SCREENING
# ============================================================

echo "============================================================"
echo " J. Screening plasmid replicons"
echo "============================================================"
echo


CURRENT=0


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue

    CURRENT=$((CURRENT + 1))


    FASTA="${ASM_DIR}/${SAMPLE}/${SAMPLE}.fasta"

    OUTPUT="${PLS_DIR}/${SAMPLE}_plasmidfinder.tab"


    echo "------------------------------------------------------------"
    echo "PlasmidFinder ${CURRENT}/${NSAMPLES}: ${SAMPLE}"
    echo "------------------------------------------------------------"


    abricate \
        --db "${PLASMID_DATABASE}" \
        --minid "${MIN_ID}" \
        --mincov "${MIN_COV}" \
        --threads "${SLURM_CPUS_PER_TASK}" \
        --nopath \
        "${FASTA}" \
        > "${OUTPUT}"


    if [[ ! -f "${OUTPUT}" ]]; then

        echo "ERROR: PlasmidFinder output not generated:" >&2
        echo "       ${OUTPUT}" >&2

        exit 1

    fi


done < list.txt


# ============================================================
# N. CREATE PLASMID SUMMARY
# ============================================================

echo
echo "============================================================"
echo " K. Creating plasmid summary"
echo "============================================================"
echo


PLASMID_FILES=()


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue


    PLASMID_FILES+=(
        "${PLS_DIR}/${SAMPLE}_plasmidfinder.tab"
    )


done < list.txt


abricate --summary \
    "${PLASMID_FILES[@]}" \
    > "${PLS_DIR}/summary_plasmidfinder.tab"


echo "Plasmid summary table created."
echo


# ============================================================
# O. VERIFY OUTPUTS
# ============================================================

echo "============================================================"
echo " L. Checking ABRicate outputs"
echo "============================================================"
echo


RESFINDER_COUNT=0
CARD_COUNT=0
ARGANNOT_COUNT=0
NCBI_COUNT=0

VFDB_COUNT=0
ECOLI_VF_COUNT=0

PLASMID_COUNT=0


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue


    [[ -f "${AMR_DIR}/${SAMPLE}/${SAMPLE}_resfinder.tab" ]] \
        && RESFINDER_COUNT=$((RESFINDER_COUNT + 1))

    [[ -f "${AMR_DIR}/${SAMPLE}/${SAMPLE}_card.tab" ]] \
        && CARD_COUNT=$((CARD_COUNT + 1))

    [[ -f "${AMR_DIR}/${SAMPLE}/${SAMPLE}_argannot.tab" ]] \
        && ARGANNOT_COUNT=$((ARGANNOT_COUNT + 1))

    [[ -f "${AMR_DIR}/${SAMPLE}/${SAMPLE}_ncbi.tab" ]] \
        && NCBI_COUNT=$((NCBI_COUNT + 1))


    [[ -f "${VIR_DIR}/${SAMPLE}_vfdb.tab" ]] \
        && VFDB_COUNT=$((VFDB_COUNT + 1))

    [[ -f "${VIR_DIR}/${SAMPLE}_ecoli_vf.tab" ]] \
        && ECOLI_VF_COUNT=$((ECOLI_VF_COUNT + 1))


    [[ -f "${PLS_DIR}/${SAMPLE}_plasmidfinder.tab" ]] \
        && PLASMID_COUNT=$((PLASMID_COUNT + 1))


done < list.txt


echo "AMR:"
echo "  ResFinder       : ${RESFINDER_COUNT}/${NSAMPLES}"
echo "  CARD            : ${CARD_COUNT}/${NSAMPLES}"
echo "  ARG-ANNOT       : ${ARGANNOT_COUNT}/${NSAMPLES}"
echo "  NCBI AMR        : ${NCBI_COUNT}/${NSAMPLES}"

echo
echo "Virulence:"
echo "  VFDB            : ${VFDB_COUNT}/${NSAMPLES}"
echo "  E. coli VF      : ${ECOLI_VF_COUNT}/${NSAMPLES}"

echo
echo "Plasmids:"
echo "  PlasmidFinder   : ${PLASMID_COUNT}/${NSAMPLES}"
echo


# ============================================================
# P. FAIL IF OUTPUTS ARE INCOMPLETE
# ============================================================

if [[ "${RESFINDER_COUNT}" -ne "${NSAMPLES}" ]] ||
   [[ "${CARD_COUNT}" -ne "${NSAMPLES}" ]] ||
   [[ "${ARGANNOT_COUNT}" -ne "${NSAMPLES}" ]] ||
   [[ "${NCBI_COUNT}" -ne "${NSAMPLES}" ]] ||
   [[ "${VFDB_COUNT}" -ne "${NSAMPLES}" ]] ||
   [[ "${ECOLI_VF_COUNT}" -ne "${NSAMPLES}" ]] ||
   [[ "${PLASMID_COUNT}" -ne "${NSAMPLES}" ]]
then

    echo
    echo "ERROR: One or more expected ABRicate outputs are missing." >&2

    exit 1

fi


# ============================================================
# Q. CHECK COMBINED SUMMARY TABLES
# ============================================================

SUMMARY_FILES=(
    "${AMR_DIR}/summary_resfinder.tab"
    "${AMR_DIR}/summary_card.tab"
    "${AMR_DIR}/summary_argannot.tab"
    "${AMR_DIR}/summary_ncbi.tab"
    "${VIR_DIR}/summary_vfdb.tab"
    "${VIR_DIR}/summary_ecoli_vf.tab"
    "${PLS_DIR}/summary_plasmidfinder.tab"
)


for FILE in "${SUMMARY_FILES[@]}"; do

    if [[ ! -f "${FILE}" ]]; then

        echo "ERROR: Expected summary table missing:" >&2
        echo "       ${FILE}" >&2

        exit 1

    fi

done


# ============================================================
# R. DISPLAY SUMMARY LOCATIONS
# ============================================================

echo
echo "============================================================"
echo " SUMMARY TABLES"
echo "============================================================"
echo

echo "AMR:"
echo "  ${AMR_DIR}/summary_resfinder.tab"
echo "  ${AMR_DIR}/summary_card.tab"
echo "  ${AMR_DIR}/summary_argannot.tab"
echo "  ${AMR_DIR}/summary_ncbi.tab"

echo
echo "Virulence:"
echo "  ${VIR_DIR}/summary_vfdb.tab"
echo "  ${VIR_DIR}/summary_ecoli_vf.tab"

echo
echo "Plasmids:"
echo "  ${PLS_DIR}/summary_plasmidfinder.tab"


# ============================================================
# S. FINAL SUMMARY
# ============================================================

echo
echo "============================================================"
echo " ABRICATE PROFILING COMPLETED SUCCESSFULLY"
echo "============================================================"
echo


echo "Samples analysed:"
echo "  ${NSAMPLES}"

echo
echo "Minimum identity:"
echo "  ${MIN_ID}%"

echo
echo "Minimum coverage:"
echo "  ${MIN_COV}%"

echo
echo "AMR databases:"
echo "  ResFinder"
echo "  CARD"
echo "  ARG-ANNOT"
echo "  NCBI AMR"

echo
echo "Virulence databases:"
echo "  VFDB"
echo "  E. coli VF"

echo
echo "Plasmid database:"
echo "  PlasmidFinder"

echo
echo "Results directory:"
echo "  ${RES_DIR}/"

echo
echo "Ready for:"
echo "  Step 10 - Phylogenetic Analysis"

echo "============================================================"

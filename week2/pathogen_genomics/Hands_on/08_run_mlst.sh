#!/bin/bash
#SBATCH --job-name=mlst_profiling
#SBATCH --output=reports/mlst_%j.out
#SBATCH --error=reports/mlst_%j.err
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --time=01:00:00

set -euo pipefail

# ============================================================
# 08_run_mlst.sh
#
# Bacterial Genomics Practical Training
#
# Purpose:
#   Perform multilocus sequence typing (MLST) of assembled
#   E. coli genomes using the Achtman MLST scheme.
#
# Input:
#   assembly/<SAMPLE>/<SAMPLE>.fasta
#   list.txt
#
# Output:
#   mlsts/<SAMPLE>_mlst.tsv
#   mlsts/summary-mlst.tsv
#   mlsts/sequence_type_counts.tsv
#   mlsts/unresolved_sequence_types.tsv
#   mlsts/uncertain_allele_calls.tsv
#
# MLST scheme:
#   ecoli_achtman_4
#
# Expected dataset:
#   40 E. coli isolates
#
# HPC NOTE:
#   MLST is executed directly from its Singularity container
#   rather than through the cluster modulefile.
# ============================================================


# ------------------------------------------------------------
# 1. Move to submission directory
# ------------------------------------------------------------

cd "${SLURM_SUBMIT_DIR:-$PWD}"

echo "============================================================"
echo " BACTERIAL GENOMICS TRAINING - MLST PROFILING"
echo "============================================================"
echo
echo "Working directory : $(pwd)"
echo "Node              : $(hostname)"
echo "SLURM Job ID      : ${SLURM_JOB_ID}"
echo "CPUs allocated    : ${SLURM_CPUS_PER_TASK}"
echo


# ============================================================
# A. CONFIGURE MLST CONTAINER
# ============================================================

echo "============================================================"
echo " A. Configuring MLST Singularity container"
echo "============================================================"
echo

if ! command -v singularity >/dev/null 2>&1; then
    echo "ERROR: Singularity is not available." >&2
    exit 1
fi

echo "Singularity:"
command -v singularity
echo

MLST_SIF="/etc/ace-data/rgc/containers/mlst/mlst-2.35.0--hdfd78af_0.sif"

if [[ ! -s "${MLST_SIF}" ]]; then
    echo "ERROR: MLST container not found:" >&2
    echo "       ${MLST_SIF}" >&2
    exit 1
fi

echo "MLST container:"
echo "  ${MLST_SIF}"
echo


# ------------------------------------------------------------
# Local MLST wrapper
# ------------------------------------------------------------

mlst() {
    singularity exec "${MLST_SIF}" mlst "$@"
}

echo "MLST version:"
mlst --version 2>&1 | head -n 5
echo

echo "MLST container configured successfully."
echo


# ============================================================
# B. DEFINE PATHS AND MLST SCHEME
# ============================================================

ASM_DIR="assembly"
MLST_DIR="mlsts"

MLST_SCHEME="ecoli_achtman_4"

SUMMARY_FILE="${MLST_DIR}/summary-mlst.tsv"
ST_COUNTS="${MLST_DIR}/sequence_type_counts.tsv"

UNRESOLVED_FILE="${MLST_DIR}/unresolved_sequence_types.tsv"
UNCERTAIN_FILE="${MLST_DIR}/uncertain_allele_calls.tsv"

mkdir -p "${MLST_DIR}" reports


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

NSAMPLES=$(grep -cve '^[[:space:]]*$' list.txt)

echo "Samples detected : ${NSAMPLES}"
echo "MLST scheme      : ${MLST_SCHEME}"

if [[ "${NSAMPLES}" -ne 40 ]]; then
    echo "WARNING: Expected 40 samples but found ${NSAMPLES}." >&2
fi

echo


# ============================================================
# D. CONFIRM ACHTMAN MLST SCHEME
# ============================================================

echo "============================================================"
echo " C. Checking MLST scheme"
echo "============================================================"
echo

if ! mlst --list 2>&1 \
    | tr '[:space:]' '\n' \
    | grep -qx "${MLST_SCHEME}"
then
    echo "ERROR: MLST scheme '${MLST_SCHEME}' is not available." >&2
    echo
    echo "Available E. coli-related schemes:" >&2

    mlst --list 2>&1 \
        | tr '[:space:]' '\n' \
        | grep -i 'ecoli' \
        || true

    exit 1
fi

echo "MLST scheme available:"
echo "  ${MLST_SCHEME}"
echo


# ============================================================
# E. CHECK ALL ASSEMBLIES
# ============================================================

echo "============================================================"
echo " D. Checking assemblies"
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
    echo "MLST analysis will not start." >&2
    exit 1
fi

echo "All ${NSAMPLES} assemblies are available."
echo


# ============================================================
# F. PREPARE OUTPUT DIRECTORY
# ============================================================

echo "============================================================"
echo " E. Preparing MLST output directory"
echo "============================================================"
echo

rm -f "${MLST_DIR}"/*_mlst.tsv
rm -f "${SUMMARY_FILE}"
rm -f "${ST_COUNTS}"
rm -f "${UNRESOLVED_FILE}"
rm -f "${UNCERTAIN_FILE}"

echo "Output directory ready:"
echo "  ${MLST_DIR}/"
echo


# ============================================================
# G. RUN MLST FOR EACH SAMPLE
# ============================================================

echo "============================================================"
echo " F. Running E. coli Achtman MLST"
echo "============================================================"
echo

CURRENT=0

while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue

    CURRENT=$((CURRENT + 1))

    FASTA="${ASM_DIR}/${SAMPLE}/${SAMPLE}.fasta"
    OUT_TSV="${MLST_DIR}/${SAMPLE}_mlst.tsv"

    echo "------------------------------------------------------------"
    echo "Processing sample ${CURRENT}/${NSAMPLES}: ${SAMPLE}"
    echo "------------------------------------------------------------"

    mlst \
        --scheme "${MLST_SCHEME}" \
        --threads "${SLURM_CPUS_PER_TASK}" \
        --nopath \
        "${FASTA}" \
        > "${OUT_TSV}"

    if [[ ! -s "${OUT_TSV}" ]]; then
        echo "ERROR: No MLST result generated for ${SAMPLE}." >&2
        exit 1
    fi

    echo "Result:"
    cat "${OUT_TSV}"

    echo
    echo "Completed: ${SAMPLE}"
    echo

done < list.txt


# ============================================================
# H. VERIFY INDIVIDUAL MLST RESULTS
# ============================================================

echo "============================================================"
echo " G. Checking MLST results"
echo "============================================================"
echo

MLST_COUNT=0

while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue

    RESULT="${MLST_DIR}/${SAMPLE}_mlst.tsv"

    if [[ -s "${RESULT}" ]]; then
        MLST_COUNT=$((MLST_COUNT + 1))
    fi

done < list.txt

echo "MLST result files: ${MLST_COUNT}/${NSAMPLES}"

if [[ "${MLST_COUNT}" -ne "${NSAMPLES}" ]]; then
    echo
    echo "ERROR: Expected ${NSAMPLES} MLST results" >&2
    echo "but found ${MLST_COUNT}." >&2
    exit 1
fi


# ============================================================
# I. CREATE COMBINED MLST SUMMARY
# ============================================================

echo
echo "============================================================"
echo " H. Creating combined MLST summary"
echo "============================================================"
echo

printf "Sample\tScheme\tST\tAllele1\tAllele2\tAllele3\tAllele4\tAllele5\tAllele6\tAllele7\n" \
    > "${SUMMARY_FILE}"

while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue

    RESULT="${MLST_DIR}/${SAMPLE}_mlst.tsv"

    awk -v sample="${SAMPLE}" '
        BEGIN {
            FS=OFS="\t"
        }

        {
            $1=sample
            print
        }
    ' "${RESULT}" >> "${SUMMARY_FILE}"

done < list.txt


# ============================================================
# J. CHECK COMBINED SUMMARY
# ============================================================

NRESULTS=$(awk '
    NR > 1 {
        count++
    }

    END {
        print count+0
    }
' "${SUMMARY_FILE}")

echo "Samples in combined summary: ${NRESULTS}"

if [[ "${NRESULTS}" -ne "${NSAMPLES}" ]]; then
    echo
    echo "ERROR: Expected ${NSAMPLES} samples in summary" >&2
    echo "but found ${NRESULTS}." >&2
    exit 1
fi


# ============================================================
# K. DISPLAY COMBINED MLST RESULTS
# ============================================================

echo
echo "============================================================"
echo " MLST RESULTS"
echo "============================================================"
echo

if command -v column >/dev/null 2>&1; then
    column -t -s $'\t' "${SUMMARY_FILE}"
else
    cat "${SUMMARY_FILE}"
fi


# ============================================================
# L. GENERATE SEQUENCE-TYPE COUNTS
# ============================================================

echo
echo "============================================================"
echo " I. Calculating sequence-type frequencies"
echo "============================================================"
echo

printf "ST\tCount\n" > "${ST_COUNTS}"

awk -F '\t' '
    NR > 1 {
        count[$3]++
    }

    END {
        for (st in count) {
            print st "\t" count[st]
        }
    }
' "${SUMMARY_FILE}" \
    | sort -k2,2nr \
    >> "${ST_COUNTS}"

echo "Sequence type counts:"
echo

if command -v column >/dev/null 2>&1; then
    column -t -s $'\t' "${ST_COUNTS}"
else
    cat "${ST_COUNTS}"
fi


# ============================================================
# M. CHECK UNRESOLVED SEQUENCE TYPES
# ============================================================

echo
echo "============================================================"
echo " J. Checking unresolved sequence types"
echo "============================================================"
echo

printf "Sample\tScheme\tST\tAlleles\n" > "${UNRESOLVED_FILE}"

awk -F '\t' '
    NR > 1 && $3 == "-" {

        alleles=""

        for (i=4; i<=NF; i++) {

            if (i > 4) {
                alleles = alleles ";"
            }

            alleles = alleles $i
        }

        print $1 "\t" $2 "\t" $3 "\t" alleles
    }
' "${SUMMARY_FILE}" \
    >> "${UNRESOLVED_FILE}"


UNRESOLVED=$(awk -F '\t' '
    NR > 1 && $3 == "-" {
        count++
    }

    END {
        print count+0
    }
' "${SUMMARY_FILE}")


echo "Unresolved sequence types:"
echo "  ${UNRESOLVED}/${NSAMPLES}"


if [[ "${UNRESOLVED}" -gt 0 ]]; then

    echo
    echo "Samples with unresolved STs:"
    echo

    awk -F '\t' '
        NR > 1 && $3 == "-" {
            print "  " $1
        }
    ' "${SUMMARY_FILE}"

    echo
    echo "Detailed unresolved results:"
    echo "  ${UNRESOLVED_FILE}"

fi


# ============================================================
# N. CHECK UNCERTAIN OR INCOMPLETE ALLELE CALLS
# ============================================================

echo
echo "============================================================"
echo " K. Checking uncertain allele calls"
echo "============================================================"
echo

printf "Sample\tScheme\tST\tAlleles\n" > "${UNCERTAIN_FILE}"

awk -F '\t' '
    NR > 1 {

        uncertain=0

        for (i=4; i<=NF; i++) {

            if (
                $i ~ /\?/ ||
                $i ~ /~/  ||
                $i ~ /\(-\)/
            ) {
                uncertain=1
            }
        }

        if (uncertain == 1) {

            alleles=""

            for (i=4; i<=NF; i++) {

                if (i > 4) {
                    alleles = alleles ";"
                }

                alleles = alleles $i
            }

            print $1 "\t" $2 "\t" $3 "\t" alleles
        }
    }
' "${SUMMARY_FILE}" \
    >> "${UNCERTAIN_FILE}"


UNCERTAIN_COUNT=$(awk -F '\t' '
    NR > 1 {

        uncertain=0

        for (i=4; i<=NF; i++) {

            if (
                $i ~ /\?/ ||
                $i ~ /~/  ||
                $i ~ /\(-\)/
            ) {
                uncertain=1
            }
        }

        if (uncertain == 1) {
            count++
        }
    }

    END {
        print count+0
    }
' "${SUMMARY_FILE}")


echo "Samples with uncertain/incomplete allele calls:"
echo "  ${UNCERTAIN_COUNT}/${NSAMPLES}"

if [[ "${UNCERTAIN_COUNT}" -gt 0 ]]; then
    echo
    echo "Detailed uncertain allele results:"
    echo "  ${UNCERTAIN_FILE}"
fi


# ============================================================
# O. COUNT UNIQUE RESOLVED SEQUENCE TYPES
# ============================================================

echo
echo "============================================================"
echo " L. Counting resolved sequence types"
echo "============================================================"
echo

UNIQUE_ST=$(awk -F '\t' '
    NR > 1 &&
    $3 != "-" &&
    $3 != "" {

        seen[$3]=1
    }

    END {

        for (st in seen) {
            count++
        }

        print count+0
    }
' "${SUMMARY_FILE}")


echo "Unique resolved sequence types:"
echo "  ${UNIQUE_ST}"
echo


# ============================================================
# P. FINAL SUMMARY
# ============================================================

echo "============================================================"
echo " MLST PROFILING COMPLETED SUCCESSFULLY"
echo "============================================================"
echo

echo "Samples analysed:"
echo "  ${NSAMPLES}"
echo

echo "MLST result files:"
echo "  ${MLST_COUNT}/${NSAMPLES}"
echo

echo "MLST scheme:"
echo "  ${MLST_SCHEME}"
echo

echo "Unique resolved STs:"
echo "  ${UNIQUE_ST}"
echo

echo "Unresolved ST calls:"
echo "  ${UNRESOLVED}/${NSAMPLES}"
echo

echo "Samples with uncertain/incomplete allele calls:"
echo "  ${UNCERTAIN_COUNT}/${NSAMPLES}"
echo

echo "Individual results:"
echo "  ${MLST_DIR}/<SAMPLE>_mlst.tsv"
echo

echo "Combined MLST table:"
echo "  ${SUMMARY_FILE}"
echo

echo "Sequence type counts:"
echo "  ${ST_COUNTS}"
echo

echo "Unresolved ST table:"
echo "  ${UNRESOLVED_FILE}"
echo

echo "Uncertain allele table:"
echo "  ${UNCERTAIN_FILE}"
echo

echo "Ready for:"
echo "  Step 09 - AMR, Plasmid and Virulence Profiling"
echo

echo "============================================================"

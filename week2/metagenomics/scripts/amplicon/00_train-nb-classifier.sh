#!/bin/bash

#SBATCH --job-name=TrainSILVA
#SBATCH --output=logs/train-silva_%j.out
#SBATCH --error=logs/train-silva_%j.err
#SBATCH --time=08:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G

# ============================================================
# QIIME 2 container
# ============================================================

QIIME_CONTAINER="/etc/ace-data/rgc/containers/qiime2/qiime2-2026.7.sif"

qiime() {
    /usr/bin/apptainer exec \
        "${QIIME_CONTAINER}" \
        qiime "$@"
}

# ============================================================
# Writable cache directories
# ============================================================

export MPLCONFIGDIR="/tmp/${USER}-matplotlib"
mkdir -p "${MPLCONFIGDIR}"

export NUMBA_CACHE_DIR="/tmp/${USER}-numba"
mkdir -p "${NUMBA_CACHE_DIR}"

# ============================================================
# Variables
# ============================================================

DB_DIR="${SHARED_DIR}/databases"

SEQS="${DB_DIR}/silva-138-99-seqs.qza"
TAX="${DB_DIR}/silva-138-99-tax.qza"

EXTRACTED="${DB_DIR}/silva-138-99-extracted.qza"

CLASSIFIER="${DB_DIR}/silva-138-99-nb-classifier-2026.7.qza"

THREADS="${SLURM_CPUS_PER_TASK}"

# ============================================================
# Primers V1-V3 (using 27F and 518R primers) - https://kb.ezbiocloud.net/home/science-blogs/identify/16s-rrna
# ============================================================

F_PRIMER="AGAGTTTGATCMTGGCTCAG"
R_PRIMER="GTATTACCGCGGCTGCTGG"

# ============================================================
# Extract target region
# ============================================================

qiime feature-classifier extract-reads \
    --i-sequences "${SEQS}" \
    --p-f-primer "${F_PRIMER}" \
    --p-r-primer "${R_PRIMER}" \
    --p-n-jobs "${THREADS}" \
    --o-reads "${EXTRACTED}" \
    --o-read-extraction-stats "extraction-stats.qza"

# ============================================================
# Train Naive Bayes classifier
# ============================================================

qiime feature-classifier fit-classifier-naive-bayes \
    --i-reference-reads "${EXTRACTED}" \
    --i-reference-taxonomy "${TAX}" \
    --o-classifier "${CLASSIFIER}"

#!/bin/bash

#SBATCH --job-name=QiimeTaxonomy
#SBATCH --output=logs/taxonomy_%j.out
#SBATCH --error=logs/taxonomy_%j.err
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G

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
# Environment
# ============================================================

export MPLCONFIGDIR="/tmp/${USER}-matplotlib"
mkdir -p "${MPLCONFIGDIR}"

export NUMBA_CACHE_DIR="/tmp/${USER}-numba"
mkdir -p "${NUMBA_CACHE_DIR}"

# ============================================================
# Variables
# ============================================================

DADA2_DIR="$HOME/metagenomics/amplicon/results/qiime2/dada2-run2"

TAXA_DIR="$HOME/metagenomics/amplicon/results/qiime2/taxonomy"

CLASSIFIER="$HOME/metagenomics/amplicon/silva-138-99-nb-classifier-2026.7.qza"

THREADS="${SLURM_CPUS_PER_TASK}"

# ============================================================
# Taxonomic classification
# ============================================================

mkdir -p "${TAXA_DIR}"

qiime feature-classifier classify-sklearn \
    --i-classifier "${CLASSIFIER}" \
    --i-reads "${DADA2_DIR}/rep-seqs.qza" \
    --p-n-jobs "${THREADS}" \
    --o-classification "${TAXA_DIR}/taxonomy.qza" \
    --verbose

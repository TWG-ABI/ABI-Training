#!/bin/bash

#SBATCH --job-name=Taxaplot
#SBATCH --output=logs/taxaplot_%j.out
#SBATCH --error=logs/taxaplot_%j.err
#SBATCH --time=02:00:00
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

TAX_DIR="$HOME/metagenomics/amplicon/results/qiime2/taxonomy"
ASV_DIR="$HOME/metagenomics/amplicon/results/qiime2/dada2-run2"
METADATA="$HOME/metagenomics/amplicon/metadata.tsv"

# ============================================================
# Taxonomic classification
# ============================================================

qiime taxa barplot \
    --i-table "${ASV_DIR}/table.qza" \
    --i-taxonomy "${TAX_DIR}/taxonomy.qza" \
    --m-metadata-file "${METADATA}" \
    --o-visualization "${TAX_DIR}/taxa-bar-plots.qzv"

#!/bin/bash

#SBATCH --job-name=Dada2Stats
#SBATCH --output=logs/stats_%j.out
#SBATCH --error=logs/stats_%j.err
#SBATCH --time=01:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G

# ============================================================
# QIIME 2 container configuration
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

export MPLCONFIGDIR="/tmp/${USER}/matplotlib"
mkdir -p "${MPLCONFIGDIR}"

export NUMBA_CACHE_DIR="/tmp/${USER}-numba"
mkdir -p "${NUMBA_CACHE_DIR}"

# ============================================================
# Variables
# ============================================================

DADA2_DIR="$HOME/metagenomics/amplicon/results/qiime2/dada2"

# ============================================================
# 1. Tabulate DADA2 denoising statistics
# ============================================================

qiime metadata tabulate \
    --m-input-file "${DADA2_DIR}/dada2-stats.qza" \
    --o-visualization "${DADA2_DIR}/dada2-stats.qzv"


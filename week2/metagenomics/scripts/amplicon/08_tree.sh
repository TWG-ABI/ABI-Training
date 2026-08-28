#!/bin/bash

#SBATCH --job-name=QiimeTree
#SBATCH --output=logs/tree_%j.out
#SBATCH --error=logs/tree_%j.err
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

export MPLCONFIGDIR="/tmp/${USER}/matplotlib"
mkdir -p "${MPLCONFIGDIR}"

export NUMBA_CACHE_DIR="/tmp/${USER}-numba"
mkdir -p "${NUMBA_CACHE_DIR}"

# ============================================================
# Variables
# ============================================================

IN_DIR="$HOME/metagenomics/amplicon/results/qiime2/dada2"
OUT_DIR="$HOME/metagenomics/amplicon/results/qiime2/phylogeny"
THREADS="${SLURM_CPUS_PER_TASK}"

# ============================================================
# Multiple sequence alignment + phylogenetic tree
# ============================================================

mkdir -p "${OUT_DIR}"

qiime phylogeny align-to-tree-mafft-fasttree \
    --i-sequences "${IN_DIR}/rep-seqs.qza" \
    --o-alignment "${OUT_DIR}/aligned-rep-seqs.qza" \
    --o-masked-alignment "${OUT_DIR}/masked-aligned-rep-seqs.qza" \
    --o-tree "${OUT_DIR}/unrooted-tree.qza" \
    --o-rooted-tree "${OUT_DIR}/rooted-tree.qza" \
    --p-n-threads "${THREADS}"

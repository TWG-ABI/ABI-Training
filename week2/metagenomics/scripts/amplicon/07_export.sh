#!/bin/bash

#SBATCH --job-name=QiimeExport
#SBATCH --output=logs/export_%j.out
#SBATCH --error=logs/export_%j.err
#SBATCH --time=01:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G

# ============================================================
# QIIME 2 container
# ============================================================

QIIME_CONTAINER="/etc/ace-data/rgc/containers/qiime2/qiime2-2026.7.sif"

qiime() {
    /usr/bin/apptainer exec \
        "${QIIME_CONTAINER}" \
        qiime "$@"
}

module load biom-format


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

ASV_DIR="$HOME/metagenomics/amplicon/results/qiime2/dada2-run2"
TAX_DIR="$HOME/metagenomics/amplicon/results/qiime2/taxonomy"
#TREE_DIR="r$HOME/metagenomics/amplicon/esults/qiime2/phylogeny"
OUT_DIR="$HOME/metagenomics/amplicon/results/qiime2/exported"

# ============================================================
# Export directory
# ============================================================

mkdir -p "${OUT_DIR}"

# ============================================================
# Export feature table
# ============================================================

qiime tools export \
    --input-path "${ASV_DIR}/table.qza" \
    --output-path "${OUT_DIR}"

biom convert \
    -i "${OUT_DIR}/feature-table.biom" \
    -o "${OUT_DIR}/feature-table.tsv" \
    --to-tsv

# ============================================================
# Export taxonomy
# ============================================================

qiime tools export \
    --input-path "${TAX_DIR}/taxonomy.qza" \
    --output-path "${OUT_DIR}"

# ============================================================
# Export rooted phylogenetic tree
# ============================================================

# qiime tools export \
#    --input-path "${TREE_DIR}/rooted-tree.qza" \
#    --output-path "${OUT_DIR}"

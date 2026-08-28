#!/bin/bash

#SBATCH --job-name=QiimeDADA2
#SBATCH --output=logs/dada2_%j.out
#SBATCH --error=logs/dada2_%j.err
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G

# ============================================================
# Load Apptainer environment
# ============================================================

module load qiime2

# ============================================================
# QIIME 2 container workaround
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

OUT_DIR="$HOME/metagenomics/amplicon/results/qiime2/dada2-run2"
THREADS="${SLURM_CPUS_PER_TASK}"

# ============================================================
# Check input exists
# ============================================================

INPUT="$HOME/metagenomics/amplicon/results/qiime2/paired-end-demux.qza"

if [ ! -f "${INPUT}" ]; then
    echo "ERROR: Input file not found: ${INPUT}"
    exit 1
fi

# ============================================================
# Run DADA2 denoising
# ============================================================

mkdir -p "${OUT_DIR}"

qiime dada2 denoise-paired \
    --i-demultiplexed-seqs "${INPUT}" \
    --p-trim-left-f 0 \
    --p-trim-left-r 0 \
    --p-trunc-len-f 280 \ 
    --p-trunc-len-r 250 \
    --p-n-threads "${THREADS}" \
    --o-table "${OUT_DIR}/table.qza" \
    --o-representative-sequences "${OUT_DIR}/rep-seqs.qza" \
    --o-denoising-stats "${OUT_DIR}/dada2-stats.qza" \
    --o-base-transition-stats "${OUT_DIR}/base-transition-stats.qza" \
    --verbose

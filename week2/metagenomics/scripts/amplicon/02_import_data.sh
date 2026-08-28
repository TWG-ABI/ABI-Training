#!/bin/bash

#SBATCH --job-name=QiimeImport
#SBATCH --output=logs/import_%j.out
#SBATCH --error=logs/import_%j.err
#SBATCH --time=03:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --mem=8G

# ============================================================
# Load QIIME 2 module
# ============================================================

module load qiime2

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
# Directories
# ============================================================

# ${SHARED_DIR} is a path where we have all shared materials - replace accordingly

DATA_DIR="${SHARED_DIR}/metagenomics/amplicon/sampled"
OUT_DIR="$HOME/metagenomics/amplicon/results/qiime2"
MANIFEST="$HOME/metagenomics/amplicon/manifest.tsv"

mkdir -p "${OUT_DIR}"

# ============================================================
# Create manifest
# ============================================================

if [ ! -f "${MANIFEST}" ]; then

    echo -e "sample-id\tforward-absolute-filepath\treverse-absolute-filepath" > "${MANIFEST}"

    for R1 in "${DATA_DIR}"/*_1.fastq.gz; do

        # Skip if no files match
        [ -e "${R1}" ] || continue

        SAMPLE=$(basename "${R1}" _1.fastq.gz)

        R2="${DATA_DIR}/${SAMPLE}_2.fastq.gz"

        if [ -f "${R2}" ]; then

            echo -e "${SAMPLE}\t$(realpath "${R1}")\t$(realpath "${R2}")" \
                >> "${MANIFEST}"

        else

            echo "WARNING: Reverse read not found for ${SAMPLE}"

        fi

    done

fi

# ============================================================
# Import paired-end reads into QIIME 2
# ============================================================

qiime tools import \
    --type 'SampleData[PairedEndSequencesWithQuality]' \
    --input-path "${MANIFEST}" \
    --output-path "${OUT_DIR}/paired-end-demux.qza" \
    --input-format PairedEndFastqManifestPhred33V2

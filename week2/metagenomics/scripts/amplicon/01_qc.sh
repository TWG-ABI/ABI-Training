#!/bin/bash

#SBATCH --job-name=QC
#SBATCH --output=logs/qc_%j.out
#SBATCH --error=logs/qc_%j.err
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --mem=8G

# -----------------------------
# Load required software
# -----------------------------

# Load FastQC for quality assessment of FASTQ files
module load fastqc

# Load MultiQC for combining QC reports from multiple samples
module load multiqc

# -----------------------------
# Define input and output paths
# -----------------------------

# Directory containing the input compressed FASTQ files
DATA_DIR="${SHARED_DIR}/metagenomics/amplicon/sampled"

# Directory where QC results will be stored
OUT_DIR="$HOME/metagenomics/amplicon/results/qc"

# -----------------------------
# Create output directory
# -----------------------------

# Create the output directory if it does not already exist
# -p also creates any missing parent directories
mkdir -p "${OUT_DIR}"

# -----------------------------
# Run FastQC
# -----------------------------

# Run FastQC on all compressed FASTQ files (.gz) in the data directory
fastqc "${DATA_DIR}"/*.gz -o "${OUT_DIR}"

# -----------------------------
# Run MultiQC
# -----------------------------

# Scan the FastQC output directory and combine all QC reports
# into a single MultiQC report
#
# The final MultiQC report will also be placed in OUT_DIR
multiqc "${OUT_DIR}"/* -o "${OUT_DIR}"

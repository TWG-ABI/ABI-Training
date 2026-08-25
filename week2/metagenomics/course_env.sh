#!/bin/bash
# /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
# Usage (interactive OR inside every #SBATCH job script after the headers):
#   source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
#
# No #SBATCH lines in this file. Shared DBs are read-only — do not download
# personal copies. Write outputs under $COURSE_WORK_DIR / $HOME.
# =============================================================================

# Shared databases
export COURSE_DBS="/etc/ace-data/ABI-SummerSchool-26/metagenomics/databases"
export EGGNOG_DATA_DIR="${COURSE_DBS}/eggnog"
export CHECKM2DB="${COURSE_DBS}/checkm2/CheckM2_database/uniref100.KO.1.dmnd"
export GTDBTK_DATA_PATH="${COURSE_DBS}/gtdbtk/release226"
export HUMANN_DB_PATH="${COURSE_DBS}/humann3"
export AMRFINDER_DB="${COURSE_DBS}/amrfinder/latest"
export METAPHLAN_DB="${COURSE_DBS}/metaphlanDB"
export KRAKEN_DB="${COURSE_DBS}/krakenDB"
export IMAGES_DIR="${COURSE_DBS}/images"

# Host genome Bowtie2 index (on ACE this sits next to databases/, spelling GRCH38)
export HOST_IDX="/etc/ace-data/ABI-SummerSchool-26/metagenomics/GRCH38_index/GRCh38_noalt_as"

# Shared shotgun FASTQs
export SHOTGUN_DIR="/etc/ace-data/ABI-SummerSchool-26/metagenomics/data/shotgun"
export GUT_DIR="${SHOTGUN_DIR}/gut_sample"
export GUT_MINIPROJECT_DIR="${SHOTGUN_DIR}/gut_miniproject"
export SOIL_MINIPROJECT_DIR="${SHOTGUN_DIR}/soil_miniproject"

# Personal writable area for job outputs
export COURSE_WORK_DIR="${COURSE_WORK_DIR:-/etc/ace-data/home/${USER}}"
mkdir -p "${COURSE_WORK_DIR}" 2>/dev/null || true

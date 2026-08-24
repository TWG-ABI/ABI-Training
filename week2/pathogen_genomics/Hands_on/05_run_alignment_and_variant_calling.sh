#!/bin/bash
#SBATCH --job-name=variant_calling
#SBATCH --output=reports/varcall_%j.out
#SBATCH --error=reports/varcall_%j.err
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=12:00:00

set -euo pipefail

# ============================================================
# 05_run_alignment_and_variant_calling.sh
# Bacterial Genomics Practical Training
#
# Purpose:
#   1. Align trimmed paired-end reads to an E. coli reference
#      genome using BWA-MEM
#   2. Sort and index BAM files using SAMtools
#   3. Call haploid variants using BCFtools
#   4. Filter variants using QUAL and depth
#   5. Build a custom SnpEff database
#   6. Annotate filtered variants using SnpEff
#
# Input:
#   clean_data/SAMPLE_R1_paired.fastq.gz
#   clean_data/SAMPLE_R2_paired.fastq.gz
#   Reference/Ecoli_Ref.fasta
#   Reference/Ecoli_Ref.gff3
#   list.txt
#
# Output:
#   snps/alignment/
#   snps/variant_calling/
#   snps/annotation/
#   snps/snpeff_db/
#
# Expected dataset:
#   40 E. coli isolates
#
# IMPORTANT HPC NOTE:
#   BWA, SAMtools, BCFtools and SnpEff are run directly
#   through Singularity because their cluster modulefiles
#   currently contain broken function-export definitions.
# ============================================================


# ------------------------------------------------------------
# 1. Move to directory from which job was submitted
# ------------------------------------------------------------

cd "${SLURM_SUBMIT_DIR:-$PWD}"

echo "============================================================"
echo " BACTERIAL GENOMICS TRAINING"
echo " ALIGNMENT, VARIANT CALLING AND ANNOTATION"
echo "============================================================"
echo
echo "Working directory : $(pwd)"
echo "Node              : $(hostname)"
echo "SLURM Job ID      : ${SLURM_JOB_ID}"
echo "CPUs allocated    : ${SLURM_CPUS_PER_TASK}"
echo


# ============================================================
# 2. CONFIGURE SOFTWARE CONTAINERS
# ============================================================

echo "=== Step 1: Configuring software containers ==="


# ------------------------------------------------------------
# Check Singularity
# ------------------------------------------------------------

if ! command -v singularity >/dev/null 2>&1; then

    echo "ERROR: Singularity is not available." >&2
    exit 1

fi

echo "Singularity:"
command -v singularity

echo


# ------------------------------------------------------------
# Define container paths
# ------------------------------------------------------------

BWA_SIF="/etc/ace-data/rgc/containers/bwa/bwa-0.7.19--h577a1d6_1.sif"

SAMTOOLS_SIF="/etc/ace-data/rgc/containers/samtools/samtools-1.23.1--ha83d96e_0.sif"

BCFTOOLS_SIF="/etc/ace-data/rgc/containers/bcftools/bcftools-1.24--h118bc1c_2.sif"

SNPEFF_SIF="/etc/ace-data/rgc/containers/snpeff/snpeff-5.4.sif"


# ------------------------------------------------------------
# Check that all containers exist
# ------------------------------------------------------------

for CONTAINER in \
    "${BWA_SIF}" \
    "${SAMTOOLS_SIF}" \
    "${BCFTOOLS_SIF}" \
    "${SNPEFF_SIF}"
do

    if [[ ! -s "${CONTAINER}" ]]; then

        echo "ERROR: Container not found:" >&2
        echo "       ${CONTAINER}" >&2
        exit 1

    fi

done


echo "All required Singularity containers found."


# ------------------------------------------------------------
# Define local command wrappers
#
# DO NOT export these functions.
# ------------------------------------------------------------

bwa() {

    singularity exec \
        "${BWA_SIF}" \
        bwa "$@"

}


samtools() {

    singularity exec \
        "${SAMTOOLS_SIF}" \
        samtools "$@"

}


bcftools() {

    singularity exec \
        "${BCFTOOLS_SIF}" \
        bcftools "$@"

}


bgzip() {

    singularity exec \
        "${BCFTOOLS_SIF}" \
        bgzip "$@"

}


snpEff() {

    singularity exec \
        "${SNPEFF_SIF}" \
        snpEff "$@"

}


# ------------------------------------------------------------
# Display software versions
# ------------------------------------------------------------

echo
echo "Software versions:"
echo


echo "BWA:"
bwa 2>&1 | grep -m1 '^Version:' || true

echo


echo "SAMtools:"
samtools --version | head -n1

echo


echo "BCFtools:"
bcftools --version | head -n1

echo


echo "SnpEff:"
snpEff -version 2>&1 | head -n1 || true

echo


echo "Software containers configured successfully."
echo


# ============================================================
# 3. DEFINE INPUT AND OUTPUT PATHS
# ============================================================

READS_DIR="clean_data"

REF_DIR="Reference"

REF_FASTA="${REF_DIR}/Ecoli_Ref.fasta"

REF_GFF="${REF_DIR}/Ecoli_Ref.gff3"


ALIGN_DIR="snps/alignment"

VC_DIR="snps/variant_calling"

ANNOT_DIR="snps/annotation"


# ------------------------------------------------------------
# SnpEff database paths
#
# IMPORTANT:
# Use ABSOLUTE paths to prevent SnpEff from duplicating
# snps/snpeff_db in its database path.
# ------------------------------------------------------------

SNPEFF_DIR="$(pwd)/snps/snpeff_db"

SNPEFF_DATA="${SNPEFF_DIR}/data"

SNPEFF_GENOME="Ecoli_Ref"

SNPEFF_GENOME_DIR="${SNPEFF_DATA}/${SNPEFF_GENOME}"

SNPEFF_CONFIG="${SNPEFF_DIR}/snpEff.config"


# ------------------------------------------------------------
# Create output directories
# ------------------------------------------------------------

mkdir -p \
    "${ALIGN_DIR}" \
    "${VC_DIR}" \
    "${ANNOT_DIR}" \
    reports


# ============================================================
# 4. CHECK REQUIRED INPUTS
# ============================================================

echo "============================================================"
echo " Step 2: Checking required inputs"
echo "============================================================"
echo


# ------------------------------------------------------------
# Check list.txt
# ------------------------------------------------------------

if [[ ! -s "list.txt" ]]; then

    echo "ERROR: list.txt not found or empty." >&2
    echo "Run 01_setup_environment.sh first." >&2
    exit 1

fi


NSAMPLES=$(grep -cve '^[[:space:]]*$' list.txt)

echo "Samples detected: ${NSAMPLES}"


if [[ "${NSAMPLES}" -ne 40 ]]; then

    echo "WARNING: Expected 40 samples but found ${NSAMPLES}." >&2

fi


# ------------------------------------------------------------
# Check reference FASTA
# ------------------------------------------------------------

if [[ ! -s "${REF_FASTA}" ]]; then

    echo "ERROR: Reference FASTA not found or empty:" >&2
    echo "       ${REF_FASTA}" >&2
    exit 1

fi


# ------------------------------------------------------------
# Check reference GFF
# ------------------------------------------------------------

if [[ ! -s "${REF_GFF}" ]]; then

    echo "ERROR: Reference GFF3 not found or empty:" >&2
    echo "       ${REF_GFF}" >&2
    exit 1

fi


echo "Reference FASTA:"
echo "  ${REF_FASTA}"

echo
echo "Reference GFF3:"
echo "  ${REF_GFF}"


# ============================================================
# 5. CHECK TRIMMED READS
# ============================================================

echo
echo "============================================================"
echo " Step 3: Checking trimmed reads"
echo "============================================================"
echo


MISSING=0


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue


    R1="${READS_DIR}/${SAMPLE}_R1_paired.fastq.gz"

    R2="${READS_DIR}/${SAMPLE}_R2_paired.fastq.gz"


    if [[ ! -s "${R1}" ]]; then

        echo "ERROR: Missing R1 for ${SAMPLE}" >&2
        echo "       ${R1}" >&2

        MISSING=$((MISSING + 1))

    fi


    if [[ ! -s "${R2}" ]]; then

        echo "ERROR: Missing R2 for ${SAMPLE}" >&2
        echo "       ${R2}" >&2

        MISSING=$((MISSING + 1))

    fi


done < list.txt


if [[ "${MISSING}" -gt 0 ]]; then

    echo
    echo "ERROR: ${MISSING} trimmed read file(s) are missing." >&2
    exit 1

fi


echo "All paired trimmed reads are available."


# ============================================================
# 6. CHECK FASTA/GFF SEQUENCE-ID COMPATIBILITY
# ============================================================

echo
echo "============================================================"
echo " Step 4: Checking reference annotation compatibility"
echo "============================================================"
echo


FASTA_IDS=$(mktemp)

GFF_IDS=$(mktemp)


trap 'rm -f "${FASTA_IDS}" "${GFF_IDS}"' EXIT


# Extract FASTA sequence IDs

grep '^>' "${REF_FASTA}" \
    | sed 's/^>//' \
    | cut -d' ' -f1 \
    | sort -u \
    > "${FASTA_IDS}"


# Extract sequence IDs from GFF feature lines

awk '
    !/^#/ && NF >= 9 {
        print $1
    }
' "${REF_GFF}" \
    | sort -u \
    > "${GFF_IDS}"


echo "Reference FASTA sequence IDs:"
cat "${FASTA_IDS}"

echo
echo "Reference GFF3 sequence IDs:"
cat "${GFF_IDS}"

echo


# ------------------------------------------------------------
# Check whether GFF sequence IDs exist in FASTA
# ------------------------------------------------------------

UNMATCHED=$(comm -13 "${FASTA_IDS}" "${GFF_IDS}" || true)


if [[ -n "${UNMATCHED}" ]]; then

    echo "ERROR: Some GFF3 sequence IDs are absent from the FASTA:" >&2
    echo "${UNMATCHED}" >&2
    echo
    echo "The FASTA and GFF3 must describe the same reference genome." >&2

    exit 1

fi


echo "Reference FASTA and GFF3 sequence IDs are compatible."


# ============================================================
# 7. INDEX REFERENCE GENOME
# ============================================================

echo
echo "============================================================"
echo " Step 5: Indexing reference genome"
echo "============================================================"
echo


# ------------------------------------------------------------
# BWA index
#
# Rebuild only if important index files are absent.
# ------------------------------------------------------------

if [[ ! -s "${REF_FASTA}.bwt" ]] ||
   [[ ! -s "${REF_FASTA}.sa" ]]; then

    echo "Building BWA index..."

    bwa index "${REF_FASTA}"

else

    echo "Existing BWA index detected."

fi


# ------------------------------------------------------------
# SAMtools FASTA index
# ------------------------------------------------------------

if [[ ! -s "${REF_FASTA}.fai" ]]; then

    echo "Building SAMtools FASTA index..."

    samtools faidx "${REF_FASTA}"

else

    echo "Existing SAMtools FASTA index detected."

fi


echo
echo "Reference indexing completed."


# ============================================================
# 8. BUILD CUSTOM SNPEFF DATABASE
# ============================================================

echo
echo "============================================================"
echo " Step 6: Building custom SnpEff database"
echo "============================================================"
echo


# ------------------------------------------------------------
# Remove old custom database
#
# This prevents stale config files or incorrect paths from
# previous failed runs.
# ------------------------------------------------------------

rm -rf "${SNPEFF_DIR}"


mkdir -p "${SNPEFF_GENOME_DIR}"


# ------------------------------------------------------------
# Copy reference files using SnpEff expected filenames
# ------------------------------------------------------------

cp "${REF_FASTA}" \
   "${SNPEFF_GENOME_DIR}/sequences.fa"


cp "${REF_GFF}" \
   "${SNPEFF_GENOME_DIR}/genes.gff"


# ------------------------------------------------------------
# Create custom SnpEff configuration
#
# IMPORTANT:
# data.dir is an absolute path.
# ------------------------------------------------------------

cat > "${SNPEFF_CONFIG}" <<EOF
data.dir = ${SNPEFF_DATA}
${SNPEFF_GENOME}.genome : Ecoli_Custom_Reference
EOF


echo "SnpEff configuration:"
echo

cat "${SNPEFF_CONFIG}"

echo


echo "SnpEff genome directory:"
echo "  ${SNPEFF_GENOME_DIR}"

echo


# ------------------------------------------------------------
# Check database inputs
# ------------------------------------------------------------

if [[ ! -s "${SNPEFF_GENOME_DIR}/sequences.fa" ]]; then

    echo "ERROR: sequences.fa missing from SnpEff database." >&2
    exit 1

fi


if [[ ! -s "${SNPEFF_GENOME_DIR}/genes.gff" ]]; then

    echo "ERROR: genes.gff missing from SnpEff database." >&2
    exit 1

fi


echo "SnpEff database input files are present."


# ------------------------------------------------------------
# Build SnpEff database
# ------------------------------------------------------------

echo
echo "Building custom SnpEff database..."
echo


snpEff build \
    -c "${SNPEFF_CONFIG}" \
    -gff3 \
    -noCheckCds \
    -noCheckProtein \
    -v \
    "${SNPEFF_GENOME}"

# ------------------------------------------------------------
# Check database build result
# ------------------------------------------------------------

SNPEFF_DB_FILE="${SNPEFF_GENOME_DIR}/snpEffectPredictor.bin"


if [[ ! -s "${SNPEFF_DB_FILE}" ]]; then

    echo
    echo "ERROR: SnpEff database build did not produce:" >&2
    echo "       ${SNPEFF_DB_FILE}" >&2

    exit 1

fi


echo
echo "SnpEff database built successfully."
echo "Database:"
echo "  ${SNPEFF_DB_FILE}"


# ============================================================
# 9. ALIGNMENT AND VARIANT CALLING
# ============================================================

echo
echo "============================================================"
echo " Step 7: Alignment and variant calling"
echo "============================================================"
echo


CURRENT=0


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue


    CURRENT=$((CURRENT + 1))


    echo
    echo "------------------------------------------------------------"
    echo "Processing sample ${CURRENT}/${NSAMPLES}: ${SAMPLE}"
    echo "------------------------------------------------------------"
    echo


    # --------------------------------------------------------
    # Input reads
    # --------------------------------------------------------

    R1="${READS_DIR}/${SAMPLE}_R1_paired.fastq.gz"

    R2="${READS_DIR}/${SAMPLE}_R2_paired.fastq.gz"


    # --------------------------------------------------------
    # Alignment outputs
    # --------------------------------------------------------

    BAM_SORTED="${ALIGN_DIR}/${SAMPLE}_sorted.bam"

    FLAGSTAT="${ALIGN_DIR}/${SAMPLE}_flagstat.txt"

    COVERAGE="${ALIGN_DIR}/${SAMPLE}_coverage.txt"


    # --------------------------------------------------------
    # Variant outputs
    # --------------------------------------------------------

    RAW_VCF="${VC_DIR}/${SAMPLE}_raw.vcf.gz"

    FILT_VCF="${VC_DIR}/${SAMPLE}_filtered.vcf.gz"

    VCF_STATS="${VC_DIR}/${SAMPLE}_filtered_vcf_stats.txt"


    # --------------------------------------------------------
    # Annotated VCF
    # --------------------------------------------------------

    ANNOT_VCF="${ANNOT_DIR}/${SAMPLE}_annotated.vcf.gz"


    # ========================================================
    # 9A. BWA-MEM alignment and BAM sorting
    # ========================================================

    echo "[1/5] Aligning reads with BWA-MEM..."


    bwa mem \
        -t "${SLURM_CPUS_PER_TASK}" \
        -R "@RG\tID:${SAMPLE}\tSM:${SAMPLE}\tPL:ILLUMINA" \
        "${REF_FASTA}" \
        "${R1}" \
        "${R2}" \
        | samtools sort \
            -@ "${SLURM_CPUS_PER_TASK}" \
            -o "${BAM_SORTED}" \
            -


    # Verify BAM

    if [[ ! -s "${BAM_SORTED}" ]]; then

        echo "ERROR: BAM file was not generated for ${SAMPLE}." >&2
        exit 1

    fi


    # ========================================================
    # 9B. Index BAM and calculate alignment statistics
    # ========================================================

    echo "[2/5] Indexing BAM and calculating alignment statistics..."


    samtools index \
        -@ "${SLURM_CPUS_PER_TASK}" \
        "${BAM_SORTED}"


    samtools flagstat \
        -@ "${SLURM_CPUS_PER_TASK}" \
        "${BAM_SORTED}" \
        > "${FLAGSTAT}"


    samtools coverage \
        "${BAM_SORTED}" \
        > "${COVERAGE}"


    # ========================================================
    # 9C. Call haploid variants
    # ========================================================

    echo "[3/5] Calling haploid variants with BCFtools..."


    bcftools mpileup \
        -Ou \
        -f "${REF_FASTA}" \
        "${BAM_SORTED}" \
        | bcftools call \
            --ploidy 1 \
            -m \
            -v \
            -Oz \
            -o "${RAW_VCF}"


    # Verify raw VCF

    if [[ ! -s "${RAW_VCF}" ]]; then

        echo "ERROR: Raw VCF was not generated for ${SAMPLE}." >&2
        exit 1

    fi


    bcftools index \
        --force \
        --tbi \
        "${RAW_VCF}"


    # ========================================================
    # 9D. Filter variants
    #
    # QUAL >= 30
    # INFO depth >= 10
    # ========================================================

    echo "[4/5] Filtering variants..."


    bcftools filter \
        -e 'QUAL<30 || INFO/DP<10' \
        "${RAW_VCF}" \
        -Oz \
        -o "${FILT_VCF}"


    # Verify filtered VCF

    if [[ ! -s "${FILT_VCF}" ]]; then

        echo "ERROR: Filtered VCF was not generated for ${SAMPLE}." >&2
        exit 1

    fi


    bcftools index \
        --force \
        --tbi \
        "${FILT_VCF}"


    # --------------------------------------------------------
    # Variant statistics
    # --------------------------------------------------------

    bcftools stats \
        "${FILT_VCF}" \
        > "${VCF_STATS}"


    # ========================================================
    # 9E. Annotate variants using SnpEff
    # ========================================================

    echo "[5/5] Annotating variants with SnpEff..."


    snpEff \
        -c "${SNPEFF_CONFIG}" \
        -v \
        "${SNPEFF_GENOME}" \
        "${FILT_VCF}" \
        | bgzip -c \
        > "${ANNOT_VCF}"


    # Verify annotated VCF

    if [[ ! -s "${ANNOT_VCF}" ]]; then

        echo "ERROR: Annotated VCF was not generated for ${SAMPLE}." >&2
        exit 1

    fi


    bcftools index \
        --force \
        --tbi \
        "${ANNOT_VCF}"


    echo
    echo "Completed sample: ${SAMPLE}"


done < list.txt


# ============================================================
# 10. VERIFY OUTPUTS
# ============================================================

echo
echo "============================================================"
echo " Step 8: Verifying variant-calling outputs"
echo "============================================================"
echo


BAM_COUNT=0

RAW_COUNT=0

FILTERED_COUNT=0

ANNOT_COUNT=0


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue


    [[ -s "${ALIGN_DIR}/${SAMPLE}_sorted.bam" ]] \
        && BAM_COUNT=$((BAM_COUNT + 1))


    [[ -s "${VC_DIR}/${SAMPLE}_raw.vcf.gz" ]] \
        && RAW_COUNT=$((RAW_COUNT + 1))


    [[ -s "${VC_DIR}/${SAMPLE}_filtered.vcf.gz" ]] \
        && FILTERED_COUNT=$((FILTERED_COUNT + 1))


    [[ -s "${ANNOT_DIR}/${SAMPLE}_annotated.vcf.gz" ]] \
        && ANNOT_COUNT=$((ANNOT_COUNT + 1))


done < list.txt


echo "Sorted BAM files       : ${BAM_COUNT}/${NSAMPLES}"

echo "Raw VCF files          : ${RAW_COUNT}/${NSAMPLES}"

echo "Filtered VCF files     : ${FILTERED_COUNT}/${NSAMPLES}"

echo "Annotated VCF files    : ${ANNOT_COUNT}/${NSAMPLES}"


# ------------------------------------------------------------
# Fail if any expected outputs are missing
# ------------------------------------------------------------

if [[ "${BAM_COUNT}" -ne "${NSAMPLES}" ]] ||
   [[ "${RAW_COUNT}" -ne "${NSAMPLES}" ]] ||
   [[ "${FILTERED_COUNT}" -ne "${NSAMPLES}" ]] ||
   [[ "${ANNOT_COUNT}" -ne "${NSAMPLES}" ]]; then

    echo
    echo "ERROR: One or more expected outputs are missing." >&2
    exit 1

fi


# ============================================================
# 11. CREATE SIMPLE VARIANT COUNT SUMMARY
# ============================================================

echo
echo "============================================================"
echo " Step 9: Creating variant-count summary"
echo "============================================================"
echo


VARIANT_SUMMARY="${VC_DIR}/variant_counts.tsv"


printf "Sample\tRaw_variants\tFiltered_variants\n" \
    > "${VARIANT_SUMMARY}"


while read -r SAMPLE; do

    [[ -z "${SAMPLE}" ]] && continue


    RAW_VCF="${VC_DIR}/${SAMPLE}_raw.vcf.gz"

    FILT_VCF="${VC_DIR}/${SAMPLE}_filtered.vcf.gz"


    RAW_N=$(bcftools view \
        -H \
        "${RAW_VCF}" \
        | wc -l)


    FILT_N=$(bcftools view \
        -H \
        "${FILT_VCF}" \
        | wc -l)


    printf "%s\t%s\t%s\n" \
        "${SAMPLE}" \
        "${RAW_N}" \
        "${FILT_N}" \
        >> "${VARIANT_SUMMARY}"


done < list.txt


echo "Variant-count summary:"
echo "  ${VARIANT_SUMMARY}"


# ============================================================
# 12. FINAL SUMMARY
# ============================================================

echo
echo "============================================================"
echo " ALIGNMENT, VARIANT CALLING AND ANNOTATION"
echo " COMPLETED SUCCESSFULLY"
echo "============================================================"
echo


echo "Samples analysed:"
echo "  ${NSAMPLES}"

echo


echo "Alignment outputs:"
echo "  ${ALIGN_DIR}/"

echo


echo "Variant calls:"
echo "  ${VC_DIR}/"

echo


echo "SnpEff annotated variants:"
echo "  ${ANNOT_DIR}/"

echo


echo "Custom SnpEff database:"
echo "  ${SNPEFF_DIR}/"

echo


echo "Important outputs:"
echo "  ${VC_DIR}/variant_counts.tsv"
echo "  ${VC_DIR}/SAMPLE_filtered.vcf.gz"
echo "  ${ANNOT_DIR}/SAMPLE_annotated.vcf.gz"

echo


echo "Output verification:"
echo "  BAM files       : ${BAM_COUNT}/${NSAMPLES}"
echo "  Raw VCFs        : ${RAW_COUNT}/${NSAMPLES}"
echo "  Filtered VCFs   : ${FILTERED_COUNT}/${NSAMPLES}"
echo "  Annotated VCFs  : ${ANNOT_COUNT}/${NSAMPLES}"

echo


echo "Ready for:"
echo "Step 06 - Prokka Genome Annotation"

echo "============================================================"

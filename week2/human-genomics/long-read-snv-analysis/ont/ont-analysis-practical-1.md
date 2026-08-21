## Oxford Nanopore Read Alignment, Variant Calling and Phasing


This tutorial introduces a basic workflow for analysing **Oxford Nanopore Technologies (ONT) long-read sequencing data**, focusing on:

1. aligning ONT reads to a reference genome;
2. inspecting long-read alignments;
3. calling variants from a single sample;
4. extending variant calling to multiple samples; and
5. phasing heterozygous variants using long sequencing reads.

---

## 1. Learning objectives

By the end of this practical, you should be able to:

- explain how ONT reads are aligned to a reference genome;
- inspect and manipulate long-read CRAM/BAM files using `samtools`;
- call small variants from ONT reads;
- distinguish single-sample from multi-sample ONT variant calling;
- phase heterozygous variants using long reads;
- interpret basic VCF genotype and phasing information.

---


## 2. Software

The practical uses:

- [samtools](https://www.htslib.org/)
- [minimap2](https://github.com/lh3/minimap2)
- [bcftools](https://samtools.github.io/bcftools/)
- [Clair3](https://github.com/HKU-BAL/Clair3)
- [WhatsHap](https://whatshap.readthedocs.io/)



# 3. Datasets

The practical dataset contains ONT long-read data from 20 individuals:

```text
HG02562
HG02573
HG02585
HG02678
HG02703

HG02938
HG02953
HG03058
HG03115
HG03301

HG03394
HG03397
HG03457
HG03461
HG03499

NA19146
NA19189
NA19207
NA19338
NA19393
```

---

## 4. Set up the working directory

Create directories for the different stages of the analysis.

```bash
mkdir long-read-analysis
cd long-read-analysis
```

```bash
mkdir -p alignment variants multisample phasing
```

Define the reference genome.

```bash
REF=/etc/ace-data/genomics-resources/hg38/Homo_sapiens_assembly38.fasta
```

Check that it exists:

```bash
ls -lh $REF
```

Index it if necessary:

```bash
samtools faidx $REF
```

---


# PART II — ONT read alignment


Inspect the fastq files:

```bash
head /etc/ace-data/ABI-SummerSchool-26/human-genomics/data/reads/long-read/HG02562.fastq
```

Count the reads:

```bash
grep -c '^@' /etc/ace-data/ABI-SummerSchool-26/human-genomics/data/reads/long-read/HG02562.fastq
```

---

## 5. Align ONT reads with minimap2

`minimap2` is widely used for aligning long sequencing reads.

For standard ONT reads:

```bash
minimap2 \
    -ax map-ont \
    -t 4 \
    $REF \
    /etc/ace-data/ABI-SummerSchool-26/human-genomics/data/reads/long-read/HG02562.fastq \
    > alignment/HG02562.sam
```

### What do the options mean?

```text
-a          produce SAM output
-x map-ont  use the ONT alignment preset
-t 4        use four CPU threads
```

For newer high-accuracy ONT reads, the appropriate minimap2 preset may differ depending on the data and software version.

---

## 6. Convert SAM to BAM

SAM files are human-readable but large.

BAM files contain essentially the same alignment information in compressed binary form.

```bash
samtools view \
    -b \
    alignment/HG02562.sam \
    > alignment/HG02562.bam
```

Sort the alignments:

```bash
samtools sort \
    -@ 4 \
    -o alignment/HG02562.sorted.bam \
    alignment/HG02562.bam
```

Index:

```bash
samtools index alignment/HG02562.sorted.bam
```

Check:

```bash
samtools flagstat alignment/HG02562.sorted.bam
```

---



# PART II — Exploring ONT alignments


## 7. Examine the CRAM files

Check one CRAM file:

```bash
samtools quickcheck -v HG02562_subset_lr.cram
```

No output usually means that the basic integrity checks passed.

---


### Examine the CRAM header

```bash
samtools view -H HG02562_subset_lr.cram | head -30
```

Look for:

- `@SQ` — reference sequences;
- `@RG` — read groups;
- `@PG` — programs used to generate the alignment.

### Question

Can you identify the reference genome or chromosome(s) represented in the file?

---

### Examine individual alignments

```bash
samtools view HG02562_subset_lr.cram | head
```

The first fields represent:

```text
QNAME FLAG RNAME POS MAPQ CIGAR ...
```

For example:

```text
read001  0  chr1  123456  60  5000M ...
```

The **MAPQ** field represents mapping quality.

A higher value generally indicates greater confidence that the read has been aligned to the correct genomic location.

---


### Generate alignment statistics

```bash
samtools flagstat HG02562_subset_lr.cram
```

Also try:

```bash
samtools stats HG02562_subset_lr.cram | head -40
```

These commands provide information about the number of reads and their mapping characteristics.

---


# PART III — Single-sample variant calling


In this practical we use **Clair3**, a long-read small-variant caller that supports ONT data.

---


# 8. Run Clair3

The exact Clair3 model should match the ONT sequencing/basecalling chemistry used to generate the data.

Set the model directory

```bash
MODEL=/path/to/clair3/model
```

Then run:

```bash
run_clair3.sh \
    --bam_fn=alignment/HG02562_subset_lr.cram \
    --ref_fn=$REF \
    --threads=4 \
    --platform=ont \
    --model_path=$MODEL \
    --output=variants/HG02562
```

---

## Examine the resulting VCF

Clair3 normally produces a compressed VCF.

For example:

```bash
ls variants/HG02562
```

Inspect the variants:

```bash
bcftools view \
    variants/HG02562/merge_output.vcf.gz \
    | less -S
```

Display only variant records:

```bash
bcftools view \
    -H \
    variants/HG02562/merge_output.vcf.gz \
    | head
```

---

Count all variants:

```bash
bcftools view \
    -H \
    variants/HG02562/merge_output.vcf.gz \
    | wc -l
```

Count SNPs:

```bash
bcftools view \
    -v snps \
    -H \
    variants/HG02562/merge_output.vcf.gz \
    | wc -l
```

Count indels:

```bash
bcftools view \
    -v indels \
    -H \
    variants/HG02562/merge_output.vcf.gz \
    | wc -l
```

Generate statistics:

```bash
bcftools stats \
    variants/HG02562/merge_output.vcf.gz \
    > variants/HG02562.stats.txt
```

Inspect them:

```bash
less variants/HG02562.stats.txt
```

---

# PART IV — Multi-sample variant calling

## Why analyse multiple samples?

Single-sample calling asks:

> What variants are present in this individual?

Multi-sample analysis allows us to ask:

> How does genetic variation differ among individuals?

It facilitates analyses of:

- allele frequencies;
- shared and private variants;
- population variation;
- genotype comparisons;
- downstream association studies.

---

# 9. Call variants for several samples

For this tutorial, we will use four samples:

```text
HG02562
HG02938
HG03394
NA19146
```

Create a list:

```bash
SAMPLES="HG02562 HG02938 HG03394 NA19146"
```

Run Clair3 separately for each sample:

```bash
for SAMPLE in $SAMPLES
do

    mkdir -p variants/${SAMPLE}

    run_clair3.sh \
        --bam_fn=${SAMPLE}_subset_lr.cram \
        --ref_fn=$REF \
        --threads=4 \
        --platform=ont \
        --model_path=$MODEL \
        --output=variants/${SAMPLE}

done
```

---


Check that the files are indexed:

```bash
for SAMPLE in $SAMPLES
do
    bcftools index \
        -t \
        variants/${SAMPLE}/merge_output.vcf.gz
done
```

---


# 10. Merge samples

Combine the independently called sample VCFs:

```bash
bcftools merge \
    variants/HG02562/merge_output.vcf.gz \
    variants/HG02938/merge_output.vcf.gz \
    variants/HG03394/merge_output.vcf.gz \
    variants/NA19146/merge_output.vcf.gz \
    -m none
    -0 \
    -Oz \
    -o multisample/four_samples.vcf.gz
```

Index:

```bash
bcftools index \
    -t \
    multisample/four_samples.vcf.gz
```

> **Important:** merging independently called VCFs is useful for this teaching exercise, but it is not identical to a true joint-genotyping workflow. For a production study, use a workflow designed for cohort-level calling/joint genotyping and normalize variants consistently before downstream analyses.

---

# 11. Examine the samples

```bash
bcftools query \
    -l \
    multisample/four_samples.vcf.gz
```

Expected output:

```text
HG02562
HG02938
HG03394
NA19146
```

---

# Examine genotypes across individuals

```bash
bcftools query \
    -f '%CHROM\t%POS\t%REF\t%ALT[\t%GT]\n' \
    multisample/four_samples.vcf.gz \
    | head
```

You might see something like:

```text
chr1   12345   A   G   0/1   0/0   1/1   0/1
```

This immediately shows how the same locus differs among individuals.

---

# 12. Calculate allele frequencies

First calculate allele counts and frequencies:

```bash
bcftools +fill-tags \
    multisample/four_samples.vcf.gz \
    -Oz \
    -o multisample/four_samples.AF.vcf.gz \
    -- -t AC,AN,AF
```

Index:

```bash
bcftools index \
    -t \
    multisample/four_samples.AF.vcf.gz
```

View allele frequencies:

```bash
bcftools query \
    -f '%CHROM\t%POS\t%REF\t%ALT\t%AC\t%AN\t%AF\n' \
    multisample/four_samples.AF.vcf.gz \
    | head
```

Where:

```text
AC = alternate allele count
AN = total number of called alleles
AF = alternate allele frequency
```

---



# PART V — Long-read phasing

## What is phasing?

Consider two heterozygous variants:

```text
Position 1: A/G
Position 2: C/T
```

Without phasing we know both variants are present, but we do not know which alleles occur together on the same chromosome.

Possible haplotypes include:

```text
Chromosome 1: A -------- C
Chromosome 2: G -------- T
```

or:

```text
Chromosome 1: A -------- T
Chromosome 2: G -------- C
```

Long reads are particularly useful because **one sequencing read can span multiple heterozygous variants**.

---

## Unphased versus phased genotypes

An unphased genotype is represented as:

```text
0/1
```

A phased genotype is represented as:

```text
0|1
```

The vertical bar indicates that the haplotype relationship has been determined.

---

# 14. Phase variants using WhatsHap

Take the single-sample VCF for HG02562.

First make sure it is indexed:

```bash
bcftools index \
    -t \
    variants/HG02562/merge_output.vcf.gz
```

Run WhatsHap:

```bash
whatshap phase \
    --reference=$REF \
    -o phasing/HG02562.phased.vcf \
    variants/HG02562/merge_output.vcf.gz \
    HG02562_subset_lr.cram
```

Compress the result:

```bash
bgzip \
    -c phasing/HG02562.phased.vcf \
    > phasing/HG02562.phased.vcf.gz
```

Index:

```bash
tabix \
    -p vcf \
    phasing/HG02562.phased.vcf.gz
```

---

## Examine phased variants

Display genotype and phase-set information:

```bash
bcftools query \
    -f '%CHROM\t%POS[\t%GT\t%PS]\n' \
    phasing/HG02562.phased.vcf.gz \
    | head -20
```

Look for genotypes such as:

```text
0|1
```

and:

```text
1|0
```

rather than:

```text
0/1
```

The `PS` field identifies variants belonging to the same **phase set** or phased block.

---

# 15. Compare before and after phasing

Before:

```bash
bcftools query \
    -f '%CHROM\t%POS[\t%GT]\n' \
    variants/HG02562/merge_output.vcf.gz \
    | head
```

After:

```bash
bcftools query \
    -f '%CHROM\t%POS[\t%GT]\n' \
    phasing/HG02562.phased.vcf.gz \
    | head
```


# 15. Optional: haplotag the reads

WhatsHap can assign reads to haplotypes based on phased variants.

```bash
whatshap haplotag \
    --reference=$REF \
    -o phasing/HG02562.haplotagged.bam \
    phasing/HG02562.phased.vcf.gz \
    HG02562_subset_lr.cram
```

Index:

```bash
samtools index \
    phasing/HG02562.haplotagged.bam
```

Inspect:

```bash
samtools view \
    phasing/HG02562.haplotagged.bam \
    | head
```

Look towards the end of each SAM record for tags such as:

```text
HP:i:1
```

or:

```text
HP:i:2
```

These indicate that the read has been assigned to **haplotype 1** or **haplotype 2**.

---



# 16. Scaling from one sample to 20 samples

We analysed only a few samples interactively, but the dataset contains:

```text
HG02562 HG02573 HG02585 HG02678 HG02703
HG02938 HG02953 HG03058 HG03115 HG03301
HG03394 HG03397 HG03457 HG03461 HG03499
NA19146 NA19189 NA19207 NA19338 NA19393
```


# Exercise

Write a Nextflow workflow to replicate the multi-sample variant calling and indexing above on the full set of 20 samples.


# 17. Discussion questions

### Question 1

Why are long reads particularly useful for phasing?

### Question 2

Why might variant calling from ONT reads require algorithms specifically trained for long-read sequencing errors?

### Question 3

Why might calling variants independently in 1,000 individuals and simply merging the VCFs be problematic?

### Question 4

What advantages would HPC provide if we wanted to analyse 1,000 ONT whole genomes?

---


# 18. Further reading

- minimap2 documentation: https://github.com/lh3/minimap2
- SAMtools documentation: https://www.htslib.org/
- BCFtools documentation: https://samtools.github.io/bcftools/
- Clair3 documentation: https://github.com/HKU-BAL/Clair3
- WhatsHap documentation: https://whatshap.readthedocs.io/

---

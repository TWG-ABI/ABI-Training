# Day 3 Practical: Shotgun Metagenomics Pipeline

## Purpose

Unlike amplicon sequencing (Day 1), shotgun metagenomics sequences all DNA in a sample,
enabling species-level taxonomic profiling *and* functional/genomic content (assembly,
binning — covered Days 4–5). This practical walks through the standard shotgun workflow:
QC → adapter/quality trimming → host DNA removal → taxonomic classification → de novo
assembly and assessment. Two contrasting sample types (human gut vs soil) are processed
side by side to highlight how host contamination is a gut-specific concern.

## Setup

```bash
set -euo pipefail

GUT_DIR="../../data/shotgun/gut"
SOIL_DIR="../../data/shotgun/soil"
REF_DIR="../../data/reference"
OUT_DIR="day3_results"
THREADS=8
HOST_IDX="${REF_DIR}/human_genome/GRCh38"
KRAKEN_DB="${REF_DIR}/kraken2_db"

mkdir -p ${OUT_DIR}/{qc,trimmed,host_removed,kraken2,assembly,quast}
```
All intermediate output directories are created up front using brace expansion, keeping
the pipeline organised by stage.

---

## Section 1 — Quality Control (FastQC + MultiQC)

```bash
for R1 in ${GUT_DIR}/*_R1.fastq.gz; do
    SAMPLE=$(basename ${R1} _R1.fastq.gz)
    R2="${GUT_DIR}/${SAMPLE}_R2.fastq.gz"
    fastqc --outdir ${OUT_DIR}/qc --threads 2 --quiet ${R1} ${R2}
done
```
Same idea as Day 1 — FastQC per paired-end sample — but looped explicitly over both gut
and soil directories (each with its own loop) since shotgun samples typically live in
type-specific subfolders.

```bash
multiqc ${OUT_DIR}/qc/ --outdir ${OUT_DIR}/qc/multiqc --quiet
```
Aggregates all FastQC reports (gut + soil together) into one dashboard for a quick
side-by-side quality comparison across sample types.

---

## Section 2 — Trimming with fastp

```bash
for R1 in ${GUT_DIR}/*_R1.fastq.gz ${SOIL_DIR}/*_R1.fastq.gz; do
    SAMPLE=$(basename ${R1} _R1.fastq.gz)
    if [[ "${R1}" == *gut* ]]; then
        R2="${GUT_DIR}/${SAMPLE}_R2.fastq.gz"; PREFIX="gut"
    else
        R2="${SOIL_DIR}/${SAMPLE}_R2.fastq.gz"; PREFIX="soil"
    fi

    fastp \
        --in1 ${R1} --in2 ${R2} \
        --out1 ${OUT_DIR}/trimmed/${SAMPLE}_R1_trimmed.fastq.gz \
        --out2 ${OUT_DIR}/trimmed/${SAMPLE}_R2_trimmed.fastq.gz \
        --qualified_quality_phred 20 \
        --length_required 50 \
        --detect_adapter_for_pe \
        --thread ${THREADS} \
        --json ${OUT_DIR}/trimmed/${SAMPLE}_fastp.json \
        --html ${OUT_DIR}/trimmed/${SAMPLE}_fastp.html
done
```
**fastp** performs combined adapter trimming and quality filtering in one fast step:
- `--qualified_quality_phred 20`: bases are only counted as "qualified" (kept) above Q20.
- `--length_required 50`: discard reads shorter than 50 bp after trimming — too short to
  map or assemble reliably.
- `--detect_adapter_for_pe`: auto-detects adapter sequences by overlap analysis between
  read pairs, rather than requiring a known adapter FASTA.
- Per-sample JSON/HTML reports let you audit trimming statistics individually, in
  addition to the aggregate MultiQC view from Section 1.

The `$(basename ...)` + string-matching (`*gut*`) logic determines whether each file
belongs to the gut or soil set purely from its path, since both are looped together here.

```bash
seqkit stats ${OUT_DIR}/trimmed/*_R1_trimmed.fastq.gz | ...
```
A quick read-count summary post-trimming, letting you gauge how much data survived
filtering before moving to host removal / classification.

---

## Section 3 — Host Read Removal (gut samples only)

```bash
if [ -f "${HOST_IDX}.1.bt2" ]; then
    for R1 in ${OUT_DIR}/trimmed/gut*_R1_trimmed.fastq.gz; do
        ...
        bowtie2 \
            -x ${HOST_IDX} \
            -1 ${R1} -2 ${R2} \
            --un-conc-gz ${OUT_DIR}/host_removed/${SAMPLE}_clean_%.fastq.gz \
            --threads ${THREADS} \
            --very-sensitive \
            2>${OUT_DIR}/host_removed/${SAMPLE}_bowtie2.log \
            | samtools view -bS > /dev/null
    done
```
Human gut metagenomes are typically 1–50%+ human DNA by read count, which must be removed
before taxonomic profiling of the microbial community (and for ethical/privacy reasons —
human reads should not be shared or uploaded to public databases). Reads are aligned
against the GRCh38 human reference with Bowtie2:
- `--un-conc-gz ..._clean_%.fastq.gz`: writes reads that *fail* to align concordantly as a
  pair (i.e. non-human reads) to `_clean_1.fastq.gz`/`_clean_2.fastq.gz` — the `%` is
  replaced by 1/2 automatically. This is the key flag: it's discarding the human-mapping
  reads and keeping everything else.
- `--very-sensitive`: a slower but more thorough alignment preset, trading speed for
  fewer missed human reads (false negatives here mean human contamination leaking into
  the "clean" set).
- The aligned SAM stream itself is piped to `samtools view -bS > /dev/null` and discarded
  — here we only care about *which reads didn't map*, not the alignments themselves.

```bash
HOST_RATE=$(grep "overall alignment rate" \
    ${OUT_DIR}/host_removed/${SAMPLE}_bowtie2.log | awk '{print $1}')
echo "    Host alignment rate: ${HOST_RATE}"
```
Bowtie2 prints its alignment rate to stderr (captured in the log); this extracts and
reports it per sample as a direct estimate of "% human DNA" in that gut sample.

```bash
else
    echo "  WARNING: Human genome index not found..."
    for R1 in ${OUT_DIR}/trimmed/gut*_R1_trimmed.fastq.gz; do
        cp ${R1} ${OUT_DIR}/host_removed/${SAMPLE}_clean_1.fastq.gz
        ...
    done
fi
```
Graceful fallback: if the (large, multi-GB) human genome index isn't available, the
script still proceeds by simply copying the trimmed reads through unchanged, so the rest
of the pipeline doesn't break — with a clear warning that host removal was skipped.

```bash
# Soil samples — no host removal needed, just copy
for R1 in ${OUT_DIR}/trimmed/soil*_R1_trimmed.fastq.gz; do
    cp ${R1} ${OUT_DIR}/host_removed/${SAMPLE}_clean_1.fastq.gz
    ...
done
```
Soil samples have no human host to remove, so they're simply copied into the same
`host_removed/` naming convention — this keeps downstream steps (Kraken2, assembly)
agnostic to sample type, since both gut and soil files now share the same
`_clean_1/2.fastq.gz` naming pattern.

---

## Section 4 — Taxonomic Classification: Kraken2 + Bracken

```bash
if [ -d "${KRAKEN_DB}" ]; then
    for R1 in ${OUT_DIR}/host_removed/*_clean_1.fastq.gz; do
        ...
        kraken2 \
            --db ${KRAKEN_DB} \
            --paired ${R1} ${R2} \
            --threads ${THREADS} \
            --report ${OUT_DIR}/kraken2/${SAMPLE}.report \
            --output ${OUT_DIR}/kraken2/${SAMPLE}.out \
            --gzip-compressed \
            2>${OUT_DIR}/kraken2/${SAMPLE}_kraken2.log
```
**Kraken2** classifies each read by exact k-mer matching against a reference database of
genomes, assigning it to the lowest common ancestor (LCA) of all matching taxa. `--paired`
tells it R1/R2 belong together; `--report` produces a hierarchical, tree-structured
summary (reads per taxon at each rank) in addition to the per-read `--output`.

```bash
        if command -v bracken &> /dev/null; then
            bracken \
                -d ${KRAKEN_DB} \
                -i ${OUT_DIR}/kraken2/${SAMPLE}.report \
                -o ${OUT_DIR}/kraken2/${SAMPLE}_bracken.txt \
                -r 150 -l S
        fi
```
Kraken2's raw read counts per taxon are biased by genome size and shared k-mers between
related species. **Bracken** re-estimates more accurate relative abundances at a chosen
rank (`-l S` = species level) using a Bayesian re-distribution model, given the average
read length (`-r 150`).

```bash
        echo "    $(grep 'unclassified' ${OUT_DIR}/kraken2/${SAMPLE}.report | \
                   awk '{printf "Classified: %.1f%%\n", 100-$1}')"
```
Extracts the "unclassified" percentage from the Kraken2 report and reports its complement
as an at-a-glance classification rate per sample — soil samples typically classify worse
than gut samples due to sparser reference genome coverage for environmental microbes.

```bash
else
    echo "  WARNING: Kraken2 database not found..."
fi
```
Again, a graceful warning-and-skip if the (often very large, tens of GB) Kraken2 database
isn't installed, rather than a hard crash.

---

## Section 5 — De Novo Assembly with MEGAHIT + QUAST

```bash
DEMO_SAMPLE=$(ls ${OUT_DIR}/host_removed/soil*_clean_1.fastq.gz 2>/dev/null | head -1)
```
Assembly is computationally expensive, so — for course time constraints — only a single
soil sample is assembled as a worked demonstration (soil is chosen since gut samples were
just human-DNA-filtered, but either could be used in a full analysis).

```bash
megahit \
    -1 ${DEMO_SAMPLE} \
    -2 ${R2} \
    -o ${OUT_DIR}/assembly/${SAMPLE_NAME} \
    --threads ${THREADS} \
    --min-contig-len 1000 \
    --memory 0.5
```
**MEGAHIT** is a memory-efficient de Bruijn graph assembler well suited to complex,
high-diversity metagenomes. `--min-contig-len 1000` discards very short contigs that add
noise without being useful for binning; `--memory 0.5` caps memory usage to 50% of
available RAM, useful on shared training-cluster machines.

```bash
seqkit stats --all ${OUT_DIR}/assembly/${SAMPLE_NAME}/final.contigs.fa | column -t
```
Reports assembly-level statistics: number of contigs (lower is generally better — fewer,
longer contigs indicate a more complete assembly), and min/average/max contig length
(higher is better, reflecting longer contiguous genomic stretches recovered).

```bash
seqkit seq --min-len 1500 \
    ${OUT_DIR}/assembly/${SAMPLE_NAME}/final.contigs.fa \
    > ${OUT_DIR}/assembly/${SAMPLE_NAME}/contigs_min1500.fa
```
A stricter length filter (≥1500 bp) is applied specifically to prepare contigs for
**binning** on Day 4 — very short contigs carry too little compositional/coverage
signal for binning tools to place them reliably into genome bins.

```bash
quast.py \
    ${OUT_DIR}/assembly/${SAMPLE_NAME}/contigs_min1500.fa \
    --output-dir ${OUT_DIR}/quast/${SAMPLE_NAME} \
    --threads ${THREADS} \
    --no-check-install
```
**QUAST** computes standard assembly quality metrics on the filtered contig set:
- **N50** — the contig length at which 50% of total assembly length is contained in
  contigs of that length or longer; *higher is better* (indicates longer, more contiguous
  sequences).
- **L50** — the *number* of contigs needed to reach that 50% threshold; *lower is better*
  (fewer, larger pieces).
- **# contigs** — lower is generally better for a given total assembly length (less
  fragmentation).
- **Largest contig** / **Total length** — sanity-checked against the expected genome/
  metagenome size for the sample type.

---

## Key Outputs

| Output | Path |
|---|---|
| MultiQC (raw QC) | `${OUT_DIR}/qc/multiqc/` |
| Cleaned (host-filtered) reads | `${OUT_DIR}/host_removed/` |
| Kraken2/Bracken classifications | `${OUT_DIR}/kraken2/` |
| Assembly (demo soil sample) | `${OUT_DIR}/assembly/` |
| QUAST report | `${OUT_DIR}/quast/` |

## Discussion Questions

1. What % of gut reads were human DNA? Is this expected?
2. What are the most abundant species in gut vs soil samples?
3. What is the N50 of the assembly? How does this compare to genome size?
4. How many contigs are ≥1500 bp (usable for binning)?

<style>
/* Clean, modern, high-contrast code blocks with pretty borders */
div.sourceCode, pre.sourceCode, pre, pre code, div.cell-code pre {
  background-color: #f8f9fa !important;
  color: #212529 !important;
  border: 1px solid #dee2e6 !important;
  border-left: 4px solid #31BAE9 !important;
  border-radius: 6px !important;
}

/* Base text (plain tokens, punctuation) */
code span {
  color: #212529 !important;
}

/* Comments / shebangs */
code span.co, code span.c, code span.ch, code span.cm, code span.c1 {
  color: #2e7d32 !important; /* green */
  font-weight: 600 !important;
  opacity: 1 !important;
}

/* Strings */
code span.st, code span.s, code span.s1, code span.s2 {
  color: #c2410c !important; /* burnt orange */
}

/* Keywords (set, if, for, function, etc.) */
code span.kw {
  color: #7c3aed !important; /* purple */
  font-weight: 600 !important;
}

/* Variables ($VAR, DATA_DIR, etc.) */
code span.va {
  color: #0369a1 !important; /* blue */
}

/* Function / command names */
code span.fu {
  color: #b91c1c !important; /* red */
}

/* Numbers */
code span.dv, code span.fl, code span.bn, code span.cn {
  color: #b45309 !important; /* amber */
}

/* Operators, flags like -e, -u, -o */
code span.op {
  color: #495057 !important;
}

/* Errors / special tokens Pandoc sometimes flags */
code span.er {
  color: #dc2626 !important;
  font-weight: 600 !important;
}
</style>

# Day 1 Practical — Part 1: Quality Control with FastQC & SeqKit

## Purpose

Before any downstream analysis (denoising, assembly, taxonomic classification), raw
sequencing reads must be inspected for quality, length distribution, and composition.
This practical introduces two complementary QC tools:

- **SeqKit** — a fast command-line toolkit for FASTA/FASTQ manipulation and summary statistics
- **FastQC / MultiQC** — per-base quality visualisation and aggregated reporting across samples

By the end of this session you should be able to explain *why* a dataset does or doesn't
need trimming, and *where* to look for adapter contamination or low-quality tails.

## Setup

```bash
set -euo pipefail
```
`set -euo pipefail` makes the script stop immediately on any error (`-e`), treat unset
variables as errors (`-u`), and fail if any command in a pipe fails (`-o pipefail`) — good
practice for reproducible pipelines.

```bash
DATA_DIR="data/amplicon/gut"
OUT_DIR="day1_results/qc"
THREADS=4
```
Paths and thread count are defined once at the top so they're easy to adjust for a
different dataset or machine.

---

## Section 1 — SeqKit: Exploring your FASTQ files

### 1a. Summary statistics for all samples

```bash
seqkit stats --all --tabular --threads ${THREADS} ${DATA_DIR}/*.fastq.gz \
    > ${OUT_DIR}/seqkit_stats.tsv
```
- `--all` reports extended stats (min/avg/max length, N50, GC%, Q20/Q30 rates) rather than
  just read counts.
- `--tabular` outputs machine-readable TSV instead of a formatted table — useful for
  downstream parsing in R or Excel.
- Running this across `*.fastq.gz` in one call lets SeqKit process all samples in a single
  pass rather than looping manually.

**What to look for:** number of reads per sample (are libraries balanced?), average read
length (does it match the expected amplicon/read length?), and Q20/Q30 percentages (a
rough proxy for overall quality before you even open FastQC).

### 1b. GC content per file

```bash
seqkit fx2tab --name --gc ${DATA_DIR}/*.fastq.gz | \
    awk '{sum+=$3; n++} END {printf "Mean GC: %.1f%%\n", sum/n}'
```
`fx2tab` converts FASTQ/FASTA records to a simple tabular format; here `--gc` adds a GC%
column per read. The `awk` command averages that column across all reads to give a single
mean GC% for the dataset — a quick sanity check (e.g. gut 16S amplicons are typically in
the 45–55% GC range; strong deviations can indicate contamination or the wrong reference).

### 1c. Read length distribution (first sample)

```bash
FIRST_SAMPLE=$(ls ${DATA_DIR}/*.fastq.gz | head -1)
seqkit fx2tab --name --length ${FIRST_SAMPLE} | \
    awk '{len[$2]++} END {for (l in len) print l"\t"len[l]}' | \
    sort -n | \
    awk '{printf "Length %s bp: %d reads\n", $1, $2}'
```
This builds a histogram of read lengths for one representative sample: `fx2tab --length`
adds a length column, the first `awk` tallies how many reads fall at each length, and the
final `sort`/`awk` pair prints it in ascending, human-readable order. For amplicon data you
generally expect a tight peak at the expected amplicon length (e.g. ~250 bp for V4 16S);
a broad or bimodal distribution can flag primer-trimming issues.

### 1d. Subsampling for the FastQC demo

```bash
seqkit sample --proportion 0.1 --rand-seed 42 ${FIRST_SAMPLE} \
    --out-file ${OUT_DIR}/demo_sample_sub.fastq.gz
```
`--proportion 0.1` randomly keeps ~10% of reads; `--rand-seed 42` makes the subsampling
reproducible. This is purely a *teaching convenience* to make FastQC run quickly during
the course — in a real analysis you would run FastQC on the full file.

---

## Section 2 — FastQC: Per-sample quality reports

```bash
fastqc --outdir ${OUT_DIR}/fastqc --threads ${THREADS} --quiet ${DATA_DIR}/*.fastq.gz
```
FastQC generates an HTML report per FASTQ file covering per-base quality scores, GC
content distribution, sequence duplication levels, adapter content, and overrepresented
sequences. `--quiet` suppresses per-file progress messages so the log stays readable when
processing many samples at once.

---

## Section 3 — MultiQC: Aggregating FastQC reports

```bash
multiqc ${OUT_DIR}/fastqc/ --outdir ${OUT_DIR}/multiqc \
    --filename "multiqc_day1_amplicon" --quiet
```
MultiQC scans a directory of tool outputs (here, all the FastQC reports) and produces a
single interactive HTML dashboard. This is essential once you have more than a handful of
samples — comparing 20 separate FastQC pages by eye doesn't scale, but MultiQC overlays
all per-base quality curves and duplication rates on one page.

---

## Section 4 — SeqKit: Advanced filtering and manipulation

### 4a. Filter reads below a minimum length

```bash
seqkit seq --min-len 200 ${FIRST_SAMPLE} --out-file ${OUT_DIR}/filtered_min200.fastq.gz
```
`seqkit seq` is a general sequence-filtering command; `--min-len 200` discards any read
shorter than 200 bp. Short fragments are often adapter dimers or degraded reads that add
noise to downstream clustering/denoising.

### 4b. Count filtered reads

```bash
ORIG=$(seqkit stats ${FIRST_SAMPLE} | awk 'NR==2{print $4}')
FILT=$(seqkit stats ${OUT_DIR}/filtered_min200.fastq.gz | awk 'NR==2{print $4}')
echo "Original reads: ${ORIG}"
echo "After length filter (≥200 bp): ${FILT}"
```
`seqkit stats` without `--tabular` prints a formatted table; column 4 (`NR==2`, i.e. the
first data row) is the read count. Comparing before/after gives a quick sense of how much
data the length filter removes.

### 4c. Convert FASTQ to FASTA

```bash
seqkit fq2fa ${FIRST_SAMPLE} --out-file ${OUT_DIR}/demo_sample.fasta.gz
```
Some downstream tools (e.g. certain taxonomy classifiers, BLAST-based searches) require
FASTA rather than FASTQ input, since they don't use quality scores. `fq2fa` strips the
quality lines and keeps only sequence + header.

---

## Key Outputs

| Output | Path |
|---|---|
| SeqKit stats | `${OUT_DIR}/seqkit_stats.tsv` |
| FastQC reports | `${OUT_DIR}/fastqc/` |
| MultiQC report | `${OUT_DIR}/multiqc/multiqc_day1_amplicon.html` — open in a browser |

## Discussion Questions

1. What is the average read length? Is this expected for V4 amplicons?
2. Are there any samples with poor quality? How would you identify them?
3. Is there significant adapter contamination?
4. What does the GC content plot look like? Any outliers?

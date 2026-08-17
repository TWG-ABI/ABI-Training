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

---

# Day 1 Practical — Part 2: QIIME2 Amplicon Analysis Pipeline

## Purpose

This practical takes the QC-passed reads from Part 1 through a complete amplicon
sequence variant (ASV) workflow in **QIIME2**: importing paired-end reads, denoising with
DADA2, building a phylogenetic tree, assigning taxonomy, and exporting everything for
downstream diversity analysis in R (Day 2).

## Setup and Pre-flight Check

```bash
set -euo pipefail

DATA_DIR="../../data/amplicon/gut"
REF_DIR="../../data/reference"
OUT_DIR="day1_results/qiime2"
MANIFEST="manifest.tsv"
METADATA="metadata.tsv"
CLASSIFIER="${REF_DIR}/silva-138-99-seqs-515-806-classifier.qza"
THREADS=4
```
Paths and the SILVA classifier location are defined up front.

```bash
if [ ! -f "${CLASSIFIER}" ]; then
    echo "ERROR: SILVA classifier not found..."
    exit 1
fi
```
The script fails fast with a clear message (and the download URL) if the pre-trained
taxonomy classifier hasn't been downloaded yet, rather than running for an hour and
failing at Step 6.

---

## Step 1 — Import paired-end reads into QIIME2

```bash
if [ ! -f "${MANIFEST}" ]; then
    echo -e "sample-id\tforward-absolute-filepath\treverse-absolute-filepath" > ${MANIFEST}
    for R1 in ${DATA_DIR}/*_R1.fastq.gz; do
        SAMPLE=$(basename ${R1} _R1.fastq.gz)
        R2="${DATA_DIR}/${SAMPLE}_R2.fastq.gz"
        if [ -f "${R2}" ]; then
            echo -e "${SAMPLE}\t$(realpath ${R1})\t$(realpath ${R2})" >> ${MANIFEST}
        fi
    done
fi
```
QIIME2 needs a **manifest file** mapping each sample ID to the absolute paths of its
forward/reverse FASTQ files. This block auto-generates that manifest by pairing up
`_R1`/`_R2` files, but only if a manifest doesn't already exist — so you can hand-edit it
once and re-run the script without it being overwritten.

```bash
qiime tools import \
    --type 'SampleData[PairedEndSequencesWithQuality]' \
    --input-path ${MANIFEST} \
    --output-path ${OUT_DIR}/paired-end-demux.qza \
    --input-format PairedEndFastqManifestPhred33V2
```
This imports the raw reads into QIIME2's native `.qza` (QIIME Zipped Artifact) format,
using the manifest to associate files with sample IDs. `PairedEndFastqManifestPhred33V2`
specifies both the manifest format version and that quality scores use the standard
Phred+33 encoding.

---

## Step 2 — Visualise demultiplexed read quality

```bash
qiime demux summarize \
    --i-data ${OUT_DIR}/paired-end-demux.qza \
    --o-visualization ${OUT_DIR}/demux-summary.qzv
```
Produces a `.qzv` (QIIME Zipped Visualization) with interactive per-base quality plots for
forward and reverse reads. **This is the step that determines the truncation lengths used
in DADA2 below** — you inspect where quality drops off and truncate before that point.
View any `.qzv` file at https://view.qiime2.org by uploading it.

---

## Step 3 — DADA2: Denoising, error correction, chimera removal

```bash
qiime dada2 denoise-paired \
    --i-demultiplexed-seqs ${OUT_DIR}/paired-end-demux.qza \
    --p-trim-left-f 0 \
    --p-trim-left-r 0 \
    --p-trunc-len-f 240 \
    --p-trunc-len-r 200 \
    --p-n-threads ${THREADS} \
    --o-table ${OUT_DIR}/table.qza \
    --o-representative-sequences ${OUT_DIR}/rep-seqs.qza \
    --o-denoising-stats ${OUT_DIR}/dada2-stats.qza \
    --verbose
```
DADA2 models the error profile of the sequencing run to correct errors and infer exact
**amplicon sequence variants (ASVs)** — a higher-resolution alternative to OTU clustering —
and removes chimeric sequences.

- `--p-trim-left-f/-r 0`: bases to trim from the 5′ end (e.g. primers); set to 0 here
  because primers were presumably already removed, or none are present.
- `--p-trunc-len-f 240` / `--p-trunc-len-r 200`: truncate forward reads at 240 bp and
  reverse reads at 200 bp, based on where quality drops in the Step 2 plots. Reverse reads
  typically degrade faster, hence the shorter truncation length.
- Outputs: a **feature table** (`table.qza`, ASV × sample counts), **representative
  sequences** (`rep-seqs.qza`, one sequence per ASV), and **denoising stats** (read counts
  retained at each filtering stage).

```bash
qiime metadata tabulate \
    --m-input-file ${OUT_DIR}/dada2-stats.qza \
    --o-visualization ${OUT_DIR}/dada2-stats.qzv
```
Turns the denoising stats artifact into a browsable table — check what fraction of raw
reads survived filtering, denoising, merging, and chimera removal at each stage.

---

## Step 4 — Feature table summary

```bash
qiime feature-table summarize \
    --i-table ${OUT_DIR}/table.qza \
    --o-visualization ${OUT_DIR}/table-summary.qzv \
    --m-sample-metadata-file ${METADATA}

qiime feature-table tabulate-seqs \
    --i-data ${OUT_DIR}/rep-seqs.qza \
    --o-visualization ${OUT_DIR}/rep-seqs.qzv
```
`feature-table summarize` reports the number of ASVs, per-sample read count distribution,
and frequency histograms — useful for spotting samples with very low sequencing depth that
may need to be excluded before rarefaction. `tabulate-seqs` lists each ASV's sequence and
length, with a BLAST link for quick identification.

---

## Step 5 — Phylogenetic tree (needed for UniFrac on Day 2)

```bash
qiime phylogeny align-to-tree-mafft-fasttree \
    --i-sequences ${OUT_DIR}/rep-seqs.qza \
    --o-alignment ${OUT_DIR}/aligned-rep-seqs.qza \
    --o-masked-alignment ${OUT_DIR}/masked-aligned-rep-seqs.qza \
    --o-tree ${OUT_DIR}/unrooted-tree.qza \
    --o-rooted-tree ${OUT_DIR}/rooted-tree.qza \
    --p-n-threads ${THREADS}
```
This convenience action chains four steps: MAFFT multiple sequence alignment of all ASVs,
masking of highly variable/uninformative alignment columns, FastTree construction of an
unrooted tree, and midpoint rooting to produce a rooted tree. The rooted tree is required
for phylogenetically-aware beta diversity metrics (e.g. weighted/unweighted UniFrac) used
in Day 2.

---

## Step 6 — Taxonomy assignment with the SILVA classifier

```bash
qiime feature-classifier classify-sklearn \
    --i-classifier ${CLASSIFIER} \
    --i-reads ${OUT_DIR}/rep-seqs.qza \
    --o-classification ${OUT_DIR}/taxonomy.qza \
    --p-n-jobs ${THREADS}
```
Uses a pre-trained naive Bayes classifier (trained on the SILVA 138.1 database, restricted
to the 515F/806R V4 primer region) to assign taxonomy to each ASV.

```bash
qiime metadata tabulate \
    --m-input-file ${OUT_DIR}/taxonomy.qza \
    --o-visualization ${OUT_DIR}/taxonomy.qzv
```
Makes the taxonomy assignments browsable alongside each ASV's confidence score.

---

## Step 7 — Taxonomy bar plots

```bash
qiime taxa barplot \
    --i-table ${OUT_DIR}/table.qza \
    --i-taxonomy ${OUT_DIR}/taxonomy.qza \
    --m-metadata-file ${METADATA} \
    --o-visualization ${OUT_DIR}/taxa-bar-plots.qzv
```
Generates an interactive stacked bar plot of relative taxonomic composition per sample,
adjustable to any taxonomic level (Phylum, Family, Genus, etc.) directly in the
qiime2 viewer.

---

## Export — Preparing artifacts for R analysis (Day 2)

```bash
mkdir -p ${OUT_DIR}/exported

qiime tools export --input-path ${OUT_DIR}/table.qza \
    --output-path ${OUT_DIR}/exported/feature_table
biom convert -i ${OUT_DIR}/exported/feature_table/feature-table.biom \
    -o ${OUT_DIR}/exported/feature_table/feature-table.tsv --to-tsv

qiime tools export --input-path ${OUT_DIR}/taxonomy.qza \
    --output-path ${OUT_DIR}/exported/taxonomy

qiime tools export --input-path ${OUT_DIR}/rooted-tree.qza \
    --output-path ${OUT_DIR}/exported/tree
```
QIIME2 artifacts (`.qza`) are opaque zip containers — R packages like `phyloseq` need
plain-text/BIOM inputs. This block exports the feature table (converting the binary BIOM
format to TSV with `biom convert`), taxonomy table, and phylogenetic tree (Newick format)
into `exported/`, which is exactly what Day 2's `phyloseq` workflow loads.

---

## Key Outputs

| Output | Path |
|---|---|
| Quality check | `${OUT_DIR}/demux-summary.qzv` |
| DADA2 stats | `${OUT_DIR}/dada2-stats.qzv` |
| Feature table summary | `${OUT_DIR}/table-summary.qzv` |
| Taxonomy bar plots | `${OUT_DIR}/taxa-bar-plots.qzv` |
| Exported for Day 2 | `${OUT_DIR}/exported/` (feature table, taxonomy, tree) |

## Discussion Questions

1. How many ASVs were detected? How does this compare to OTU-based methods?
2. What fraction of reads passed DADA2 filtering? Is this expected?
3. What are the dominant phyla in the gut samples?
4. Are there differences between samples visible in the bar plot?

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

# Day 5 Practical — Part 1: Functional Analysis

## Purpose

Taxonomy tells you *who* is present (Days 1–4); functional analysis tells you *what they
can do*. This practical covers gene prediction and annotation on individual MAGs (Prokka,
eggNOG-mapper), community-wide pathway profiling directly from reads (HUMAnN3), and
antimicrobial resistance (AMR) gene screening — the standard functional toolkit for
metagenomic studies.

## Setup

```bash
set -euo pipefail

DAY3_DIR="../day3/day3_results"
DAY4_DIR="../day4/day4_results"
OUT_DIR="day5_results"
THREADS=8
HUMANN_DB="${HUMANN_DB_PATH:-../../data/reference/humann3}"

MAG_DIR="${DAY4_DIR}/das_tool/DAS_output_DASTool_bins"
if [ ! -d "${MAG_DIR}" ]; then
    MAG_DIR="${DAY4_DIR}/metabat2/bins"
fi

mkdir -p ${OUT_DIR}/{prokka,eggnog,humann3,amr}
```
Prefers the DAS_Tool-refined MAGs from Day 4 as the highest-quality bin set, falling back
to raw MetaBAT2 bins if refinement wasn't run — the same fallback pattern used throughout
Day 4.

---

## Section 1 — Gene Prediction & Annotation with Prokka

```bash
N_MAGS=0
for MAG in ${MAG_DIR}/*.fa; do
    MAG_NAME=$(basename ${MAG} .fa)
    N_MAGS=$((N_MAGS + 1))

    if [ ${N_MAGS} -gt 3 ]; then
        echo "  (Limiting to 3 MAGs for course time)"
        break
    fi

    prokka \
        --outdir ${OUT_DIR}/prokka/${MAG_NAME} \
        --prefix ${MAG_NAME} \
        --cpus ${THREADS} \
        --kingdom Bacteria \
        --quiet \
        ${MAG}
```
**Prokka** performs rapid, standardised prokaryotic genome annotation: gene calling (via
Prodigal internally), followed by function assignment through similarity search against
curated protein databases, output as GFF/GenBank/FASTA files including a `.faa` (protein
FASTA) file per genome. `--kingdom Bacteria` selects the appropriate reference gene
models; only the first 3 MAGs are annotated to keep runtime manageable during the course
(in a full analysis, every MAG would be annotated).

```bash
    if [ -f "${OUT_DIR}/prokka/${MAG_NAME}/${MAG_NAME}.txt" ]; then
        grep -E "CDS|rRNA|tRNA|gene" \
            ${OUT_DIR}/prokka/${MAG_NAME}/${MAG_NAME}.txt | \
            awk '{printf "    %-12s %s\n", $1, $2}'
    fi
```
Prokka's `.txt` summary file reports counts of each feature type predicted (coding
sequences, rRNAs, tRNAs); this prints them per MAG as a quick genome-content overview.

```bash
cat ${OUT_DIR}/prokka/*/*/*.faa > ${OUT_DIR}/prokka/all_MAGs.faa 2>/dev/null || \
    cat ${OUT_DIR}/prokka/*/*.faa > ${OUT_DIR}/prokka/all_MAGs.faa 2>/dev/null

TOTAL_GENES=$(grep -c "^>" ${OUT_DIR}/prokka/all_MAGs.faa 2>/dev/null || echo 0)
```
Concatenates every MAG's predicted proteins into one combined FASTA — annotating and
profiling all genes together in one batch (Section 2/4 below) is far more efficient than
running each tool separately per MAG. The two alternate `cat` glob patterns handle
possible differences in Prokka's output directory nesting; `grep -c "^>"` counts total
predicted genes across all annotated MAGs.

---

## Section 2 — Functional Annotation with eggNOG-mapper

```bash
if [ -f "${OUT_DIR}/prokka/all_MAGs.faa" ] && [ ${TOTAL_GENES} -gt 0 ]; then
    if command -v emapper.py &> /dev/null; then
        emapper.py \
            -i ${OUT_DIR}/prokka/all_MAGs.faa \
            -o ${OUT_DIR}/eggnog/all_MAGs_eggnog \
            --cpu ${THREADS} \
            --output_dir ${OUT_DIR}/eggnog \
            --override \
            --no_annot --no_file_comments \
            2>/dev/null || \
        emapper.py \
            -i ${OUT_DIR}/prokka/all_MAGs.faa \
            -o all_MAGs_eggnog \
            --output_dir ${OUT_DIR}/eggnog \
            --cpu ${THREADS} \
            2>${OUT_DIR}/eggnog/eggnog.log
```
**eggNOG-mapper** annotates each predicted protein with orthology-based functional
information — KEGG orthologs (KO), COG functional categories, and GO terms — by mapping
against the eggNOG database of orthologous groups. The first invocation attempts a faster
mode (`--no_annot --no_file_comments`, skipping some annotation steps and comment lines
for speed); if that particular option combination fails (e.g. due to a version mismatch),
the `||` fallback re-runs with the simpler default settings instead.

```bash
        if [ -f "${OUT_DIR}/eggnog/all_MAGs_eggnog.emapper.annotations" ]; then
            awk -F'\t' 'NR>4 && $5!=""{n++} END{print "  "n" genes with KEGG KO"}' \
                ${OUT_DIR}/eggnog/all_MAGs_eggnog.emapper.annotations
            awk -F'\t' 'NR>4 && $7!=""{n++} END{print "  "n" genes with COG category"}' \
                ${OUT_DIR}/eggnog/all_MAGs_eggnog.emapper.annotations
        fi
```
The eggNOG-mapper output table has a multi-line comment header (`NR>4` skips it), then
counts how many genes received a non-empty KEGG KO (column 5) or COG category (column 7)
assignment — a coverage metric showing what fraction of predicted genes could be
functionally annotated.

---

## Section 3 — HUMAnN3: Community-Level Functional Profiling

```bash
DEMO_READS=$(ls ${DAY3_DIR}/host_removed/gut*_clean_1.fastq.gz 2>/dev/null | head -1)
if [ -z "${DEMO_READS}" ]; then
    DEMO_READS=$(ls ${DAY3_DIR}/trimmed/*_R1_trimmed.fastq.gz 2>/dev/null | head -1)
fi
```
Unlike Prokka/eggNOG (which annotate individual assembled MAGs), **HUMAnN3** profiles
functional pathways directly from raw/QC'd reads for the *whole microbial community*,
including organisms too rare to be assembled into MAGs. It therefore uses the Day 3
cleaned gut reads (host-filtered) rather than MAG protein sequences, with a fallback to
generically trimmed reads if host-filtered ones aren't found.

```bash
if command -v humann &> /dev/null && [ -n "${DEMO_READS}" ]; then
    humann \
        --input ${DEMO_READS} \
        --output ${OUT_DIR}/humann3/${SAMPLE_NAME} \
        --threads ${THREADS} \
        --metaphlan-options "--bowtie2db ${HUMANN_DB}/metaphlan_db" \
        --nucleotide-database ${HUMANN_DB}/chocophlan \
        --protein-database ${HUMANN_DB}/uniref
```
HUMAnN3 internally runs **MetaPhlAn** first (to identify which species are present, via
`--metaphlan-options` pointing at its marker-gene database), then aligns reads against
species-specific pangenomes from the **ChocoPhlAn** nucleotide database, and finally
falls back to **UniRef** protein-level search for reads that don't match any
pangenome — producing gene family and pathway abundance profiles for the whole community.
Note only a single sample's forward reads (`--input ${DEMO_READS}`, not paired) are
processed here as a time-limited course demo — HUMAnN3 is typically run on single-end
or concatenated reads per sample, and a full analysis would loop over all samples.

```bash
    humann_renorm_table \
        --input ${OUT_DIR}/humann3/${SAMPLE_NAME}/*_genefamilies.tsv \
        --output ${OUT_DIR}/humann3/${SAMPLE_NAME}_genefamilies_relab.tsv \
        --units relab
```
Raw HUMAnN3 gene family counts aren't directly comparable across samples of different
sequencing depth; `humann_renorm_table --units relab` converts them to relative
abundance so that gene family abundances sum to a consistent total per sample.

```bash
    grep -v "UNMAPPED\|UNINTEGRATED" \
        ${OUT_DIR}/humann3/${SAMPLE_NAME}/*_pathabundance.tsv 2>/dev/null | \
        sort -k2 -nr | head -10 | \
        awk -F'\t' '{printf "  %s\t%.4f\n", $1, $2}'
```
Filters out the `UNMAPPED`/`UNINTEGRATED` catch-all categories (reads that couldn't be
assigned to any known pathway) from the pathway abundance table, sorts by abundance
(column 2, descending), and prints the top 10 most abundant community pathways (e.g.
MetaCyc pathways) as a quick summary.

```bash
else
    echo "  HUMAnN3 not available or no reads found."
fi
```
Skips gracefully with a clear message if HUMAnN3 isn't installed or no suitable reads
were found — this step has the heaviest database/runtime requirements in the whole
course ("30–60 minutes", per the script's own comment), so this fallback matters in a
live teaching session.

---

## Section 4 — AMR Gene Detection

```bash
if command -v rgi &> /dev/null && [ -f "${OUT_DIR}/prokka/all_MAGs.faa" ]; then
    rgi main \
        -i ${OUT_DIR}/prokka/all_MAGs.faa \
        -o ${OUT_DIR}/amr/rgi_output \
        -t protein \
        --clean \
        --num_threads ${THREADS}
```
**RGI** (Resistance Gene Identifier) screens the combined MAG protein set against the
**CARD** (Comprehensive Antibiotic Resistance Database) to detect antimicrobial resistance
genes. `-t protein` specifies protein-level input (matching the Prokka `.faa` output);
`--clean` removes RGI's intermediate temp files after the run.

```bash
    awk -F'\t' 'NR>1{print $9}' ${OUT_DIR}/amr/rgi_output.txt 2>/dev/null | \
        sort | uniq -c | sort -nr | head -10 | \
        awk '{printf "  Count=%d  Drug class: %s\n", $1, $2}'
```
Tallies detected AMR hits by drug class (column 9 of RGI's output), showing the top 10
most frequent resistance categories found across all annotated MAGs.

```bash
elif command -v amrfinder &> /dev/null && [ -f "${OUT_DIR}/prokka/all_MAGs.faa" ]; then
    amrfinder \
        -p ${OUT_DIR}/prokka/all_MAGs.faa \
        -o ${OUT_DIR}/amr/amrfinder_output.tsv \
        --plus \
        --threads ${THREADS}
```
**AMRFinderPlus** (NCBI's alternative AMR screening tool) is used if RGI isn't
available — `--plus` additionally screens for virulence factors and stress-response
genes beyond core AMR determinants. The two tools are treated as interchangeable
alternatives (`elif`) since either gives a reasonable AMR profile.

```bash
else
    echo "  No AMR tool found. Install one of: RGI, AMRFinderPlus"
fi
```
Final fallback if neither tool is installed.

---

## Key Outputs

| Output | Path |
|---|---|
| Prokka annotations | `${OUT_DIR}/prokka/` |
| eggNOG functional annotation | `${OUT_DIR}/eggnog/` |
| HUMAnN3 community profiles | `${OUT_DIR}/humann3/` |
| AMR gene hits | `${OUT_DIR}/amr/` |

> Continue to `02_functional_plots.Rmd` for visualisation of these results.

## Discussion Questions

*(not included in the original script — consider adding questions on: which functional
categories dominate the community profile, whether any AMR genes of clinical concern were
detected, and how MAG-level annotation compares to community-level HUMAnN3 profiling.)*

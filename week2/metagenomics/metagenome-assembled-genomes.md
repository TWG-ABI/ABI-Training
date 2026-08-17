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

/* Function/command names */
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

# Day 4 Practical: Metagenome-Assembled Genomes (MAGs)

## Purpose

An assembly (Day 3) is a pile of contigs from *all* organisms in a sample, mixed
together. **Binning** groups contigs that likely belong to the same genome based on shared
composition and coverage signal, recovering **Metagenome-Assembled Genomes (MAGs)** —
draft genomes of individual community members, often including organisms that have never
been cultured. This practical covers the full recovery workflow: read mapping for
coverage → binning with two independent tools → bin refinement/deduplication →
completeness/contamination assessment → taxonomic classification.

## Setup

```bash
set -euo pipefail

DAY3_DIR="../day3/day3_results"
OUT_DIR="day4_results"
THREADS=8
ASSEMBLY="${DAY3_DIR}/assembly/soil_SRR6868006/contigs_min1500.fa"
READS_R1="${DAY3_DIR}/host_removed/soil_SRR6868006_clean_1.fastq.gz"
READS_R2="${DAY3_DIR}/host_removed/soil_SRR6868006_clean_2.fastq.gz"
GTDBTK_DATA="${GTDBTK_DATA_PATH:-/path/to/gtdbtk_r214_data}"

mkdir -p ${OUT_DIR}/{mapping,metabat2,maxbin2,das_tool,checkm2,gtdbtk}
```
This continues directly from the Day 3 demo assembly of one soil sample. `GTDBTK_DATA`
falls back to a placeholder path unless the `GTDBTK_DATA_PATH` environment variable is
already set — a reminder that this large reference database needs configuring separately.

```bash
if [ ! -f "${ASSEMBLY}" ]; then
    echo "ERROR: Assembly not found..."
    exit 1
fi
```
Fails immediately with a clear message if Day 3 hasn't been run (or the path needs
adjusting), rather than erroring deep inside the binning steps.

---

## Step 1 — Map reads to assembly (coverage profiles)

```bash
bowtie2-build --threads ${THREADS} ${ASSEMBLY} ${OUT_DIR}/mapping/assembly_idx
```
Binning tools use **coverage depth** as one of their key signals (contigs from the same
genome tend to have similar coverage, since they were sequenced from the same
population). To measure that, reads are first mapped back to their own assembly — so a
Bowtie2 index is built directly from the assembled contigs (not an external reference).

```bash
bowtie2 -x ${OUT_DIR}/mapping/assembly_idx -1 ${READS_R1} -2 ${READS_R2} \
    --threads ${THREADS} \
    2>${OUT_DIR}/mapping/bowtie2_map.log | \
    samtools sort -@ ${THREADS} -o ${OUT_DIR}/mapping/reads_sorted.bam

samtools index ${OUT_DIR}/mapping/reads_sorted.bam
```
Reads are aligned against the assembly and piped directly into `samtools sort` (avoiding
an intermediate unsorted SAM/BAM file on disk), then indexed for fast random access.

```bash
samtools flagstat ${OUT_DIR}/mapping/reads_sorted.bam | grep -E "mapped|total" | head -5
```
A quick sanity check: what fraction of reads mapped back to their own assembly (should be
high — this measures assembly completeness/representativeness, not classification
accuracy).

```bash
jgi_summarize_bam_contig_depths \
    --outputDepth ${OUT_DIR}/mapping/depth.txt \
    ${OUT_DIR}/mapping/reads_sorted.bam
```
This MetaBAT2-associated utility converts the BAM alignment into a per-contig average
coverage depth table — the exact input format MetaBAT2 expects for its binning algorithm.

---

## Step 2 — Binning with MetaBAT2

```bash
metabat2 \
    -i ${ASSEMBLY} \
    -a ${OUT_DIR}/mapping/depth.txt \
    -o ${OUT_DIR}/metabat2/bins/bin \
    --minContig 1500 \
    --numThreads ${THREADS} \
    --saveCls
```
**MetaBAT2** clusters contigs into bins using both tetranucleotide composition (a
genome-specific "signature" independent of coverage) and the coverage depth computed
above. `--minContig 1500` matches the length filter already applied to the assembly;
`--saveCls` retains the contig-to-bin cluster assignments for later use.

```bash
N_BINS=$(ls ${OUT_DIR}/metabat2/bins/bin.*.fa 2>/dev/null | wc -l)
seqkit stats ${OUT_DIR}/metabat2/bins/bin.*.fa | \
    awk 'NR>1{printf "  %s: %s bp, %s sequences\n", $1, $5, $4}'
```
Reports how many bins were produced and each bin's total size/contig count — a first
glance at whether bins are plausible genome-sized fragments (typically 1–10 Mb for
bacteria) rather than tiny fragments or implausibly huge merged bins.

---

## Step 3 — Binning with MaxBin2 (for comparison)

```bash
if command -v run_MaxBin.pl &> /dev/null; then
    awk 'NR>1{print $1"\t"$3}' ${OUT_DIR}/mapping/depth.txt > \
        ${OUT_DIR}/mapping/abundance.txt

    run_MaxBin.pl \
        -contig ${ASSEMBLY} \
        -abund ${OUT_DIR}/mapping/abundance.txt \
        -out ${OUT_DIR}/maxbin2/bins/bin \
        -thread ${THREADS}
```
**MaxBin2** is a second, independently-developed binning algorithm (using marker genes +
coverage/composition in an expectation-maximisation framework). Running two different
binners is standard practice because no single binner is best on all datasets — their
outputs are reconciled in the next step. MaxBin2 needs a simpler two-column
contig/abundance file, extracted here from the same depth table with `awk` (column 1 =
contig ID, column 3 = average depth).

```bash
else
    echo "  MaxBin2 not available — skipping"
fi
```
If MaxBin2 isn't installed, the pipeline degrades gracefully to running DAS_Tool with only
MetaBAT2 bins.

---

## Step 4 — Bin refinement with DAS_Tool

```bash
grep ">" ${OUT_DIR}/metabat2/bins/bin.*.fa | \
    sed 's/.*\/\(bin\.[0-9]*\)\.fa:>/\1\t/' | \
    awk '{print $2"\t"$1}' > ${OUT_DIR}/das_tool/metabat2_s2b.tsv 2>/dev/null || \
    Fasta_to_Contig2Bin.sh -i ${OUT_DIR}/metabat2/bins/ -e fa \
        > ${OUT_DIR}/das_tool/metabat2_s2b.tsv 2>/dev/null
```
DAS_Tool needs a simple "scaffold-to-bin" mapping (which contig belongs to which bin) per
binner, rather than the FASTA bin files themselves. This extracts that mapping from the
MetaBAT2 FASTA headers using `grep`/`sed`/`awk`; if that parsing fails for any reason, it
falls back to DAS_Tool's own official helper script (`Fasta_to_Contig2Bin.sh`), which does
the same job more robustly.

```bash
if [ -d "${OUT_DIR}/maxbin2/bins" ] && ls ${OUT_DIR}/maxbin2/bins/*.fasta &>/dev/null; then
    Fasta_to_Contig2Bin.sh -i ${OUT_DIR}/maxbin2/bins/ -e fasta \
        > ${OUT_DIR}/das_tool/maxbin2_s2b.tsv 2>/dev/null
    BINNER_FILES="${BINNER_FILES},${OUT_DIR}/das_tool/maxbin2_s2b.tsv"
    BINNER_NAMES="${BINNER_NAMES},maxbin2"
fi
```
The same scaffold-to-bin file is generated for MaxBin2 *only if* it actually produced
bins, and appended to the comma-separated lists of files/names that DAS_Tool will
compare.

```bash
DAS_Tool \
    -i ${BINNER_FILES} \
    -l ${BINNER_NAMES} \
    -c ${ASSEMBLY} \
    -o ${OUT_DIR}/das_tool/DAS_output \
    --search_engine diamond \
    --write_bins 1 \
    --write_unbinned 0 \
    --threads ${THREADS}
```
**DAS_Tool** takes bin sets from one or more binners and uses single-copy marker gene
scoring (via DIAMOND search) to select the best-supported, non-redundant set of bins
across all input binners — typically producing fewer but higher-quality bins than any
individual binner alone. `--write_bins 1` outputs the final refined bin FASTA files;
`--write_unbinned 0` skips writing out unbinned contigs (not needed for this course).

```bash
N_DAS=$(ls ${OUT_DIR}/das_tool/DAS_output_DASTool_bins/*.fa 2>/dev/null | wc -l)
echo "  DAS_Tool refined to ${N_DAS} bins"
```
Reports the final refined bin count for comparison against the raw MetaBAT2/MaxBin2
counts.

---

## Step 5 — Quality assessment with CheckM2

```bash
BIN_DIR="${OUT_DIR}/das_tool/DAS_output_DASTool_bins"
if [ ! -d "${BIN_DIR}" ] || [ -z "$(ls ${BIN_DIR}/*.fa 2>/dev/null)" ]; then
    BIN_DIR="${OUT_DIR}/metabat2/bins"
fi
```
Uses the DAS_Tool-refined bins if available; otherwise falls back to the raw MetaBAT2
bins so the workflow can still complete.

```bash
if command -v checkm2 &> /dev/null; then
    checkm2 predict \
        --input ${BIN_DIR} \
        --output-directory ${OUT_DIR}/checkm2 \
        --extension fa \
        --threads ${THREADS}
```
**CheckM2** estimates each bin's **completeness** (% of expected single-copy genes
present) and **contamination** (% suggesting mixed-genome content) using a machine-learning
model trained on genome quality — the standard metrics for judging whether a MAG is
usable.

```bash
        awk -F'\t' 'NR>1{
            if ($2>=90 && $3<5) tier="High Quality"
            else if ($2>=50 && $3<10) tier="Medium Quality"
            else tier="Low Quality"
            printf "  %-30s Comp=%.1f%% Cont=%.1f%% [%s]\n", $1, $2, $3, tier
        }' ${OUT_DIR}/checkm2/quality_report.tsv
```
Classifies each bin into the standard **MIMAG** (Minimum Information about a
Metagenome-Assembled Genome) quality tiers:
- **High quality**: ≥90% complete, <5% contamination
- **Medium quality**: ≥50% complete, <10% contamination
- **Low quality**: everything else

```bash
        awk -F'\t' 'NR>1{
            if ($2>=90 && $3<5) hq++
            else if ($2>=50 && $3<10) mq++
            else lq++
        } END {
            printf "  High quality (≥90%% / <5%%):   %d\n", hq+0
            ...
        }' ${OUT_DIR}/checkm2/quality_report.tsv
```
Tallies how many bins fall into each tier — the headline number reported in most MAG
recovery papers ("we recovered N high-quality MAGs").

```bash
else
    echo "  WARNING: CheckM2 not found. Install: conda install -c bioconda checkm2"
fi
```
Graceful warning if CheckM2 isn't installed.

---

## Step 6 — Taxonomy with GTDB-Tk

```bash
if command -v gtdbtk &> /dev/null && [ -d "${GTDBTK_DATA}" ]; then
    export GTDBTK_DATA_PATH="${GTDBTK_DATA}"

    gtdbtk classify_wf \
        --genome_dir ${BIN_DIR} \
        --out_dir ${OUT_DIR}/gtdbtk \
        --cpus ${THREADS} \
        --extension fa \
        --skip_ani_screen
```
**GTDB-Tk** classifies each MAG taxonomically using the Genome Taxonomy Database
(GTDB) — a genome-based, phylogenetically consistent taxonomy that has largely superseded
NCBI taxonomy for MAG-based studies, since it's designed specifically to handle
uncultured/novel lineages recovered from metagenomes. `--skip_ani_screen` skips an
optional fast pre-screening step, running the full classification workflow directly
(useful for a small number of course MAGs where speed isn't the bottleneck).

```bash
    if [ -f "${OUT_DIR}/gtdbtk/gtdbtk.bac120.summary.tsv" ]; then
        awk -F'\t' 'NR<=11{printf "  %-20s %s\n", $1, $2}' \
            ${OUT_DIR}/gtdbtk/gtdbtk.bac120.summary.tsv
    fi
```
Prints the first 10 bacterial MAG classifications (genome ID + assigned lineage) as a
quick preview of the results table.

```bash
else
    echo "  WARNING: GTDB-Tk not configured"
fi
```
GTDB-Tk requires a large (~100+ GB) reference database — the script warns and skips
cleanly if it isn't set up, rather than failing partway through classification.

---

## Key Outputs

| Output | Path |
|---|---|
| Coverage depth table | `${OUT_DIR}/mapping/depth.txt` |
| MetaBAT2 bins | `${OUT_DIR}/metabat2/bins/` |
| DAS_Tool refined bins | `${OUT_DIR}/das_tool/` |
| CheckM2 quality report | `${OUT_DIR}/checkm2/quality_report.tsv` |
| GTDB-Tk taxonomy | `${OUT_DIR}/gtdbtk/` |

## Discussion Questions

1. How many MAGs did each binner produce? Why do they differ?
2. How many MAGs are high-quality (≥90% complete, <5% contamination)?
3. What phyla are represented by your MAGs?
4. Are any MAGs from novel lineages (GTDB prefix "UBA" or "GCA_")?

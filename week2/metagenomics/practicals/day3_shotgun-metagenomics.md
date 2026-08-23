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

# Day 3 Practical: Shotgun Metagenomics Pipeline

## Purpose

Unlike amplicon sequencing (Day 1), shotgun metagenomics sequences all DNA in a sample,
enabling species-level taxonomic profiling *and* functional/genomic content (assembly,
binning — covered Days 4–5). This practical walks through the standard shotgun workflow:
QC → adapter/quality trimming → host DNA removal → taxonomic classification (two parallel
routes) → de novo assembly and assessment.

## Dataset

All six gut samples from the course's TransplantLines subset (3 LTR + 3 HC) are used
today, each subsampled to 1M read pairs, staged under `data/shotgun/gut_sample/`. Two of
them — `SRR27027652` (LTR) and `SRR27027756` (HC) — also have a full-depth copy under
`data/shotgun/gut_miniproject/`, set aside for homework / the Day 5 mini-project rather
than today's practical. See `data-overview.md` for the full provenance, accessions, and
why this depth was chosen.

There is **no soil sample in Day 3.** Soil tillage data live under
`data/shotgun/soil_miniproject/` for the Day 5 mini-project. Today's assembly demo
(Section 6) runs on a gut sample instead — the point of the demo (what a de Bruijn graph
assembler does, how to read QUAST output) doesn't depend on sample type.

## Setup

Before starting, load the shared course environment (databases are shared — do not
download your own copy). **No git clone is required** — follow this document
(`week2/metagenomics/practicals/day3_shotgun-metagenomics.md`) and write outputs under your home area.

```bash
source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
```

If submitting with SLURM, put that `source` line **inside** the job script after the
`#SBATCH` headers.

```bash
set -euo pipefail

# From course_env.sh (re-stated here for clarity; trailing / required for concat style)
IN_DIR="${GUT_DIR}/"
OUT_DIR="${COURSE_WORK_DIR}/day3_results/"
databases="${COURSE_DBS}/"
kraken_DB="${KRAKEN_DB}"
metaphlan_DB="${METAPHLAN_DB}"
HOST_IDX="${HOST_IDX}"
# Singularity images for Bracken / MetaPhlAn (confirm path on ACE)
IMAGES_DIR="${COURSE_DBS}/images/"
THREADS=8

mkdir -p ${OUT_DIR}{qc,trimmed,host_removed,kraken2,metaphlan,tables,assembly,quast}
```

> **Shotgun layout on ACE.** Class FASTQs: `${GUT_DIR}` (`.../data/shotgun/gut_sample/`).
> Mini-project folders: `${GUT_MINIPROJECT_DIR}`, `${SOIL_MINIPROJECT_DIR}` — do not use those for Day 3.
>
> **Trailing slashes matter** if you concatenate (`${IN_DIR}*_1.fastq.gz`). Prefer
> `"${IN_DIR}"/*_1.fastq.gz` with quotes if you drop the trailing slash.
>
> Confirm `HOST_IDX` and `IMAGES_DIR` with `ls` before class if needed.

**Day 3 modules only** (load these; do not load Day 4/5 stacks yet):

```bash
module load fastqc
module load multiqc
module load fastp
module load bowtie2
module load kraken2
module load megahit
module load quast
module load seqkit
# Bracken + MetaPhlAn4: singularity images under IMAGES_DIR (not modules)
```

> Run `module avail <tool>` if a name differs on ACE.

---

## Section 1 — Quality Control (FastQC + MultiQC)

```bash
fastqc --outdir ${OUT_DIR}qc/ --threads ${THREADS} --quiet ${IN_DIR}*.gz

multiqc ${OUT_DIR}qc/ --filename "metagenomes_multiqc" --quiet -o ${OUT_DIR}qc/
```
FastQC runs once across every FASTQ in `IN_DIR` (all 6 subsampled gut samples, R1 and R2
together) rather than looping sample-by-sample — a single glob is simpler here since
there's no soil subset to keep separate anymore. MultiQC then aggregates all of those
per-file reports into one dashboard, named explicitly (`metagenomes_multiqc`) so it
doesn't collide with other MultiQC runs in the same `OUT_DIR`.

---

## Section 2 — Trimming with fastp

```bash
for file in $(ls ${IN_DIR}*_1.fastq.gz)
do
  sample=$(basename ${file} _1.fastq.gz)
  fastp \
    --in1 ${IN_DIR}${sample}_1.fastq.gz \
    --in2 ${IN_DIR}${sample}_2.fastq.gz \
    --out1 ${OUT_DIR}trimmed/${sample}_trimmed_1.fastq.gz \
    --out2 ${OUT_DIR}trimmed/${sample}_trimmed_2.fastq.gz \
    --qualified_quality_phred 20 \
    --length_required 50 \
    --detect_adapter_for_pe \
    --thread ${THREADS} \
    --json ${OUT_DIR}trimmed/${sample}_fastp.json \
    --html ${OUT_DIR}trimmed/${sample}_fastp.html
done
```
Same fastp parameters as before — Q20 quality filtering, 50 bp minimum length,
auto-detected paired-end adapters. The naming here (`_1.fastq.gz`/`_2.fastq.gz`) matches
what `fastq-dump --split-files` produces directly (see `data-overview.md`), so there's no
rename step between download and this loop.

---

## Section 3 — Host Read Removal

```bash
for R1 in ${OUT_DIR}trimmed/*_trimmed_1.fastq.gz; do
    SAMPLE=$(basename ${R1} _trimmed_1.fastq.gz)
    R2="${OUT_DIR}trimmed/${SAMPLE}_trimmed_2.fastq.gz"

    echo "  bowtie2 host filter: ${SAMPLE}"

    bowtie2 \
        -x ${HOST_IDX} \
        -1 ${R1} \
        -2 ${R2} \
        --un-conc-gz ${OUT_DIR}host_removed/${SAMPLE}_clean_%.fastq.gz \
        --threads ${THREADS} \
        --very-sensitive \
        -S /dev/null \
        2>${OUT_DIR}host_removed/${SAMPLE}_bowtie2.log

    HOST_RATE=$(grep "overall alignment rate" \
        ${OUT_DIR}host_removed/${SAMPLE}_bowtie2.log | awk '{print $1}')
    echo "    Host alignment rate: ${SAMPLE}: ${HOST_RATE}"
done
```
All six samples are gut, so every one goes through host removal this time (no soil
branch to skip it for). `-S /dev/null` discards the alignment stream directly instead of
piping through `samtools view` — we only need `--un-conc-gz`'s output (the reads that
*didn't* map to the human genome), not the alignments themselves. The per-sample host
alignment rate printed here is worth comparing across the 6 samples as a QC check: a
sample with an unusually high or low % human DNA relative to the others is worth a second
look before trusting its downstream taxonomy.

---

## Section 4 — Taxonomic Classification, Route A: Kraken2 + Bracken

The course teaching path — fast k-mer classification, in wide use, good for building
intuition about LCA assignment and database-dependent classification rates.

```bash
for R1 in ${OUT_DIR}host_removed/*_clean_1.fastq.gz; do
    SAMPLE=$(basename ${R1} _clean_1.fastq.gz)
    R2="${OUT_DIR}host_removed/${SAMPLE}_clean_2.fastq.gz"

    kraken2 \
        --db ${kraken_DB} \
        --paired ${R1} ${R2} \
        --threads ${THREADS} \
        --report ${OUT_DIR}kraken2/${SAMPLE}.report \
        --output ${OUT_DIR}kraken2/${SAMPLE}.out \
        --gzip-compressed \
        2>${OUT_DIR}kraken2/${SAMPLE}_kraken2.log
done

for REPORT in ${OUT_DIR}kraken2/*.report
do
    SAMPLE=$(basename ${REPORT} .report)
    singularity exec ${IMAGES_DIR}bracken_3.1.simg bracken \
        -d ${kraken_DB} \
        -i ${REPORT} \
        -o ${OUT_DIR}kraken2/${SAMPLE}_bracken.txt \
        -r 150 \
        -l S
done
```
Kraken2 classifies each read pair by k-mer matching against `kraken_DB`, assigning the
lowest common ancestor across matching taxa. Bracken then re-estimates species-level
(`-l S`) abundances from those raw counts using the average read length (`-r 150`) — it
runs from a Singularity image here rather than a module, so each call is wrapped in
`singularity exec ${IMAGES_DIR}bracken_3.1.simg bracken ...` instead of calling `bracken`
directly.

### Merging and analysing the Bracken output

Combine every sample's Bracken table into one species-by-sample matrix, then run the R
diversity/differential-abundance analysis — both reuse the scripts already built for this
in the main course repo (`metagenomics_course_kampala/practicals/day3/`):

```bash
bash /path/to/metagenomics_course_kampala/practicals/day3/03_merge_abundance_tables.sh \
  ${OUT_DIR}kraken2 \
  ${OUT_DIR}tables/bracken_species_counts.tsv

Rscript /path/to/metagenomics_course_kampala/practicals/day3/04_abundance_analysis.R \
  ${OUT_DIR}tables/bracken_species_counts.tsv \
  ${SHOTGUN_DIR:-/etc/ace-data/ABI-SummerSchool-26/metagenomics/data/shotgun}/gut_metadata.tsv \
  ${OUT_DIR}analysis_bracken
```
`03_merge_abundance_tables.sh` joins all `*_bracken.txt` files on taxon name into one
wide table (`combine_bracken_outputs.py` if available, a Python fallback otherwise).
`04_abundance_analysis.R` then computes Shannon diversity, an Aitchison-distance PCA, and
a simple CLR-based differential abundance comparison between the LTR and HC groups —
replace `/path/to/` with wherever the kampala course repo is checked out on this cluster.

---

## Section 5 — Taxonomic Classification, Route B: MetaPhlAn4 (paper-style)

The TransplantLines paper this gut dataset comes from (Zhang et al. 2024, *mSystems*,
doi:10.1128/msystems.01312-23) profiled species abundance with MetaPhlAn rather than
Kraken2/Bracken. Running both routes on the same samples lets participants compare a
marker-gene profiler against a k-mer classifier on identical input.

MetaPhlAn's database is large and slow to build — it's pre-staged at `metaphlan_DB` as a
one-time course-prep step, not something participants install:

```bash
# Course prep only — do not run this during the practical
mkdir -p ${metaphlan_DB}
singularity exec ${IMAGES_DIR}metaphlan_4.2.6.simg \
  metaphlan --install \
    --db_dir ${metaphlan_DB} \
    -x mpa_vJun23_CHOCOPhlAnSGB_202403
```

The actual per-sample profiling participants run:

```bash
INDEX="mpa_vJun23_CHOCOPhlAnSGB_202403"
PROFILE_LIST="${OUT_DIR}metaphlan/profile_list.txt"
: > ${PROFILE_LIST}

for R1 in ${OUT_DIR}host_removed/*_clean_1.fastq.gz; do
    SAMPLE=$(basename ${R1} _clean_1.fastq.gz)
    R2="${OUT_DIR}host_removed/${SAMPLE}_clean_2.fastq.gz"

    echo "  MetaPhlAn: ${SAMPLE}"

    singularity exec \
      -B ${OUT_DIR}:${OUT_DIR} \
      -B ${metaphlan_DB}:${metaphlan_DB} \
      ${IMAGES_DIR}metaphlan_4.2.6.simg \
      metaphlan \
        "${R1},${R2}" \
        --input_type fastq \
        --nproc ${THREADS} \
        --db_dir ${metaphlan_DB} \
        -x ${INDEX} \
        --mapout ${OUT_DIR}metaphlan/${SAMPLE}.bowtie2.bz2 \
        -o ${OUT_DIR}metaphlan/${SAMPLE}_profile.txt

    echo -e "${SAMPLE}\t${OUT_DIR}metaphlan/${SAMPLE}_profile.txt" >> ${PROFILE_LIST}
done
```
Each Singularity call binds `OUT_DIR` and `metaphlan_DB` explicitly with `-B` — inside the
container's isolated filesystem, paths outside those two binds aren't visible, so both
need to be mounted for MetaPhlAn to read the cleaned reads and write its output.
`--mapout` saves the raw Bowtie2 mapping (useful for troubleshooting/reruns); `-o` writes
the human-readable species profile.

```bash
singularity exec \
  -B ${OUT_DIR}:${OUT_DIR} \
  ${IMAGES_DIR}metaphlan_4.2.6.simg \
  merge_metaphlan_tables.py \
    ${OUT_DIR}metaphlan/*_profile.txt \
    > ${OUT_DIR}tables/metaphlan_merged_all_levels.tsv

# Species-only relative abundances (for R / paper-like analyses)
awk -F'\t' 'NR==1 || $1 ~ /s__/' \
    ${OUT_DIR}tables/metaphlan_merged_all_levels.tsv \
    > ${OUT_DIR}tables/metaphlan_species_relab.tsv
```
`merge_metaphlan_tables.py` (bundled in the MetaPhlAn image) joins all six per-sample
profiles into one table across every taxonomic level; the `awk` filter keeps only rows
whose clade name includes `s__` (MetaPhlAn's species-level marker), giving a clean
species × sample relative-abundance matrix directly comparable to the Bracken one from
Section 4 — same 6 samples, two independent profiling methods.

> Optional, not run today: HUMAnN3 pathway profiling on the cleaned reads (paper-style
> functional analysis) is covered in Day 5 (`day5_functional-analysis.md`).

---

## Section 6 — De Novo Assembly with MEGAHIT + QUAST

```bash
DEMO_SAMPLE=$(ls ${OUT_DIR}host_removed/*_clean_1.fastq.gz 2>/dev/null | head -1)
SAMPLE_NAME=$(basename ${DEMO_SAMPLE} _clean_1.fastq.gz)
R2="${OUT_DIR}host_removed/${SAMPLE_NAME}_clean_2.fastq.gz"

megahit \
    -1 ${DEMO_SAMPLE} \
    -2 ${R2} \
    -o ${OUT_DIR}assembly/${SAMPLE_NAME} \
    --threads ${THREADS} \
    --min-contig-len 1000 \
    --memory 0.5
```
Assembly is computationally expensive, so — for course time — only one sample is
assembled as a worked demonstration: whichever gut sample sorts first alphabetically
among the host-removed files. (Previously this demo ran on a soil sample specifically to
avoid re-using gut reads that had just been through host filtering; with no soil sample
in the course anymore, a gut sample works fine for the same teaching purpose — the point
is de Bruijn graph mechanics and reading QUAST output, not the sample's biology.) Note
this sample is subsampled to 1M read pairs, same as everything else today — don't expect
a highly complete assembly at this depth; that's itself worth discussing (see Discussion
Questions).

```bash
seqkit stats --all ${OUT_DIR}assembly/${SAMPLE_NAME}/final.contigs.fa | column -t

seqkit seq --min-len 1500 \
    ${OUT_DIR}assembly/${SAMPLE_NAME}/final.contigs.fa \
    > ${OUT_DIR}assembly/${SAMPLE_NAME}/contigs_min1500.fa

quast.py \
    ${OUT_DIR}assembly/${SAMPLE_NAME}/contigs_min1500.fa \
    --output-dir ${OUT_DIR}quast/${SAMPLE_NAME} \
    --threads ${THREADS} \
    --no-check-install
```
Same filtering/QC logic as before: a ≥1500 bp filter prepares contigs for Day 4 binning,
and QUAST reports N50 (higher is better), L50 (lower is better), and total assembled
length against the community's expected size.

---

## Key Outputs

| Output | Path |
|---|---|
| MultiQC (raw QC) | `${OUT_DIR}qc/multiqc_report.html` |
| Cleaned (host-filtered) reads | `${OUT_DIR}host_removed/` |
| Kraken2/Bracken classifications | `${OUT_DIR}kraken2/`, merged table in `${OUT_DIR}tables/bracken_species_counts.tsv` |
| MetaPhlAn4 profiles | `${OUT_DIR}metaphlan/`, merged table in `${OUT_DIR}tables/metaphlan_species_relab.tsv` |
| Assembly (demo sample) | `${OUT_DIR}assembly/` |
| QUAST report | `${OUT_DIR}quast/` |

## Discussion Questions

1. What % of each sample's reads were human DNA? Does it vary much across the 6 samples?
2. Do Kraken2/Bracken and MetaPhlAn4 agree on the most abundant species per sample? Where
   do they disagree, and why might a k-mer classifier and a marker-gene profiler give
   different answers on the same reads?
3. Do LTR and HC samples separate on species composition, even by eye, at this depth?
4. What is the N50 of the demo assembly? Given it's built from only 1M read pairs, how
   does that compare to what you'd expect from the two full-depth samples set aside for
   homework (`SRR27027652`, `SRR27027756`) — would you expect a meaningfully better
   assembly from those, and why?

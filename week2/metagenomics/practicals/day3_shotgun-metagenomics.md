<style>
/* Clean, modern, high-contrast code blocks with pretty borders */
div.sourceCode, pre.sourceCode, pre, pre code, div.cell-code pre {
  background-color: #f8f9fa !important;
  color: #212529 !important;
  border: 1px solid #dee2e6 !important;
  border-left: 4px solid #31BAE9 !important;
  border-radius: 6px !important;
}
code span { color: #212529 !important; }
code span.co, code span.c, code span.ch, code span.cm, code span.c1 {
  color: #2e7d32 !important; font-weight: 600 !important; opacity: 1 !important;
}
code span.st, code span.s, code span.s1, code span.s2 { color: #c2410c !important; }
code span.kw { color: #7c3aed !important; font-weight: 600 !important; }
code span.va { color: #0369a1 !important; }
code span.fu { color: #b91c1c !important; }
code span.dv, code span.fl, code span.bn, code span.cn { color: #b45309 !important; }
code span.op { color: #495057 !important; }
code span.er { color: #dc2626 !important; font-weight: 600 !important; }
</style>

---

# Day 3 Practical: Shotgun Metagenomics Pipeline

## Purpose

Unlike amplicon sequencing (Day 1), shotgun metagenomics sequences all DNA in a sample,
enabling species-level taxonomic profiling *and* functional/genomic content (assembly,
binning — covered Days 4–5). This practical walks through the standard shotgun workflow:

**QC → trim → host DNA removal → Kraken2/Bracken → MetaPhlAn → assembly + QUAST**

Runnable code lives under `scripts/` as six SLURM-ready step scripts (preferred over one
monolithic job). Read this document for *why*; submit the matching script for *how*.

| Step | Script | Main outputs under `${COURSE_WORK_DIR}/day3_results/` |
|------|--------|------------------------------------------------------|
| 1 | `scripts/01_raw_qc.sh` | `01_qc/`, `01_qc/multiqc/` |
| 2 | `scripts/02_qc-trim.sh` | `02_trimmed/*_R1_trimmed.fastq.gz` |
| 3 | `scripts/03_host-read_removal.sh` | `03_host_removed/*_clean_{1,2}.fastq.gz` |
| 4 | `scripts/04_kraken2.sh` | `04_kraken2/*.report`, `*_bracken.txt` |
| 5 | `scripts/05_species_abundance.sh` | `05_species_abundance/*_profile.txt` |
| 6 | `scripts/06_assembly.sh` | `06_assembly/`, `06_quast/` |

## Dataset

All six gut samples from the course's TransplantLines subset (3 LTR + 3 HC), each
subsampled to 1M read pairs, under `${GUT_DIR}` (`.../data/shotgun/gut_sample/`). See
`data-overview.md` for provenance. **No soil sample in Day 3.**

## Setup (every session / every `#SBATCH` job)

```bash
source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
cd /path/to/ABI-Training/week2/metagenomics
```

`course_env.sh` sets shared paths only (`GUT_DIR`, `HOST_IDX`, `KRAKEN_DB`,
`METAPHLAN_DB`, `IMAGES_DIR`, `COURSE_WORK_DIR`). It has **no** `#SBATCH` lines.

Each step script sets threads as:

```bash
THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-8}}"
```

Use `THREADS` if you already exported it; else SLURM’s `--cpus-per-task`; else `8`.

Submit from `week2/metagenomics/` so relative log names land next to the scripts:

```bash
sbatch scripts/01_raw_qc.sh
# after 01 finishes:
sbatch scripts/02_qc-trim.sh
# … then 03 → 04 → 05 → 06
```

> Optional one-shot (interactive or inside a large allocation): the older
> `scripts/day3_shotgun.sh` still exists, but the **step scripts above are the
> teaching path** and match the folder layout used in class.

---

## Section 1 — Quality Control (`01_raw_qc.sh`)

**What it does:** runs FastQC on every raw PE pair in `${GUT_DIR}`, then MultiQC.

```bash
sbatch scripts/01_raw_qc.sh
```

Core logic (see the script for full `#SBATCH` headers):

```bash
source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-8}}"
OUT_DIR="${COURSE_WORK_DIR}/day3_results"
mkdir -p "${OUT_DIR}/01_qc"

for R1 in "${GUT_DIR}"/*_1.fastq.gz; do
  SAMPLE=$(basename "${R1}" _1.fastq.gz)
  R2="${GUT_DIR}/${SAMPLE}_2.fastq.gz"
  fastqc --outdir "${OUT_DIR}/01_qc" --threads "${THREADS}" --quiet "${R1}" "${R2}"
done

multiqc "${OUT_DIR}/01_qc/" --outdir "${OUT_DIR}/01_qc/multiqc" --quiet
```

**Why:** catch adapter content, quality drops, and odd GC before spending cluster time
on taxonomy/assembly. Open `01_qc/multiqc/multiqc_report.html`.

---

## Section 2 — Trimming (`02_qc-trim.sh`)

**What it does:** `fastp` adapter detection + quality trimming; writes
`${SAMPLE}_R1_trimmed.fastq.gz` / `_R2_trimmed.fastq.gz`; MultiQC on the JSON/HTML reports.

```bash
sbatch scripts/02_qc-trim.sh
```

```bash
fastp \
  -i "${R1}" -I "${R2}" \
  -o "${OUT_DIR}/02_trimmed/${SAMPLE}_R1_trimmed.fastq.gz" \
  -O "${OUT_DIR}/02_trimmed/${SAMPLE}_R2_trimmed.fastq.gz" \
  --detect_adapter_for_pe \
  -M 25 -5 -r --correction \
  -w "${THREADS}" \
  -j "${OUT_DIR}/02_trimmed/${SAMPLE}_fastp.json" \
  -h "${OUT_DIR}/02_trimmed/${SAMPLE}_fastp.html"
```

**Why:** remove adapters and low-quality bases so k-mers and contigs reflect biology.
Expect most discarded reads under “too short” after adapter clip — that is normal.

Naming note: trimmed files use `_R1_trimmed` / `_R2_trimmed`. Host-removed files later
use Bowtie2’s `--un-conc-gz` pattern (`_clean_1` / `_clean_2`).

---

## Section 3 — Host removal (`03_host-read_removal.sh`)

**What it does:** map trimmed pairs to GRCh38 (`${HOST_IDX}`); keep non-host pairs;
optionally write a host BAM; summarise alignment rates.

```bash
sbatch scripts/03_host-read_removal.sh
```

```bash
bowtie2 \
  -x "${HOST_IDX}" \
  -1 "${R1}" -2 "${R2}" \
  --un-conc-gz "${OUT_DIR}/03_host_removed/${SAMPLE}_clean_%.fastq.gz" \
  --threads "${THREADS}" \
  --very-sensitive \
  2>"${OUT_DIR}/03_host_removed/${SAMPLE}_bowtie2.log" \
  | samtools sort -@ "${THREADS}" -o "${OUT_DIR}/03_host_removed/${SAMPLE}_host.bam" -
```

`--un-conc-gz` writes the **unmapped** concordant pairs (microbiome reads). The BAM is
optional for Day 3 taxonomy; the clean FASTQs are required for steps 4–6.

```bash
grep "overall alignment rate" "${OUT_DIR}/03_host_removed/"*_bowtie2.log \
  > "${OUT_DIR}/03_host_removed/sample-specific_host.txt"
```

**Why:** fecal libraries can contain human DNA. Even if host % is low (~1% or less),
filtering documents that residual human signal is negligible before Kraken/MetaPhlAn.

---

## Section 4 — Kraken2 + Bracken (`04_kraken2.sh`)

**What it does:** k-mer classification of cleaned pairs against `${KRAKEN_DB}`; optional
Bracken species re-estimation (`-r 150 -l S`).

```bash
sbatch scripts/04_kraken2.sh
```

```bash
kraken2 \
  --db "${KRAKEN_DB}" \
  --paired "${R1}" "${R2}" \
  --threads "${THREADS}" \
  --report "${OUT_DIR}/04_kraken2/${SAMPLE}.report" \
  --output "${OUT_DIR}/04_kraken2/${SAMPLE}.out" \
  --gzip-compressed \
  2>"${OUT_DIR}/04_kraken2/${SAMPLE}_kraken2.log"
```

Bracken runs from `${IMAGES_DIR}/bracken_3.1.simg` when present (else a `bracken` module).

**Why:** fast, widely used LCA classifier — good intuition for database-dependent
classification rates. Unclassified reads are normal for gut metagenomes.

---

## Section 5 — MetaPhlAn4 (`05_species_abundance.sh`)

**What it does:** marker-gene species profiling (paper-style route for this dataset), then
merge profiles into all-level and species-only tables.

```bash
sbatch scripts/05_species_abundance.sh
```

```bash
INDEX="mpa_vJun23_CHOCOPhlAnSGB_202403"
SIF="${IMAGES_DIR}/metaphlan_4.2.6.simg"

singularity exec \
  -B "${OUT_DIR}:${OUT_DIR}" \
  -B "${METAPHLAN_DB}:${METAPHLAN_DB}" \
  "${SIF}" \
  metaphlan \
    "${R1},${R2}" \
    --input_type fastq \
    --nproc "${THREADS}" \
    --db_dir "${METAPHLAN_DB}" \
    -x "${INDEX}" \
    --mapout "${OUT_DIR}/05_species_abundance/${SAMPLE}.bowtie2.bz2" \
    -o "${OUT_DIR}/05_species_abundance/${SAMPLE}_profile.txt"
```

`-B` bind-mounts are required so the container can see your results directory and the
shared MetaPhlAn database. After all samples:

```bash
merge_metaphlan_tables.py ... > metaphlan_merged_all_levels.tsv
awk -F'\t' 'NR==1 || $1 ~ /s__/' ... > metaphlan_species_relab.tsv
```

**Why:** the TransplantLines gut paper used MetaPhlAn-style profiling. Comparing Kraken
(k-mers) vs MetaPhlAn (markers) on the same cleaned reads is a core learning goal.
HUMAnN3 pathways are Day 5 (`day5_functional-analysis.md`).

---

## Section 6 — Assembly + QUAST (`06_assembly.sh`)

**What it does:** MEGAHIT (≥1000 bp), keep contigs ≥1500 bp with seqkit, QUAST QC.

```bash
# all cleaned samples:
sbatch scripts/06_assembly.sh

# or one demo sample only:
DEMO_SAMPLE=SRR27027504 sbatch scripts/06_assembly.sh
```

```bash
megahit \
  -1 "${R1}" -2 "${R2}" \
  -o "${OUT_DIR}/06_assembly/${SAMPLE}" \
  --num-cpu-threads "${THREADS}" \
  --min-contig-len 1000 \
  --memory 0.5

seqkit seq --min-len 1500 \
  "${OUT_DIR}/06_assembly/${SAMPLE}/final.contigs.fa" \
  -o "${OUT_DIR}/06_assembly/${SAMPLE}/contigs_min1500.fa"

quast \
  "${OUT_DIR}/06_assembly/${SAMPLE}/contigs_min1500.fa" \
  -o "${OUT_DIR}/06_quast/${SAMPLE}" \
  -t "${THREADS}"
```

**Why:** introduce de Bruijn assembly and how to read N50 / total length. At 1M pairs,
expect modest contiguity — enough for Day 4 MAG demos, not complete genomes.

Note the last assembled sample ID for Day 4 (`DEMO_SAMPLE=`).

---

## Key Outputs

| Output | Path |
|--------|------|
| Raw MultiQC | `${COURSE_WORK_DIR}/day3_results/01_qc/multiqc/` |
| Trimmed reads | `.../02_trimmed/` |
| Host rates + clean FASTQs | `.../03_host_removed/` |
| Kraken2 / Bracken | `.../04_kraken2/` |
| MetaPhlAn tables | `.../05_species_abundance/` |
| Contigs + QUAST | `.../06_assembly/`, `.../06_quast/` |

## Discussion Questions

1. What % of each sample’s reads mapped to human? Does it vary across the 6 samples?
2. Do Kraken2/Bracken and MetaPhlAn agree on dominant species? Where do they disagree, and why?
3. Do LTR and HC samples separate on species composition at this depth?
4. What is the N50 of your assembly? How would full-depth `gut_miniproject` samples change that?

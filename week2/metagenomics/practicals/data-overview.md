# Gut Metagenome Dataset — Background & Provenance

**This file is informational only.** It explains where the Day 3/Day 5 gut
shotgun samples came from and why they were chosen, so participants
understand the dataset they're working with. It is **not** something
participants run during the course — the FASTQs are already staged on the
training cluster at:

```
/etc/ace-data/ABI-SummerSchool-26/metagenomics/data/shotgun/
├── gut_sample/        # Day 3 class (6 subsampled gut FASTQs) — IN_DIR
├── gut_miniproject/   # full-depth gut homework / mini-project option
├── soil_miniproject/  # Day 5 soil tillage mini-project
├── gut_metadata.tsv
└── soil_metadata.tsv
```

(`gut_sample/` is the `IN_DIR` used throughout `day3_shotgun-metagenomics.md`). The download/
subsampling commands below are a one-time course-prep task, not a
participant exercise.

## Source study

- **BioProject:** [PRJNA1047900](https://www.ncbi.nlm.nih.gov/bioproject/PRJNA1047900)
- **Publication:** TransplantLines gut microbiome study — [doi:10.1128/msystems.01312-23](https://journals.asm.org/doi/10.1128/msystems.01312-23)
- **Design:** fecal shotgun metagenomes from end-stage lung disease (ESLD)
  patients, lung transplant recipients (LTR), and healthy controls (HC); 350
  SRA runs total.
- **Platform:** MGI/DNBSEQ (Million Microbiome of Humans Project), paired-end.
- **Data volume:** ⚠️ very deep — ~15–24 Gbases *per sample* at full depth
  (avg ~19.5 Gbases across all 350 runs). Full runs are far too large for
  everyday course use; the 6 course samples are read-limited at download
  instead of pulling the full accession and subsampling afterward.

> **Group (LTR vs. HC) is public — detailed clinical metadata is not.** The
> individual BioSample page for a run only shows `host`/`isolation
> source`/`collection date`/`geo location`. Group comes instead from the
> project-level SRA Run Table's `Library Name` column, which encodes it as a
> name prefix — `LO_...` for lung transplant recipients (LTR, n=282) and
> `ND_...` for healthy controls (HC, n=68) — matching the paper's abstract
> (282 LTR + 68 HC) exactly. Deeper clinical fields (CLAD stage,
> medications, ESLD sub-status) require a data access request to
> `datarequest.transplantlines@umcg.nl` (allow ~2 weeks).

## This course's subset — 6 samples (3 LTR + 3 HC)

Picked close to each group's median sequencing depth to avoid outliers:

| Group | Run | BioSample | Library Name | Bases (full depth) | Full-depth copy also staged? |
|---|---|---|---|---|---|
| LTR | SRR27027606 | SAMN38598790 | LO_105_1105 | 18.5 Gb | No |
| LTR | SRR27027652 | SAMN38598728 | LO_467_1338 | 18.5 Gb | **Yes — homework/mini-project** |
| LTR | SRR27027722 | SAMN38598828 | LO_245_1248 | 18.5 Gb | No |
| HC  | SRR27027691 | SAMN38598899 | ND_1160_809 | 20.6 Gb | No |
| HC  | SRR27027756 | SAMN38598991 | ND_452_622  | 20.6 Gb | **Yes — homework/mini-project** |
| HC  | SRR27027504 | SAMN38598947 | ND_872_522  | 20.6 Gb | No |

All 6 are subsampled to 1M read pairs for the Day 3/5 practicals. Two of
them — `SRR27027652` (LTR) and `SRR27027756` (HC) — additionally have a
**full-depth (unsubsampled) copy** staged separately, set aside for
homework and the Day 5 mini-project rather than the in-class practical.
Picking one LTR + one HC keeps that homework subset group-balanced too.

### Metadata

```
sample-id     group    age    sex    bmi
SRR27027606   LTR      <NA>   <NA>   <NA>
SRR27027652   LTR      <NA>   <NA>   <NA>
SRR27027722   LTR      <NA>   <NA>   <NA>
SRR27027691   HC       <NA>   <NA>   <NA>
SRR27027756   HC       <NA>   <NA>   <NA>
SRR27027504   HC       <NA>   <NA>   <NA>
```
`group` comes from the `LO_`/`ND_` Library Name prefix (public). Age/sex/BMI
require the data access request above — treat as unavailable until then.

## Subsampled depth: 1M read pairs per sample (all 6)

Each of the 6 course samples is read-limited to **1,000,000 read pairs (2M
reads total)**, same depth across all six for a fair group comparison. Why
this depth:

- **Kraken2/Bracken and MetaPhlAn4** (taxonomic classification, both routes
  taught in Day 3) saturate well below this — dominant gut genera/species
  show stable relative abundance long before 1M pairs.
- **HUMAnN3** (community functional profiling, Day 5) is the real
  bottleneck: much below 1M pairs its pathway output is dominated by
  UNMAPPED/UNINTEGRATED reads and stops being useful to look at; much above
  it, the translated UniRef90 search risks running long even on cluster
  hardware.
- **Uniform depth across samples** matters for the LTR-vs-HC diversity
  comparison — uneven depth would confound it, and it's worth flagging to
  participants as a reason real studies rarefy/normalize before comparing
  diversity across samples.

### Command used to prepare the 6 subsampled FASTQs (course prep only)

```bash
mkdir -p data/shotgun/gut_sample
cd data/shotgun/gut_sample

# NOTE: use fastq-dump here, not fasterq-dump. fasterq-dump has no -X /
# --maxSpotId option at all and always pulls the entire accession (confirmed
# on the sra-tools wiki), which would mean downloading the full 15-24 Gbases
# per sample. fastq-dump supports -X directly against the accession, so it
# only fetches the requested read range instead of the whole run.
# (fastq-dump is single-threaded — no --threads/-e flag, unlike fasterq-dump.)
for acc in SRR27027606 SRR27027652 SRR27027722 SRR27027691 SRR27027756 SRR27027504; do
  fastq-dump --split-files -X 1000000 --outdir . $acc
done
gzip *.fastq
```

This produces `<accession>_1.fastq.gz` / `<accession>_2.fastq.gz` per
sample — the naming `day3_shotgun-metagenomics.md`'s loops already expect
(`${IN_DIR}*_1.fastq.gz`), so no renaming step is needed once these land in
`data/shotgun/gut_sample/` on the cluster.

## Full-depth copies for homework / mini-project: SRR27027652, SRR27027756

Unlike the 6 subsampled copies above, these two are pulled at **full
depth** — no `-X` needed, so `fasterq-dump` (faster, multi-threaded) is the
right tool here rather than `fastq-dump`:

```bash
mkdir -p data/shotgun/gut_miniproject
cd data/shotgun/gut_miniproject

for acc in SRR27027652 SRR27027756; do
  fasterq-dump --split-files --outdir . --threads 8 $acc
done
gzip *.fastq
```

⚠️ At ~18.5–20.6 Gbases each, expect this to take a while and consume real
disk space (tens of GB uncompressed per sample before gzip) — this is a
course-prep step to run with time and storage budgeted for it, not
something to kick off casually. Keep these in `gut_miniproject/` so the
Day 3 practical's globs over `gut_sample/*_1.fastq.gz` don't accidentally
pick them up alongside the subsampled versions.

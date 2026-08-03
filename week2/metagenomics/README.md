# ABI Summer School: Metagenomics Analysis Practicals


## What this is

This is an annotated set of teaching materials for a 5-day hands-on bioinformatics
course covering the full journey from raw sequencing reads to biological/functional
interpretation, across both **amplicon (16S)** and **shotgun metagenomics** approaches.
Each Markdown doc explains *what* each command does and *why* it's there, parameters, rationale, and
expected outputs.

## Contents

| Day | File | Covers |
|---|---|---|
| 1 | `qc.md` | Raw read QC: SeqKit stats, FastQC, MultiQC, length/GC filtering |
| 1 | `qiime2-amplicon.md` | QIIME2 amplicon workflow: import → DADA2 denoising → tree → SILVA taxonomy → export |
| 2 | `diversity-analysis.md` | R/phyloseq: alpha & beta diversity, PCoA/NMDS, PERMANOVA, taxonomy plots, ANCOM-BC |
| 3 | `shortgun-metagenomics.md` | Shotgun QC/trimming, human host removal, Kraken2/Bracken classification, MEGAHIT assembly, QUAST |
| 4 | `metagenome-assembled-genomes.md` | Read mapping/coverage, MetaBAT2 & MaxBin2 binning, DAS_Tool refinement, CheckM2, GTDB-Tk taxonomy |
| 5 | `functional-analysis.md` | Prokka annotation, eggNOG-mapper, HUMAnN3 community pathways, AMR gene screening |
| 5 | `functional-analysis-visualisation.md` | Visualising Day 4/5 outputs (MAG quality, COG categories, pathway heatmaps, AMR) + mini-project template |

## How the week is structured

1. **Day 1** — Amplicon sequencing: raw QC → QIIME2 ASV pipeline → taxonomy.
2. **Day 2** — Diversity analysis in R on the Day 1 outputs.
3. **Day 3** — Shotgun metagenomics: QC → host removal → taxonomic classification → assembly.
4. **Day 4** — Recovering draft genomes (MAGs) from the Day 3 assembly via binning.
5. **Day 5** — Functional annotation of MAGs and communities, then visualisation and a
   mini-project template for participants to apply the full workflow to their own data.

Each day generally builds on the previous day's output directory (e.g. Day 4 reads from
`day3_results/`, Day 5 from `day4_results/`), so they're meant to be worked through in
order.

## Environments

Two conda environments are used across the week:
- `qiime2` — Day 1 amplicon pipeline
- `metagenomics` — Days 1 (QC), 3, 4, 5

## Discussion questions

Every practical ends with a short set of discussion questions to check understanding of
the biological interpretation, not just the commands run (Day 5 Part 1 is the one
exception — no questions were included in the original script).

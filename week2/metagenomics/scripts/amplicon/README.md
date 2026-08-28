# 16S rRNA Amplicon Analysis Pipeline

QIIME2-based workflow for processing 16S rRNA amplicon sequencing data — from raw
reads through taxonomic classification, with downstream diversity analysis in R.
Scripts are written as SLURM batch jobs and run QIIME2 via an Apptainer/Singularity
container.

## Requirements

- SLURM cluster environment
- Modules: `fastqc`, `multiqc`, `qiime2`, `biom-format`
- QIIME2 container (path set as `QIIME_CONTAINER` in each script) — **only needed if
  `module load qiime2` doesn't already put a working `qiime` command on your PATH.**
  If it does, you can drop the `qiime()` apptainer wrapper function entirely and call
  `qiime` directly; the container is a workaround for clusters where the module
  doesn't expose the command properly.
- R packages for downstream analysis: `phyloseq`, `vegan`, `DESeq2`, `ANCOMBC`,
  `ggplot2`, `ggpubr`, `ggrepel`, `dplyr`, `tidyr`, `tidyverse`, `stringr`, `pheatmap`

## SLURM script structure

Each `.sh` script starts with an `#SBATCH` header block that tells the scheduler how
to run the job:

- `--job-name` — label shown in the queue
- `--output` / `--error` — where stdout/stderr are written (see **logs directory** below)
- `--time` — walltime limit, formatted `HH:MM:SS`
- `--nodes` / `--ntasks` / `--cpus-per-task` — resource requests; `--cpus-per-task`
  feeds `SLURM_CPUS_PER_TASK`, which the scripts reuse as `THREADS` for QIIME2's
  multi-threaded steps
- `--mem` — memory per node

### Logs directory

`--output=logs/..._%j.out` and `--error=logs/..._%j.err` are relative paths, so a
`logs/` directory must exist in the location you run `sbatch` from (`mkdir -p logs`
before submitting), or the job will fail to start.

### `SHARED_DIR`

`01_qc.sh`, `02_import_data.sh`, and `00_train-nb-classifier.sh` reference
`${SHARED_DIR}` for raw FASTQ files and reference databases (SILVA sequences/taxonomy).
This is a project-level shared storage path, not a SLURM variable — export it in your
shell/job environment (or hardcode it in the scripts) before running, e.g.:
```bash
export SHARED_DIR=/path/to/shared/project/storage
```

## Pipeline order

| Script | Purpose |
|---|---|
| `00_train-nb-classifier.sh` | Extracts target region from SILVA 138 reference and trains the naive Bayes taxonomy classifier (run once; reusable across projects) |
| `01_qc.sh` | FastQC on raw reads + MultiQC summary report |
| `02_import_data.sh` | Builds sample manifest and imports paired-end reads into QIIME2 |
| `03_dada2.sh` | Denoises reads with DADA2 → feature table + representative sequences |
| `04_dada2_stats.sh` | Tabulates DADA2 denoising stats into a visualization |
| `05_taxonomy.sh` | Assigns taxonomy with `classify-sklearn` using the trained classifier |
| `06_taxaplots.sh` | Generates taxa barplot visualization |
| `07_export.sh` | Exports feature table (biom → tsv) and taxonomy for downstream R analysis |
| `08_tree.sh` | Builds a phylogenetic tree (MAFFT + FastTree), needed if using UniFrac distances |

## Downstream diversity analysis (R)

- **`helper-functions.R`** — custom `taxa_level()` function for agglomerating ASVs
  to a given taxonomic rank (used instead of `tax_glom()`). The value it adds over
  `tax_glom()`: base `tax_glom()` merges ASVs at the chosen rank but keeps a single
  representative ASV ID as the taxon name, so downstream plots/heatmaps show
  unreadable ASV IDs unless you separately relabel them. `taxa_level()` instead
  builds the merged abundance table with the actual taxon name (e.g. `Bacteroides`)
  as the row/column identifier, so genus-level (or other rank) outputs are
  human-readable out of the box.
- **`diversity.R`** — builds a phyloseq object from the exported feature table,
  taxonomy, and metadata, then runs:
  - Alpha diversity (Observed, Chao1, Shannon, Simpson) + Kruskal-Wallis tests
  - Beta diversity (Bray-Curtis, PCoA, NMDS, PERMANOVA, betadisper)
  - Phylum-level community composition barplots
  - Genus-level abundance heatmap (top 50 genera)
  - DESeq2 differential abundance (Exacerbation vs Stable)

## Things to check before running end-to-end

- Update `SHARED_DIR`, `QIIME_CONTAINER`, and `CLASSIFIER` paths for your environment.
- DADA2 truncation lengths (`--p-trunc-len-f/r` in `03_dada2.sh`) are dataset-specific.
- Rarefaction/filtering steps in `diversity.R` are currently commented out since we were working with a sub-sampled dataset. Consider uncommenting and using appropriate cut-offs for the filters.

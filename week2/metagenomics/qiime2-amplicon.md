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

# Day 1 Practical — Part 2: QIIME 2 Amplicon Analysis Pipeline

## Purpose

In Part 1, we assessed the quality of the raw sequencing reads using FastQC and MultiQC.

In this practical, we will process the paired-end amplicon sequencing data using **QIIME 2**. The workflow will import the sequencing reads into QIIME 2, denoise them using DADA2 to generate amplicon sequence variants (ASVs), examine the resulting feature table and denoising statistics, assign taxonomy, visualise taxonomic composition, construct a phylogenetic tree, and export the results for downstream analysis.

Unlike a single monolithic pipeline, this workflow is divided into separate scripts. Each major step is submitted independently to the Slurm scheduler. This approach makes it easier to:

* Monitor individual analysis steps.
* Identify where errors occur.
* Inspect intermediate results.
* Adjust parameters without repeating the entire workflow.

The workflow consists of the following steps:

```text
Paired-end FASTQ files
        │
        ▼
1. Import into QIIME 2
        │
        ▼
paired-end-demux.qza
        │
        ▼
2. DADA2 denoising
        │
        ├── Feature table
        ├── Representative sequences
        ├── Denoising statistics
        └── Base transition statistics
        │
        ▼
3. Summarise DADA2 results
        │
        ▼
4. Taxonomic classification
        │
        ▼
5. Taxonomic bar plots
        │
        ▼
6. Phylogenetic tree construction
        │
        ▼
7. Export results for downstream analysis
```

---

# Workflow Directory Structure

The workflow uses the following directory structure:

```text
.
├── data/
│   ├── sample_1.fastq.gz
│   ├── sample_2.fastq.gz
│   └── metadata.tsv
│
├── databases/
│   └── silva-138-99-nb-classifier-2026.7.qza
│
├── results/
│   └── qiime2/
│       ├── paired-end-demux.qza
│       ├── dada2/
│       ├── taxonomy/
│       ├── phylogeny/
│       └── exported/
│
├── import.sh
├── dada2.sh
├── inspect_dada2.sh
├── taxonomy.sh
├── taxaplots.sh
├── tree.sh
└── export.sh
```

The input sequencing files are stored in the `data/` directory, while all QIIME 2 results are organised under:

```text
results/qiime2/
```

---

# Section 1 — Importing Paired-End Reads into QIIME 2

The first step is to import the paired-end FASTQ files into QIIME 2.

Save the import workflow as:

```text
import.sh
```

## Slurm Job Settings

The script begins by requesting computational resources from Slurm.

```bash
#SBATCH --job-name=QiimeImport

#SBATCH --output=job_%j.out

#SBATCH --error=job_%j.err

#SBATCH --time=01:00:00

#SBATCH --nodes=1

#SBATCH --ntasks=4

#SBATCH --mem=8G
```

These settings request:

* One compute node.
* Four tasks.
* 8 GB of memory.
* A maximum runtime of one hour.

The job output and error messages are stored in files containing the Slurm job ID.

---

## Loading QIIME 2

The workflow loads the QIIME 2 module:

```bash
module load qiime2
```

The workflow then defines the QIIME 2 Apptainer container:

```bash
QIIME_CONTAINER="/etc/ace-data/rgc/containers/qiime2/qiime2-2026.7.sif"
```

A Bash function is used to run QIIME 2 commands inside the container:

```bash
qiime() {
    /usr/bin/apptainer exec \
        "${QIIME_CONTAINER}" \
        qiime "$@"
}
```

This allows QIIME 2 commands to be run normally in the script. For example:

```bash
qiime tools import
```

The function automatically executes the command inside the QIIME 2 container.

---

## Defining Input and Output Directories

The workflow defines the locations of the sequencing files and the QIIME 2 output directory.

```bash
DATA_DIR="data"

OUT_DIR="results/qiime2"

MANIFEST="manifest.tsv"
```

The output directory is created if it does not already exist:

```bash
mkdir -p "${OUT_DIR}"
```

---

## Creating the Manifest File

QIIME 2 requires a manifest file to associate each sample ID with its corresponding forward and reverse sequencing files.

The manifest contains three columns:

```text
sample-id
forward-absolute-filepath
reverse-absolute-filepath
```

The workflow automatically creates this file if it does not already exist:

```bash
if [ ! -f "${MANIFEST}" ]; then

    echo -e "sample-id\tforward-absolute-filepath\treverse-absolute-filepath" > "${MANIFEST}"

    for R1 in "${DATA_DIR}"/*_1.fastq.gz; do

        [ -e "${R1}" ] || continue

        SAMPLE=$(basename "${R1}" _1.fastq.gz)

        R2="${DATA_DIR}/${SAMPLE}_2.fastq.gz"

        if [ -f "${R2}" ]; then

            echo -e "${SAMPLE}\t$(realpath "${R1}")\t$(realpath "${R2}")" \
                >> "${MANIFEST}"

        else

            echo "WARNING: Reverse read not found for ${SAMPLE}"

        fi

    done

fi
```

The script identifies all forward reads ending in:

```text
_1.fastq.gz
```

For each forward read, it searches for the corresponding reverse read ending in:

```text
_2.fastq.gz
```

For example:

```text
data/
├── Sample01_1.fastq.gz
├── Sample01_2.fastq.gz
├── Sample02_1.fastq.gz
└── Sample02_2.fastq.gz
```

The resulting manifest will look similar to:

```text
sample-id    forward-absolute-filepath    reverse-absolute-filepath
Sample01     /full/path/data/Sample01_1.fastq.gz    /full/path/data/Sample01_2.fastq.gz
Sample02     /full/path/data/Sample02_1.fastq.gz    /full/path/data/Sample02_2.fastq.gz
```

If a reverse read is missing, the script produces a warning.

---

## Importing the Reads

The paired-end reads are imported using:

```bash
qiime tools import \
    --type 'SampleData[PairedEndSequencesWithQuality]' \
    --input-path "${MANIFEST}" \
    --output-path "${OUT_DIR}/paired-end-demux.qza" \
    --input-format PairedEndFastqManifestPhred33V2
```

QIIME 2 stores the imported sequencing data as:

```text
results/qiime2/paired-end-demux.qza
```

The `.qza` extension represents a QIIME 2 artifact.

This artifact will be used as the input for DADA2 in the next step.

---

## Submitting the Import Job

Submit the script using:

```bash
sbatch import.sh
```

After the job finishes, confirm that the following file has been created:

```text
results/qiime2/paired-end-demux.qza
```

---

# Section 2 — DADA2 Denoising

The next step is to process the imported reads using DADA2.

DADA2 performs several important functions:

* Quality filtering.
* Error modelling.
* Sequence denoising.
* Paired-end read merging.
* Chimera detection and removal.
* Inference of amplicon sequence variants (ASVs).

Save this workflow as:

```text
dada2.sh
```

---

## Computational Resources

The DADA2 workflow requests:

```bash
#SBATCH --job-name=QiimeDADA2

#SBATCH --output=dada2_%j.out

#SBATCH --error=dada2_%j.err

#SBATCH --time=04:00:00

#SBATCH --nodes=1

#SBATCH --ntasks=1

#SBATCH --cpus-per-task=4

#SBATCH --mem=8G
```

DADA2 is allocated four CPUs using:

```bash
#SBATCH --cpus-per-task=4
```

The number of available CPUs is stored automatically by Slurm and accessed through:

```bash
THREADS="${SLURM_CPUS_PER_TASK}"
```

This allows the script to pass the allocated number of CPUs directly to DADA2.

---

## Configuring the Environment

The workflow defines temporary directories for software that requires writable cache locations:

```bash
export MPLCONFIGDIR="/tmp/${USER}-matplotlib"

mkdir -p "${MPLCONFIGDIR}"

export NUMBA_CACHE_DIR="/tmp/${USER}-numba"

mkdir -p "${NUMBA_CACHE_DIR}"
```

These directories are created in temporary storage for the duration of the analysis.

---

## Checking the Input File

The DADA2 workflow requires the imported QIIME 2 artifact:

```text
results/qiime2/paired-end-demux.qza
```

The script checks whether this file exists:

```bash
INPUT="results/qiime2/paired-end-demux.qza"

if [ ! -f "${INPUT}" ]; then

    echo "ERROR: Input file not found: ${INPUT}"

    exit 1

fi
```

If the import step has not completed successfully, the DADA2 job stops immediately.

---

## Running DADA2

The denoising command is:

```bash
qiime dada2 denoise-paired \
    --i-demultiplexed-seqs "${INPUT}" \
    --p-trim-left-f 0 \
    --p-trim-left-r 0 \
    --p-trunc-len-f 280 \
    --p-trunc-len-r 280 \
    --p-n-threads "${THREADS}" \
    --o-table "${OUT_DIR}/table.qza" \
    --o-representative-sequences "${OUT_DIR}/rep-seqs.qza" \
    --o-denoising-stats "${OUT_DIR}/dada2-stats.qza" \
    --o-base-transition-stats "${OUT_DIR}/base-transition-stats.qza" \
    --verbose
```

The forward and reverse reads are truncated at:

```text
Forward reads: 280 bp
Reverse reads: 280 bp
```

The trimming parameters are:

```bash
--p-trim-left-f 0

--p-trim-left-r 0
```

This means that no bases are removed from the beginning of either the forward or reverse reads during this step.

The truncation lengths determine how many bases are retained from each read.

---

## DADA2 Outputs

DADA2 produces four main outputs.

### Feature Table

```text
results/qiime2/dada2/table.qza
```

This contains the abundance of each ASV in each sample.

Conceptually, the table looks like:

| ASV  | Sample 1 | Sample 2 | Sample 3 |
| ---- | -------: | -------: | -------: |
| ASV1 |      120 |       54 |       80 |
| ASV2 |       45 |        0 |       21 |
| ASV3 |       10 |       32 |        7 |

---

### Representative Sequences

```text
results/qiime2/dada2/rep-seqs.qza
```

This contains one representative DNA sequence for each ASV.

These sequences are used for:

* Taxonomic classification.
* Multiple sequence alignment.
* Phylogenetic tree construction.

---

### Denoising Statistics

```text
results/qiime2/dada2/dada2-stats.qza
```

These statistics show how many reads remain after the different stages of DADA2 processing.

The stages include:

* Input reads.
* Filtered reads.
* Denoised reads.
* Merged reads.
* Non-chimeric reads.

---

### Base Transition Statistics

```text
results/qiime2/dada2/base-transition-stats.qza
```

This artifact contains information related to nucleotide transitions observed during the DADA2 error-learning process.

---

## Submitting the DADA2 Job

Run:

```bash
sbatch dada2.sh
```

DADA2 may take longer than the import step because it performs quality filtering, error modelling, denoising, paired-end merging, and chimera removal.

---

# Section 3 — Summarising the DADA2 Results

After DADA2 has completed, the resulting artifacts should be inspected before proceeding.

Save this script as:

```text
inspect_dada2.sh
```

The workflow checks that the following files exist:

```text
results/qiime2/dada2/table.qza

results/qiime2/dada2/rep-seqs.qza

results/qiime2/dada2/dada2-stats.qza

data/metadata.tsv
```

If any required file is missing, the workflow stops with an error.

---

## Summarising the Feature Table

The feature table is summarised using:

```bash
qiime feature-table summarize \
    --i-table "${OUT_DIR}/table.qza" \
    --o-feature-frequencies "${OUT_DIR}/feature-table-summary.qza" \
    --o-sample-frequencies "${OUT_DIR}/sample-table-summary.qza" \
    --o-summary "${OUT_DIR}/overall-table-summary.qzv" \
    --m-metadata-file "${METADATA}"
```

This produces:

```text
feature-table-summary.qza

sample-table-summary.qza

overall-table-summary.qzv
```

The `.qzv` file provides an interactive summary of the feature table.

It can be inspected using the QIIME 2 viewer:

[QIIME 2 View](https://view.qiime2.org)

The summary can be used to examine:

* The number of samples.
* The number of ASVs.
* Sequencing depth across samples.
* Samples with unusually low read counts.
* The distribution of feature frequencies.

---

## Viewing Representative Sequences

Representative sequences are tabulated using:

```bash
qiime feature-table tabulate-seqs \
    --i-data "${OUT_DIR}/rep-seqs.qza" \
    --o-visualization "${OUT_DIR}/rep-seqs.qzv"
```

This produces:

```text
results/qiime2/dada2/rep-seqs.qzv
```

The visualisation allows the ASV sequences to be inspected.

---

## Viewing DADA2 Denoising Statistics

The DADA2 statistics are converted into a visualisation using:

```bash
qiime metadata tabulate \
    --m-input-file "${OUT_DIR}/dada2-stats.qza" \
    --o-visualization "${OUT_DIR}/dada2-stats.qzv"
```

The output is:

```text
results/qiime2/dada2/dada2-stats.qzv
```

This table shows how many reads remain after each DADA2 processing stage.

When examining the results, pay particular attention to:

* The proportion of reads retained after filtering.
* The proportion of reads successfully merged.
* The number of reads remaining after chimera removal.
* Samples with unusually low retention rates.

---

## Submitting the Summary Job

```bash
sbatch inspect_dada2.sh
```

---

# Section 4 — Taxonomic Classification

The representative ASV sequences are assigned taxonomy using a pre-trained SILVA classifier.

Save the workflow as:

```text
taxonomy.sh
```

The relevant variables are:

```bash
IN_DIR="results/qiime2/dada2"

OUT_DIR="results/qiime2/taxonomy"

CLASSIFIER="databases/silva-138-99-nb-classifier-2026.7.qza"

THREADS="${SLURM_CPUS_PER_TASK}"
```

The taxonomy results will be stored in:

```text
results/qiime2/taxonomy/
```

---

## Running the Classifier

Taxonomic classification is performed using:

```bash
qiime feature-classifier classify-sklearn \
    --i-classifier "${CLASSIFIER}" \
    --i-reads "${IN_DIR}/rep-seqs.qza" \
    --p-n-jobs "${THREADS}" \
    --o-classification "${OUT_DIR}/taxonomy.qza" \
    --verbose
```

The classifier compares each representative ASV sequence against the taxonomic information contained in the pre-trained SILVA classifier.

The output is:

```text
results/qiime2/taxonomy/taxonomy.qza
```

Each ASV receives a taxonomic classification and an associated confidence value.

---

## Submitting the Taxonomy Job

```bash
sbatch taxonomy.sh
```

---

# Section 5 — Visualising Taxonomic Composition

After taxonomy has been assigned, taxonomic composition can be visualised using QIIME 2 taxonomic bar plots.

Save the workflow as:

```text
taxaplots.sh
```

The script uses:

```bash
TAX_DIR="results/qiime2/taxonomy"

ASV_DIR="results/qiime2/dada2"

METADATA="data/metadata.tsv"
```

The taxonomic bar plot is generated using:

```bash
qiime taxa barplot \
    --i-table "${ASV_DIR}/table.qza" \
    --i-taxonomy "${TAX_DIR}/taxonomy.qza" \
    --m-metadata-file "${METADATA}" \
    --o-visualization "${TAX_DIR}/taxa-bar-plots.qzv"
```

The output is:

```text
results/qiime2/taxonomy/taxa-bar-plots.qzv
```

The visualisation shows the relative abundance of taxa across samples.

The taxonomic level can be changed interactively in the QIIME 2 viewer to examine composition at different levels, such as:

* Phylum.
* Class.
* Order.
* Family.
* Genus.

---

## Submitting the Taxonomic Bar Plot Job

```bash
sbatch taxaplots.sh
```

---

# Section 6 — Constructing a Phylogenetic Tree

A phylogenetic tree is required for phylogenetically informed diversity analyses.

Save this workflow as:

```text
tree.sh
```

The workflow uses the representative sequences produced by DADA2:

```text
results/qiime2/dada2/rep-seqs.qza
```

The analysis is performed using:

```bash
qiime phylogeny align-to-tree-mafft-fasttree \
    --i-sequences "${IN_DIR}/rep-seqs.qza" \
    --o-alignment "${OUT_DIR}/aligned-rep-seqs.qza" \
    --o-masked-alignment "${OUT_DIR}/masked-aligned-rep-seqs.qza" \
    --o-tree "${OUT_DIR}/unrooted-tree.qza" \
    --o-rooted-tree "${OUT_DIR}/rooted-tree.qza" \
    --p-n-threads "${THREADS}"
```

This workflow performs several steps.

### Multiple Sequence Alignment

The representative ASV sequences are aligned using MAFFT.

Output:

```text
aligned-rep-seqs.qza
```

### Alignment Masking

Highly variable or uninformative alignment positions are masked.

Output:

```text
masked-aligned-rep-seqs.qza
```

### Unrooted Tree

An unrooted phylogenetic tree is constructed.

Output:

```text
unrooted-tree.qza
```

### Rooted Tree

The phylogenetic tree is rooted.

Output:

```text
rooted-tree.qza
```

The rooted tree can be used in downstream analyses involving phylogenetic diversity and phylogenetically informed beta diversity metrics.

---

## Submitting the Tree Construction Job

```bash
sbatch tree.sh
```

---

# Section 7 — Exporting Results for Downstream Analysis

The final step is to export the main QIIME 2 artifacts into formats that can be used for downstream analysis.

Save this workflow as:

```text
export.sh
```

The script also loads the BIOM format tools:

```bash
module load biom-format
```

The workflow uses results from the following directories:

```bash
ASV_DIR="results/qiime2/dada2"

TAX_DIR="results/qiime2/taxonomy"

TREE_DIR="results/qiime2/phylogeny"

OUT_DIR="results/qiime2/exported"
```

The export directory is created using:

```bash
mkdir -p "${OUT_DIR}"
```

---

## Exporting the Feature Table

The QIIME 2 feature table is exported using:

```bash
qiime tools export \
    --input-path "${ASV_DIR}/table.qza" \
    --output-path "${OUT_DIR}"
```

This produces:

```text
feature-table.biom
```

The BIOM file is then converted to TSV format:

```bash
biom convert \
    -i "${OUT_DIR}/feature-table.biom" \
    -o "${OUT_DIR}/feature-table.tsv" \
    --to-tsv
```

The resulting file is:

```text
results/qiime2/exported/feature-table.tsv
```

---

## Exporting the Taxonomy Table

Taxonomy is exported using:

```bash
qiime tools export \
    --input-path "${TAX_DIR}/taxonomy.qza" \
    --output-path "${OUT_DIR}"
```

This exports the taxonomy information into the export directory.

---

## Exporting the Rooted Phylogenetic Tree

The rooted phylogenetic tree is exported using:

```bash
qiime tools export \
    --input-path "${TREE_DIR}/rooted-tree.qza" \
    --output-path "${OUT_DIR}"
```

The exported tree can be used for downstream phylogenetic diversity analysis.

---

## Submitting the Export Job

```bash
sbatch export.sh
```

After the export step, the main results required for downstream analysis are stored in:

```text
results/qiime2/exported/
```

---

# Recommended Order for Running the Workflow

Because the scripts depend on outputs produced by earlier steps, they should be run in the following order:

```bash
sbatch import.sh
```

Wait for the import job to finish successfully, then run:

```bash
sbatch dada2.sh
```

After DADA2 has completed:

```bash
sbatch inspect_dada2.sh
```

Then assign taxonomy:

```bash
sbatch taxonomy.sh
```

Generate taxonomic bar plots:

```bash
sbatch taxaplots.sh
```

Construct the phylogenetic tree:

```bash
sbatch tree.sh
```

Finally, export the results:

```bash
sbatch export.sh
```

---

# Key Outputs

| Analysis step                   | Main output                                      |
| ------------------------------- | ------------------------------------------------ |
| QIIME 2 import                  | `results/qiime2/paired-end-demux.qza`            |
| DADA2 feature table             | `results/qiime2/dada2/table.qza`                 |
| Representative sequences        | `results/qiime2/dada2/rep-seqs.qza`              |
| DADA2 statistics                | `results/qiime2/dada2/dada2-stats.qza`           |
| Feature table summary           | `results/qiime2/dada2/overall-table-summary.qzv` |
| Representative sequence summary | `results/qiime2/dada2/rep-seqs.qzv`              |
| DADA2 statistics visualisation  | `results/qiime2/dada2/dada2-stats.qzv`           |
| Taxonomy assignments            | `results/qiime2/taxonomy/taxonomy.qza`           |
| Taxonomic bar plots             | `results/qiime2/taxonomy/taxa-bar-plots.qzv`     |
| Rooted phylogenetic tree        | `results/qiime2/phylogeny/rooted-tree.qza`       |
| Exported results                | `results/qiime2/exported/`                       |

---

# Discussion Questions

1. How many paired-end sequencing samples were successfully imported into QIIME 2?

2. How many reads were retained after DADA2 filtering and denoising?

3. What proportion of reads were successfully merged?

4. Were there any samples with substantially lower read retention than the others?

5. How many ASVs were identified in the dataset?

6. Why might ASVs provide higher resolution than traditional OTU clustering approaches?

7. Which samples have the lowest sequencing depth after DADA2 processing?

8. What are the dominant taxonomic groups in the dataset?

9. Are there visible differences in taxonomic composition between samples or metadata groups?

10. Why is a phylogenetic tree useful for downstream diversity analysis?

11. Which exported files will be required for the downstream analysis?

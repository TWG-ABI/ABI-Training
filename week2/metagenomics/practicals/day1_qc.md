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

# Day 1 Practical — Part 1: Quality Control with FastQC and MultiQC

## Purpose

Before proceeding to downstream analysis, raw sequencing reads should be assessed to determine their overall quality. Quality control helps identify potential problems such as low-quality bases, unusual GC content, sequence duplication, overrepresented sequences, and possible adapter contamination.

In this practical, we will use two tools:

* **FastQC** — to assess the quality of individual sequencing files.
* **MultiQC** — to combine the results from multiple FastQC reports into a single interactive report.

By the end of this practical, you should be able to:

* Run quality control on multiple compressed FASTQ files.
* Interpret the main sections of a FastQC report.
* Use MultiQC to compare quality across multiple samples.
* Identify whether there are quality issues that may need to be addressed before downstream analysis.

---

## Workflow Overview

The quality control workflow consists of two main steps:

```text
Compressed FASTQ files
        │
        ▼
      FastQC
        │
        ▼
Individual QC reports
        │
        ▼
      MultiQC
        │
        ▼
Combined QC report
```

The workflow is submitted to the high-performance computing cluster using a **Slurm batch script**.

---

# Section 1 — Understanding the Slurm Script

The workflow begins with the following interpreter line:

```bash
#!/bin/bash
```

This tells the system that the script should be executed using the Bash shell.

---

## Slurm Job Settings

The following lines define the computing resources requested from the cluster.

```bash
#SBATCH --job-name=QC

#SBATCH --output=qc_%j.out

#SBATCH --error=qc_%j.err

#SBATCH --time=01:00:00

#SBATCH --nodes=1

#SBATCH --ntasks=4

#SBATCH --mem=8G
```

### Explanation

* `--job-name=QC`
  Assigns the name **QC** to the job.

* `--output=qc_%j.out`
  Stores standard output from the job in a file. `%j` is replaced with the Slurm job ID.

* `--error=qc_%j.err`
  Stores error messages in a separate file.

* `--time=01:00:00`
  Requests a maximum runtime of one hour.

* `--nodes=1`
  Requests one compute node.

* `--ntasks=4`
  Requests four tasks or CPU resources for the job.

* `--mem=8G`
  Requests 8 GB of memory.

These settings may need to be adjusted depending on the size and number of sequencing files being analysed.

---

# Section 2 — Loading the Required Software

Before running the analysis, the required software must be made available in the computing environment.

```bash
module load fastqc

module load multiqc
```

### FastQC

FastQC performs quality assessment of sequencing reads.

It generates a report for each FASTQ file containing information such as:

* Per-base sequence quality.
* Per-sequence quality scores.
* Per-base sequence content.
* GC content.
* Sequence length distribution.
* Sequence duplication levels.
* Overrepresented sequences.
* Adapter content.

### MultiQC

MultiQC collects results from multiple analysis tools and combines them into a single report.

In this workflow, MultiQC collects the FastQC results from all samples and allows us to compare sequencing quality across the entire dataset.

---

# Section 3 — Defining Input and Output Directories

The workflow defines the locations of the input sequencing files and the output directory.

```bash
DATA_DIR="data"

OUT_DIR="results/qc"
```

### Input Directory

```bash
DATA_DIR="data"
```

This directory contains the compressed sequencing files that will be analysed.

For example:

```text
data/
├── sample1_R1.fastq.gz
├── sample1_R2.fastq.gz
├── sample2_R1.fastq.gz
├── sample2_R2.fastq.gz
└── ...
```

The workflow searches for compressed files ending in `.gz`.

### Output Directory

```bash
OUT_DIR="results/qc"
```

All quality control results will be stored in this directory.

Keeping outputs organised in a dedicated results directory helps make the workflow easier to manage and reproduce.

---

# Section 4 — Creating the Output Directory

Before running the analysis, the script ensures that the output directory exists.

```bash
mkdir -p "${OUT_DIR}"
```

The `mkdir` command creates a directory.

The `-p` option means that:

* The directory will be created if it does not already exist.
* Any required parent directories will also be created.
* The command will not produce an error if the directory already exists.

After running this command, the directory structure will look similar to:

```text
results/
└── qc/
```

---

# Section 5 — Running FastQC

The following command runs FastQC on all compressed sequencing files in the input directory.

```bash
fastqc "${DATA_DIR}"/*.gz -o "${OUT_DIR}"
```

### Breaking Down the Command

```bash
"${DATA_DIR}"/*.gz
```

This selects all compressed files ending in `.gz` from the `data` directory.

For example:

```text
data/sample1_R1.fastq.gz
data/sample1_R2.fastq.gz
data/sample2_R1.fastq.gz
data/sample2_R2.fastq.gz
```

FastQC will analyse each file individually.

The option:

```bash
-o "${OUT_DIR}"
```

tells FastQC to store the results in:

```text
results/qc/
```

For each sequencing file, FastQC typically generates:

```text
sample1_R1_fastqc.html
sample1_R1_fastqc.zip
```

The HTML file contains the interactive quality report, while the ZIP file contains the underlying FastQC results.

After FastQC has completed, the output directory may look like:

```text
results/qc/
├── sample1_R1_fastqc.html
├── sample1_R1_fastqc.zip
├── sample1_R2_fastqc.html
├── sample1_R2_fastqc.zip
├── sample2_R1_fastqc.html
├── sample2_R1_fastqc.zip
└── ...
```

---

# Section 6 — Running MultiQC

Once FastQC has analysed all sequencing files, MultiQC is used to combine the results.

```bash
multiqc "${OUT_DIR}"/* -o "${OUT_DIR}"
```

### Breaking Down the Command

```bash
"${OUT_DIR}"/*
```

This instructs MultiQC to scan all files in the quality control output directory.

MultiQC automatically detects compatible output files, including FastQC results.

The option:

```bash
-o "${OUT_DIR}"
```

specifies that the MultiQC report should also be written to the same QC results directory.

The final directory will contain both the individual FastQC reports and the combined MultiQC report.

For example:

```text
results/qc/
├── sample1_R1_fastqc.html
├── sample1_R1_fastqc.zip
├── sample1_R2_fastqc.html
├── sample1_R2_fastqc.zip
├── sample2_R1_fastqc.html
├── sample2_R1_fastqc.zip
├── multiqc_report.html
└── multiqc_data/
```

The main file to inspect is:

```text
results/qc/multiqc_report.html
```

This file can be downloaded or opened in a web browser.

---

# Section 7 — The Complete QC Workflow

The complete analysis section of the script is:

```bash
# Load required software
module load fastqc
module load multiqc

# Define input and output directories
DATA_DIR="data"
OUT_DIR="results/qc"

# Create output directory
mkdir -p "${OUT_DIR}"

# Run FastQC on all compressed sequencing files
fastqc "${DATA_DIR}"/*.gz -o "${OUT_DIR}"

# Combine FastQC reports using MultiQC
multiqc "${OUT_DIR}"/* -o "${OUT_DIR}"
```

The workflow follows this sequence:

1. Load FastQC and MultiQC.
2. Define the location of the sequencing files.
3. Define where the QC results will be stored.
4. Create the output directory.
5. Run FastQC on all compressed sequencing files.
6. Collect the FastQC results using MultiQC.
7. Inspect the combined MultiQC report.

---

# Section 8 — Submitting the QC Job

Save the script, for example, as:

```text
qc.sh
```

The job can then be submitted to the Slurm scheduler using:

```bash
sbatch qc.sh
```

Slurm will return a job ID, for example:

```text
Submitted batch job 123456
```

You can check the status of your job using:

```bash
squeue -u $USER
```

The output and error files will be named according to the job ID:

```text
qc_123456.out
qc_123456.err
```

These files can be inspected if the workflow produces unexpected results or errors.

---

# Section 9 — Interpreting the QC Results

After the job has completed successfully, the main results are found in:

```text
results/qc/
```

The most useful file for comparing all samples is:

```text
results/qc/multiqc_report.html
```

When inspecting the FastQC and MultiQC reports, pay particular attention to the following sections.

### Per-base sequence quality

This shows how sequencing quality changes across the length of the reads.

Look for:

* High-quality scores across most positions.
* A decline in quality towards the end of reads.
* Samples with substantially poorer quality than the rest of the dataset.

### Per-sequence quality scores

This summarises the overall quality distribution of reads within each sample.

A large number of low-quality reads may indicate that filtering or trimming is required.

### Sequence length distribution

This shows the distribution of read lengths.

For paired-end amplicon sequencing, read lengths should generally be consistent with the sequencing run configuration, although the exact interpretation depends on the sequencing platform and library preparation.

### Per-base sequence content

This shows the proportion of A, T, G, and C bases at each position along the reads.

Strong differences between bases, particularly near the beginning of reads, may reflect primer or library preparation effects.

### Per-sequence GC content

This shows the GC content distribution of reads.

Samples with substantially different distributions from the rest of the dataset may require further investigation.

### Adapter content

This identifies sequences matching known sequencing adapters.

High adapter content may indicate that adapter trimming is required.

### Overrepresented sequences

This identifies sequences that occur unusually frequently.

These may represent:

* Primers.
* Adapters.
* Other technical sequences.
* Highly abundant biological sequences.

---

# Key Outputs

| Output                 | Location                         | Description                                         |
| ---------------------- | -------------------------------- | --------------------------------------------------- |
| FastQC HTML reports    | `${OUT_DIR}/*_fastqc.html`       | Individual quality reports for each sequencing file |
| FastQC result archives | `${OUT_DIR}/*_fastqc.zip`        | Detailed FastQC output files                        |
| MultiQC report         | `${OUT_DIR}/multiqc_report.html` | Combined quality report for all samples             |
| MultiQC data           | `${OUT_DIR}/multiqc_data/`       | Data used to generate the MultiQC report            |
| Standard output log    | `qc_<jobID>.out`                 | Messages produced during job execution              |
| Error log              | `qc_<jobID>.err`                 | Error messages generated during job execution       |

---

# Discussion Questions

1. How many sequencing files were analysed?

2. Do all samples show similar sequencing quality profiles?

3. At which positions along the reads does the sequencing quality begin to decline?

4. Are there any samples that show substantially lower quality than the others?

5. Does the sequence length distribution match the expected sequencing read length?

6. Is there evidence of adapter contamination?

7. Are any sequences reported as highly overrepresented?

8. Based on the QC results, would you recommend proceeding directly to the next step, or should trimming and filtering be considered?

9. Why is MultiQC useful when analysing many sequencing samples?

10. How would you identify a potentially problematic sample from the combined MultiQC report?

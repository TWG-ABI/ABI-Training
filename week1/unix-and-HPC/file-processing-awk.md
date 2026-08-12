<p align="center">
  <img src="linux_banner_image.png" alt="ABI Summer School 2026 · WEEK 1: Linux / HPC" width="100%" />
</p>

<style>
/* Clean, modern, high-contrast code blocks with pretty borders */
div.sourceCode, pre.sourceCode, pre, pre code, div.cell-code pre {
  background-color: #f8f9fa !important;
  color: #212529 !important;
  border: 1px solid #dee2e6 !important;
  border-left: 4px solid #31BAE9 !important;
  border-radius: 6px !important;
}
/* Ensure comments and shebangs (#) are crisp, legible, and distinct */
code span.co, code span.c, code span.ch, code span.cm, code span.c1 {
  color: #2e7d32 !important; /* clear readable green */
  font-weight: 600 !important;
  opacity: 1 !important;
}
</style>

---

# File processing: Part 2 (using awk) 

::: {.callout-note}
## Overview & Learning Objectives
**AWK** is a programming language named after its three developers: Alfred Aho, Peter J Weinberger and Brian Kernighan. 

AWK is useful for processing text files and extracting data, particularly when a file is **split into columns** or **delimited by a specific character** (e.g. a tab, comma). The **awk** command reads a file line by line and splits each line into columns according to a delimiter character. The default output delimiter is a single space character.
:::

> **Preparation:** For this tutorial, the working directory will be the `workshop1` directory within `ABI_summer_school_project1`.

---

## Part 1: Starter commands with awk

Use the awk command to print the first column of the `SAMPLE_001.vcf` file:

```bash
awk -F'\t' '{print $1}' SAMPLE_001.vcf
```

Alternatively:

```bash
awk 'BEGIN {FS="\t"} {print $1}' SAMPLE_001.vcf   # Notice the difference in inner vs outer quotation marks
```

In case you want to skip the header row:

```bash
awk 'BEGIN {FS="\t"} NR>1 {print $1}' SAMPLE_001.vcf 
```

In case you want to extract only the header row:

```bash
awk 'NR==1 {print $0}' SAMPLE_001.vcf  
```

---

## Part 2: Removing/Skipping a line with a specific pattern 

For example, extracting all contents of the file `SAMPLE_001.vcf` but skipping the record with **position 1024**: 

```bash
awk -F'\t' '!/1024/ {print $0}' SAMPLE_001.vcf 
```

This is also helpful when skipping multiple header lines:

```bash
awk -F'\t' '!/#/ {print $0}' SAMPLE_001.vcf 
```

---

## Part 3: Extracting more than one column 

Extract the first 5 columns and the 10th column in `SAMPLE_001.vcf` using awk:

```bash
awk 'BEGIN {FS="\t"} {print $1,$2,$3,$4,$5,$10}' SAMPLE_001.vcf
```

::: {.callout-tip}
## Challenge 1: Formatting Output Delimiters
Note that the delimiter in the output is now a single space character (the default for awk). How can we maintain **tab** as the delimiter?
:::
```bash

```

What if we do not want to write `$1,$2,$3,$4,$5` in the print function above, how can we specify this range? 

```bash
awk 'BEGIN {FS=OFS="\t"} {for (i=1; i<=5; i++) printf "%s%s", $i, OFS ; print $10}' SAMPLE_001.vcf
```

::: {.callout-tip}
## Practice: Column Ranges
Extract the first 8 columns in `SAMPLE_001.vcf` using **awk**; be sure to try both approaches above to specify the range of columns 1-8.
:::

**Approach 1:**
```bash

```

**Approach 2:**
```bash

```

---

## Part 4: Data Manipulation & Data Mining

### Converting file delimiter

Convert the delimiter of the file to a comma and save the output as `SAMPLE_001.csv`

```bash

```

### Determining number of columns in a file

Use awk to determine the number of columns in `SAMPLE_001.vcf`  

```bash
awk -F'\t' 'NR==1{print NF}' SAMPLE_001.vcf
```

### Extracting specific rows and columns

Use awk to extract records for participants from YRI in the file `1000G_2504_high_coverage.sequence.index.txt`

**Step 1:** Determine the column number for `POPULATION` using **sed** and/or **grep**
```bash

```

**Step 2:** Use the column number to filter the dataset:
```bash
awk -F'\t' '${col_number}=="YRI"' 1000G_2504_high_coverage.sequence.index.txt
```

::: {.callout-important}
## Detour: Tool Comparison
Compare this `awk` column-filtering approach with how you would accomplish the same task using the **sed** approach!
:::

---

*ABI Summer School 2026 · Module 1: Linux & HPC*

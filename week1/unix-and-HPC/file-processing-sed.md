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

# File processing: Part 1 (using sed)

::: {.callout-note}
**sed** allows us to automate pattern substitutions, deletions, and stream modifications (usually line-by-line). The name **sed** is an abbreviation for **stream editor**.

For this tutorial, navigate inside the `ABI_summer_school_project` directory:
```bash
cd ABI_summer_school_project
```
:::

---

## Core `sed` Concepts & Syntax

| Syntax / Flag | Description / Purpose | Example |
| :--- | :--- | :--- |
| `s/old/new/` | **Substitute First:** Replaces the *first* occurrence of `old` with `new` per line | `sed 's/fasta/fastq/' ...` |
| `s/old/new/g` | **Global Substitution:** Replaces *all* occurrences of `old` with `new` on every line | `sed 's/\t/,/g' ...` |
| `-i` | **In-place Editing:** Directly modifies the file on disk without creating a new file | `sed -i 's/Kampala/Entebbe/g' file.tsv` |
| `-n` | **Quiet / Silent Mode:** Suppresses automatic printing of lines | `sed -n '1p' file.tsv` |
| `p` | **Print Command:** Explicitly prints the specified line(s) (used with `-n`) | `sed -n '/TRUE/p' ...` |
| `d` | **Delete Command:** Deletes lines matching an address or pattern | `sed '/^##/d' file.vcf` |
| `/condition/s/old/new/` | **Conditional Substitution:** Substitutes only on lines matching `/condition/` | `sed '/Kisumu/s/150/100/' ...` |
| `^` | **Line Start Anchor:** Matches the beginning of a line (used to prepend text) | `sed 's/^/prefix\t/' ...` |
| `$` | **Line End Anchor:** Matches the end of a line (used to append text) | `sed 's/$/\tsuffix/' ...` |
| `/START/,/END/p` | **Range / Block Print:** Prints all lines from `/START/` through `/END/` | `sed -n '/SAMPLE_004/,/SAMPLE_008/p' ...` |
| `-e` | **Multiple Expressions:** Chains multiple `sed` operations in a single command | `sed -e 's/A/B/' -e 's/C/D/' ...` |

---

## 1. Replacing Simple Patterns with `sed`

### Basic Substitution (First Occurrence)
Replace the `Plasmodium_falciparum` organism name in each line of `raw_data/sample_manifest.tsv` with `P_falciparum`:

```bash
sed 's/Plasmodium_falciparum/P_falciparum/' raw_data/sample_manifest.tsv
```

To save the output to a new file:

```bash
sed 's/Plasmodium_falciparum/P_falciparum/' raw_data/sample_manifest.tsv > raw_data/sample_manifest_short.tsv
```

To make the replacement directly within the file (use with caution):

```bash
sed -i 's/Plasmodium_falciparum/P_falciparum/' raw_data/sample_manifest_short.tsv
```

---

### Global Substitution (`/g`)

By default, `s/old/new/` replaces **only the first occurrence** of a pattern on each line. To replace **all** occurrences in a line, append the global flag `g` (`s/old/new/g`).

For example, replace all underscores (`_`) in each line of `raw_data/sample_manifest.tsv` with hyphens (`-`):

```bash
sed 's/_/-/g' raw_data/sample_manifest.tsv
```

---

### Removing Unwanted Patterns

With the same substitution syntax, `sed` can **remove** unwanted patterns by substituting them with nothing (`s/pattern//g`).

Remove the `Illumina_` prefix from all platform names in `raw_data/sample_manifest.tsv`:

```bash
sed 's/Illumina_//g' raw_data/sample_manifest.tsv
```

**Exercise: Stripping File Paths & Custom Delimiters**

When patterns contain file paths with forward slashes (`/`), using the standard `s/old/new/` syntax causes confusion because each slash must be escaped (`\/`). To keep commands clean and readable, **sed allows you to use any character as the delimiter** (such as `|`, `#`, or `@`).

Generate a list of sample paths from `raw_data/` and use **sed** with the custom delimiter `|` to strip the `raw_data/` directory prefix:

```bash
# Step 1: Save the FASTQ file paths to a text file
ls raw_data/*.fastq > file_paths.txt

# Step 2: Use alternate delimiter '|' to strip the directory path prefix
sed 's|raw_data/||g' file_paths.txt
```
*(Tip: Using `s|raw_data/||` avoids having to write hard-to-read escaped slashes like `s/raw_data\///`)*.

---

### Replacing Patterns Across Multiple Files Simultaneously

`sed` can batch-edit multiple files at once using wildcards. For example, replace **Kampala** with **Entebbe** in all `.tsv` files in `raw_data/`:

```bash
sed -i 's/Kampala/Entebbe/g' raw_data/*.tsv
```

---

### Changing File Delimiters (TSV to CSV & Space-Delimited)

Convert `raw_data/sample_manifest.tsv` into a comma-separated (`.csv`) file:

```bash
sed 's/\t/,/g' raw_data/sample_manifest.tsv > raw_data/sample_manifest.csv
```

Convert `raw_data/sample_manifest.csv` into a space-delimited file:

```bash
sed 's/,/ /g' raw_data/sample_manifest.csv > raw_data/sample_manifest_space.txt
```

---

## 2. Conditional Substitutions with `sed`

Sometimes, you only want to replace a pattern on lines that meet a specific condition.

As a test case, change the `read_length` for only the **Kisumu** samples in `raw_data/sample_manifest.tsv` from `150` to `100`:

```bash
sed '/Kisumu/s/150/100/' raw_data/sample_manifest.tsv
```

---

## 3. Adding Patterns & Columns Using `sed`

### Chaining Multiple Replacements (`-e`)

Update the model numbers of both `Illumina_NextSeq` and `Illumina_MiSeq` in a single pass so they read `Illumina_NextSeq_2000` and `Illumina_MiSeq_100`:

```bash
sed -e 's/Illumina_NextSeq/Illumina_NextSeq_2000/g' -e 's/Illumina_MiSeq/Illumina_MiSeq_100/g' raw_data/sample_manifest.tsv
```

---

### Appending a New Column at the End of Lines (`$`)

Add an extra column at the end of `raw_data/sample_manifest.tsv` with the header `file_size` and column values all `.`:

```bash
sed '1s/$/\tfile_size/; 2,$s/$/\t./' raw_data/sample_manifest.tsv
```
*(Explanation: `1s/$/\tfile_size/` appends the header to line 1; `2,$s/$/\t./` appends `\t.` to line 2 through the end of the file `$`).*

---

### Prepending a New Column at the Beginning of Lines (`^`)

Add a `project_id` column as the very first column with the header `project_id` and value `Pf_AMR` for all rows:

```bash
sed '1s/^/project_id\t/; 2,$s/^/Pf_AMR\t/' raw_data/sample_manifest.tsv
```

---

## 4. Other Use Cases of `sed` in Data Cleaning

### Obtaining the Header Line of a File

Print only the 1st line of a file using `-n` (quiet mode) and `1p` (print line 1):

```bash
sed -n '1p' raw_data/sample_manifest.tsv
```

---

### Extracting Lines Matching a Specific Pattern

Print only rows that passed quality control (`pass_qc == TRUE`):

```bash
sed -n '/TRUE/p' raw_data/sample_manifest.tsv
```

---

### Counting the Number of Columns in a File

Extract the header line and count the tab-separated fields:

```bash
sed -n '1p' raw_data/sample_manifest.tsv | tr '\t' '\n' | wc -l
```

---

### Removing (Empty) Lines from a File

Remove all empty/blank lines (`/^$/d`) from a text file:

```bash
sed '/^$/d' raw_data/batch1_samples.txt
```

---

### Removing VCF Header Lines (`##`)

Remove all metadata header lines (starting with `##`) from `variants/SAMPLE_001.vcf` and save the clean variant table to `variants/SAMPLE_001_v2.vcf`:

```bash
sed '/^##/d' variants/SAMPLE_001.vcf > variants/SAMPLE_001_v2.vcf
```

---

### Removing Empty Lines AND Header Lines in One Command

Remove empty lines and remove the header line containing `sample_id` simultaneously:

```bash
sed -e '/^$/d' -e '/sample_id/d' raw_data/sample_manifest.tsv
```

---

### Extracting Text Blocks / Line Ranges from a File

Extract sample metadata lines from `SAMPLE_004` through `SAMPLE_008`:

```bash
sed -n '/SAMPLE_004/,/SAMPLE_008/p' raw_data/sample_manifest.tsv
```

```
sed -n '/SAMPLE_004/,/SAMPLE_008/p' sample_manifest3.tsv
```

---

*ABI Summer School 2026 · Week 1: Linux / HPC*



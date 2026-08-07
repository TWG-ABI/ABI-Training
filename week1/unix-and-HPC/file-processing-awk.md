<p align="center">
  <img src="linux_banner_image.png" alt="ABI Summer School 2026 · WEEK 1: Linux / HPC" width="100%" />
</p>

---

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
**AWK** is a programming language named after its three developers: Alfred Aho, Peter J Weinberger and Brian Kernighan. 
AWK is useful for processing text files and extracting data, particularly when a file is **split into columns** or **delimited by a specific character** (e.g. a tab, comma).
The **awk** command/script reads a file line by line and splits each line into columns according to a delimiter character. The default output delimiter is a single space character.

For this tutorial, navigate inside the `ABI_summer_school_project` directory:
```bash
cd ABI_summer_school_project
```
*(Note: To run commands on `SAMPLE_001.vcf`, remember it is located inside the `variants/` subfolder, so you can either `cd variants` or specify `variants/SAMPLE_001.vcf`).*
:::

---

| Syntax / Variable | Description / Purpose | Example |
| :--- | :--- | :--- |
| `-F'\t'` | **Field Separator Flag:** Sets the input column delimiter on the command line | `awk -F'\t' '{print $1}' ...` |
| `$1, $2, ...` | **Field Variables:** References column 1, column 2, etc. | `{print $1, $10}` |
| `$0` | **Whole Record:** References the entire current line | `NR==1 {print $0}` |
| `BEGIN { }` | **Initialization Block:** Code executed *before* reading any file lines | `BEGIN {FS=OFS="\t"}` |
| `FS` | **Field Separator:** Built-in variable defining the input delimiter | `FS="\t"` |
| `OFS` | **Output Field Separator:** Built-in variable defining the output delimiter | `OFS="\t"` or `OFS=","` |
| `NR` | **Number of Records:** Holds the current line number (1, 2, 3...) | `NR > 1` (skips header) |
| `NF` | **Number of Fields:** Holds the total column count of the current line | `NR==1 {print NF}` |
| `!/pattern/` | **Pattern Negation:** Matches lines that do *not* contain the pattern | `!/1024/` or `!/#/` (skips headers) |
| `$1=$1` | **Field Reassignment:** Forces AWK to rebuild `$0` using the new `OFS` | `{$1=$1; print $0}` |
| `$3 == "value"` | **Column Equality:** Filters rows where a specific column matches a value | `$3 == "Kampala"` |
| `\|\|` | **Logical OR:** Combines conditions (e.g. keep header OR matching rows) | `NR==1 \|\| $3=="Kampala"` |
| `printf` | **Formatted Print:** Prints output without adding an automatic newline | `printf "%s%s", $i, OFS` |
| `for (i=...; ...)` | **Loop Construct:** Iterates over a sequence of column indices | `for (i=1; i<=5; i++)` |

---

## Starter commands with awk

Use the awk command to print the first column of the `SAMPLE_001.vcf` file:

```bash
awk -F'\t' '{print $1}' variants/SAMPLE_001.vcf
```

Alternatively:

```bash
awk 'BEGIN {FS="\t"} {print $1}' variants/SAMPLE_001.vcf   # Notice the difference in inner vs outer quotation marks
```

In case you want to skip the header row:

```bash
awk 'BEGIN {FS="\t"} NR>1 {print $1}' variants/SAMPLE_001.vcf 
```

In case you want to extract only the header row:

```bash
awk 'NR==1 {print $0}' raw_data/sample_manifest.tsv  
```

---

### Removing/Skipping a line with a specific pattern 

e.g. extracting all contents of the file `SAMPLE_001.vcf` but skipping the record with **position 1024**: 

```bash
awk -F'\t' '!/1024/ {print $0}' variants/SAMPLE_001.vcf 
```

This is also helpful when skipping multiple header lines (lines starting with `#`):

```bash
awk -F'\t' '!/#/ {print $0}' variants/SAMPLE_001.vcf 
```

---

### Extracting more than one column 

Extract the first 5 columns and the 10th column in `SAMPLE_001.vcf` using awk:

```bash
awk 'BEGIN {FS="\t"} {print $1,$2,$3,$4,$5,$10}' variants/SAMPLE_001.vcf
```

Note that the delimiter in the output is now a single space character (the default for awk). How can we maintain **tab** as the delimiter?

```bash
awk 'BEGIN {FS=OFS="\t"} {print $1,$2,$3,$4,$5,$10}' variants/SAMPLE_001.vcf
```

What if we do not want to write `$1,$2,$3,$4,$5` in the print function above, how can we specify this range? 

```bash
awk 'BEGIN {FS=OFS="\t"} {for (i=1; i<=5; i++) printf "%s%s", $i, OFS ; print $10}' variants/SAMPLE_001.vcf
```

**Practice**: Extract the first 8 columns in `SAMPLE_001.vcf` using **awk**; be sure to try both approaches above to specify the range of columns 1-8. 

**Approach 1 (Listing columns explicitly):**
```bash
awk 'BEGIN {FS=OFS="\t"} {print $1,$2,$3,$4,$5,$6,$7,$8}' variants/SAMPLE_001.vcf
```

**Approach 2 (Looping through range with `for` and `printf`):**
```bash
awk 'BEGIN {FS=OFS="\t"} {for (i=1; i<8; i++) printf "%s%s", $i, OFS ; print $8}' variants/SAMPLE_001.vcf
```

---

### Converting file delimiter

Convert the delimiter of the file to a comma and save the output as `SAMPLE_001.csv`:

```bash
awk 'BEGIN {FS="\t"; OFS=","} {$1=$1; print $0}' variants/SAMPLE_001.vcf > variants/SAMPLE_001.csv
```
*(Tip: Reassigning `$1=$1` tells AWK to rebuild the entire line using the new `OFS` comma delimiter).*

---

### Determining number of columns in a file

Use awk to determine the number of columns in `raw_data/sample_manifest.tsv`:

```bash
awk -F'\t' 'NR==1{print NF}' raw_data/sample_manifest.tsv
```

*(For `SAMPLE_001.vcf`, the main column header is on line 16, so you can check its 10 columns using `awk -F'\t' 'NR==16{print NF}' variants/SAMPLE_001.vcf`).*

---

### Extracting specific rows and columns

Use awk to extract records for samples collected from **Kampala** in the file `raw_data/sample_manifest.tsv`:

**Step 1: Determine the column number for `site` using `head`, `tr`, and `grep`:**

```bash
head -n 1 raw_data/sample_manifest.tsv | tr '\t' '\n' | grep -n "site"
```
*(This shows that `site` is in **column 3**).*

**Step 2: Filter rows where Column 3 is `"Kampala"`:**

```bash
awk -F'\t' '$3=="Kampala"' raw_data/sample_manifest.tsv
```

To include the header row as well:
```bash
awk -F'\t' 'NR==1 || $3=="Kampala"' raw_data/sample_manifest.tsv
```

---

### Detour: Comparing with the `sed` and `grep` approach

Why use AWK instead of `grep` or `sed` for tabular files?

1. **`grep "Kampala"`:** Searches the whole line indiscriminately. If a sample ID or organism name happens to contain "Kampala", it will produce a false match.
2. **`sed`:** Excellent for stream replacements (`s/old/new/g`), but writing logic to check specific columns in `sed` requires complex, hard-to-read regular expressions.
3. **`awk '$3 == "Kampala"'`:** Specifically evaluates **only Column 3**, ensuring exact column matching without accidental matches in other fields.

---

*ABI Summer School 2026 · Week 1: Linux / HPC*



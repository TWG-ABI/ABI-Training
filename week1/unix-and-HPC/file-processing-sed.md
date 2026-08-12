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

**sed** allows us to automate pattern substitutions (usually line-by-line). The name **sed** is an abbreviation of **stream editor**.

Change to the `workshop1` directory within `ABI_summer_school_project1` as it will be your working directory for this tutorial. 

## Replacing simple patterns with sed 

Replace the **fasta** pattern in each line of the file `sample_manifest2.tsv` with **fastq**

```bash
sed 's/fasta/fastq/' sample_manifest2.tsv
```bash

To save the output to a new file:

```bash
sed 's/fasta/fastq/' sample_manifest2.tsv > sample_manifest2_fastq.tsv
```bash

To make the replacement within the primary file (use with caution):

```bash
sed -i 's/fasta/fastq/' sample_manifest2.tsv
```bash

Notice that the **fasta** pattern after **Plasmodium_falciparum_** was not replaced by the previous command. Why is this?

Write the **sed** command(s) to replace both occurrences of **fasta** in each line of `sample_manifest2.tsv` with **fastq**. Save the output to `sample_manifest2_fastq_2.tsv`

```bash

```bash

With the same syntax, sed can be used to **remove** unwanted patterns within each line of a given file. Use **sed** to remove all occurrences of **fastq** in the `sample_manifest2_fastq_2.tsv` file. Save the output to `sample_manifest3.tsv`

```bash

```bash

**Exercise**: Use **sed** to replace the `ftp://ftp.sra.ebi.ac.uk/vol1/run/ERR323/` string in each line of the file named `file_paths.txt`.


**sed** can also be used to replace patterns shared across files simultaneously. As an example, replace **Kampala** with **Entebbe** in all the `.tsv` files currently in `workshop1`

```bash
sed -i 's/Kampala/Entebbe/g' *.tsv
```bash

Using similar syntax for replacing patterns, **sed** can be used to change file delimiters/separators. As a test case, use **sed** to convert `sample_manifest3.tsv` into a `.csv` file named `sample_manifest3.csv`. 

```bash

```bash

Try converting `sample_manifest3.csv` into a **space-delimited** file. 

```bash

```bash

## Conditional substitutions with sed

Sometimes, it's helpful to replace patterns only in lines that meet a certain condition. As a test case, change the read_length for the Kisumu samples in `sample_manifest3.tsv` from 150 to 100.

```bash
sed '/Kisumu/s/150/100/' sample_manifest3.tsv
```bash



## Adding simple patterns to a file using sed

Add the model numbers of the `Illumina_NextSeq` and `Illumina_MiSeq` platforms so that they read `Illumina_NextSeq_2000` and `Illumina_MiSeq_100`, respectively. 

```bash

```bash

Add an extra column (at the end) to the contents of `sample_manifest3.tsv` with the heading `file_size` and the column values all `.` 

```bash

```bash

Add a `project_id` column (make it the first column) to `sample_manifest3.tsv`. Use **Pf_AMR** as the values for each row under this column.

```bash

```bash

## Other use cases of sed in cleaning/pre-processing files

### Obtaining the header line of a file

```bash
sed -n '1p' sample_manifest3.tsv 
```bash

### Extracting line(s) with a specific pattern

```bash
sed -n '/PATTERN/p' file.txt  
```bash

Example:

```bash
sed -n '/TRUE/p' sample_manifest3.tsv 
```bash

### Counting number of columns in a file

```bash

```bash

### Removing (empty) lines from a file

Using `file1.txt` as a testcase, remove all empty lines.

```bash

```bash

Using a similar syntax, **sed** can be used as an alternative to **grep** to remove lines containing certain patterns. Use **sed** to remove the header lines (only the ones starting with *##*) from the `SAMPLE_001.vcf` file. Save the output to a new file `SAMPLE_001_v2.vcf` so that we can reuse the `SAMPLE_001.vcf` file, if needed. 

```bash

```bash

Use sed to remove empty lines from `file1.txt` and the line containing the heading i.e. `sample_id`, in one command. 

```bash

```bash

### Extracting text blocks from a file

Using `sample_manifest3.tsv` as a test case, extract the metadata lines of samples **004** through **008** i.e. from line containing `SAMPLE_004` to the one containing `SAMPLE_008`. 

```bash
sed -n '/SAMPLE_004/,/SAMPLE_008/p' sample_manifest3.tsv
```bash

---

*ABI Summer School 2026 · Week 1: Linux / HPC*



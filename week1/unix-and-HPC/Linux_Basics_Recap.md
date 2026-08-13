<p align="center">
  <img src="linux_banner_image.png" alt="ABI Summer School 2026 · WEEK 1: Linux / HPC" width="100%" />
</p>


# Linux Basics Recap

---

::: {.callout-note}
## SESSION OVERVIEW

Welcome to the Linux Basics Recap for the ABI Summer School 2026. In high-performance computing (HPC) environments, efficiency, precision, and reproducibility are critical when handling massive biological datasets. This hands-on practical session is designed to reinforce fundamental Unix terminal skills and transition your command-line usage from simple file navigation to automated, multi-step bioinformatics workflows.
:::

**Key Learning Objectives**
* **Command Chaining & Execution Control:** Master logical operators (`&&`, `;`) to run sequential commands safely and construct conditional workflows.  
* **File System Architecture & Linking:** Practice efficient directory tree management (`mkdir -p`), relative/absolute navigation, and disk space preservation using symbolic links (`ln -s`).  
* **Bulk String & File Expansion:** Utilize brace expansion (`{}`) and wildcards (`*`) to generate directories, construct numerical log sequences, and perform instant backups without writing shell scripts.  
* **Data Inspection & Interrogation:** Inspect, paginate, and audit raw sequencing read files (FASTQ) and variant calls (VCF) using non-destructive terminal viewers (`head`, `less`, `cat -n`, `cat -T`).  
* **Pattern Searching & Metadata Summarization:** Deploy `grep` with advanced flags (`-v`, `-c`, `-n`, `-r`) alongside column extraction (`cut`), sorting (`sort`), and frequency counting (`uniq -c`).  
* **Relational Pipelines & Batch Processing:** Compare overlapping sample cohorts (`comm`), merge multi-file datasets (`join`, `paste`), and execute bulk file processing via stream piping (`|`) and argument conversion (`find` + `xargs`).  

**Dataset Context**
All exercises operate directly on the `ABI_summer_school_project` archive. This directory simulates an active *Plasmodium falciparum* malaria genomic surveillance project spanning East African field sites. You will work with real bioinformatics file formats—including sample manifests (`.tsv`), raw reads (`.fastq`), variant call files (`.vcf`), reference genomes (`.fasta`), and execution logs (`.log`).

---

## TASK 1: SETUP & NAVIGATION

**Task 1.1:** Download the project ZIP archive from the training repository, extract its contents, and navigate into the newly created directory.
::: {.callout-note collapse="true"}
## Show answer
```bash
wget https://github.com/TWG-ABI/ABI-Training/raw/refs/heads/main/week1/unix-and-HPC/ABI_summer_school_project.zip 
unzip ABI_summer_school_project.zip
cd ABI_summer_school_project
```
> **Why it works:** 
> * `wget` downloads files directly from a URL. 
> * `unzip` extracts the compressed archive. 
> * `cd` (change directory) navigates your terminal into the newly extracted folder.
:::

**Task 1.2:** List all the contents of this project directory and its subdirectories in one command to understand the structure.
::: {.callout-note collapse="true"}
## Show answer
```bash
ls -R
```
> **Why it works:** `ls` lists directory contents. 
> * `-R` (recursive) forces the command to also list all files inside all nested subdirectories, giving a complete tree view.
:::

**Task 1.3:** Navigate into the `raw_data/` directory and confirm your absolute directory path in a single line command.
::: {.callout-note collapse="true"}
## Show answer
```bash
cd raw_data && pwd 
```
> **Why it works:** `cd` changes the directory, and `pwd` (print working directory) outputs your absolute path. 
> * `&&` (AND operator) ensures that `pwd` only runs *if* the `cd` command succeeds, preventing you from executing commands in the wrong place.
:::

**Task 1.4:** Find and list any hidden tracking files in this directory along with their detailed permissions.
::: {.callout-note collapse="true"}
## Show answer
```bash
ls -la
```
> **Why it works:** `ls` lists files. 
> * `-l` (long format) displays detailed information like permissions, ownership, and file size.
> * `-a` (all) reveals hidden files and directories (those starting with a dot, like `.hidden_note.txt`).
:::

---

## TASK 2: DIRECTORY & FILE MANAGEMENT

*(Note: Unless otherwise specified, assume you have navigated back to the project root `ABI_summer_school_project`)*

**Task 2.1:** Create a directory called `qc` within the existing `results` directory.
::: {.callout-note collapse="true"}
## Show answer
```bash
mkdir results/qc
```
> **Why it works:** `mkdir` (make directory) creates a new folder. Because we provide the relative path `results/qc`, it reliably creates the `qc` folder directly inside the existing `results` directory.
:::

**Task 2.2:** From the project root, build four main pipeline directories (fastqc, trimmomatic, bwa, gatk) along with a nested reports/archive folder inside results/ simultaneously using a single command.
::: {.callout-note collapse="true"}
## Show answer
```bash
mkdir -p results/{fastqc,trimmomatic,bwa,gatk,reports/archive}
```
> **Why it works:** `mkdir` creates directories. 
> * `-p` (parents) ensures no error is thrown if `results/` already exists, and it creates parent directories like `reports/` if they are missing.
> * `{...}` (brace expansion) automatically generates multiple arguments, instantly creating all listed directories inside `results/`.
:::

**Task 2.3:** Create 5 files in the `logs` directory called `run_day_1.log` to `run_day_5.log` using brace expansion.
::: {.callout-note collapse="true"}
## Show answer
```bash
touch logs/run_day_{1..5}.log
```
> **Why it works:** `touch` creates empty files or updates their timestamps. 
> * `{1..5}` is a sequence brace expansion that automatically generates numbers 1 through 5, seamlessly creating five sequentially numbered log files in one go.
:::

**Task 2.4:** Create three QC tracker files (`sample_001_qc.txt`, `sample_002_qc.txt`, `sample_003_qc.txt`) in the `results/qc` directory.
::: {.callout-note collapse="true"}
## Show answer
```bash
touch results/qc/sample_001_qc.txt results/qc/sample_002_qc.txt results/qc/sample_003_qc.txt
```
> **Why it works:** `touch` can accept multiple file paths at once. It evaluates each path individually, generating all three text files in the specified `results/qc/` directory simultaneously.
:::

**Task 2.5:** Securely copy the entire `logs` directory and its contents into a new directory called `logs_backup`.
::: {.callout-note collapse="true"}
## Show answer
```bash
cp -r logs/ logs_backup/
```
> **Why it works:** `cp` copies files.
> * `-r` (recursive) is mandatory when copying directories. It guarantees the folder and all of its internal contents are duplicated into `logs_backup/`.
:::

**Task 2.6:** Move into `raw_data/` and create a `.backup` copy of `sample_manifest.tsv` using brace expansion to avoid retyping the filename.
::: {.callout-note collapse="true"}
## Show answer
```bash
cd raw_data
cp sample_manifest.tsv{,.backup}
```
> **Why it works:** `cp` requires a source and a destination.
> * `{,.backup}` is a brace expansion trick. The shell expands this comma-separated list into `cp sample_manifest.tsv sample_manifest.tsv.backup`, saving you from typing the filename twice.
:::

**Task 2.7:** Move the entire `scripts` directory into the `results` directory.
::: {.callout-note collapse="true"}
## Show answer
```bash
mv ../scripts/ ../results/
```
> **Why it works:** `mv` (move) relocates files or directories. `../` tells the terminal to step one directory level up (into the project root) to find `scripts/`, and moves it directly into the `results/` folder.
:::

**Task 2.8:** To conserve cluster storage space, create a symbolic link named `ref_index` inside `results/` pointing to the reference genome.
::: {.callout-note collapse="true"}
## Show answer
```bash
ln -s ../reference/Pfalciparum_3D7.fasta ../results/ref_index
```
> **Why it works:** `ln` creates links between files.
> * `-s` (symbolic) creates a lightweight shortcut instead of a hard link. Programs accessing `results/ref_index` will be seamlessly redirected to the actual FASTA file without consuming duplicate disk space.
:::

**Task 2.9:** Use a wildcard to permanently remove all files ending in `_qc.txt` from the `results/qc/` directory.
::: {.callout-note collapse="true"}
## Show answer
```bash
rm ../results/qc/sample_*_qc.txt
```
> **Why it works:** `rm` removes files. 
> * The `*` (wildcard) acts as a flexible placeholder for any string of characters. This securely deletes `sample_001_qc.txt`, `sample_002_qc.txt`, etc., while ignoring unrelated files.
:::

---

## TASK 3: INSPECTION & VIEWING

*(Navigate back to the project root)*

**Task 3.1:** Concatenate and display the contents of both `sample_manifest.tsv` and `coverage_report.tsv` to the terminal screen simultaneously.
::: {.callout-note collapse="true"}
## Show answer
```bash
cat raw_data/sample_manifest.tsv raw_data/coverage_report.tsv
```
> **Why it works:** `cat` (concatenate) reads files sequentially and prints their contents to the standard output. Supplying multiple filenames stitches them together back-to-back on your screen.
:::

**Task 3.2:** Display the contents of the hidden file `.hidden_note.txt` located in the `raw_data/` directory.
::: {.callout-note collapse="true"}
## Show answer
```bash
cat raw_data/.hidden_note.txt
```
> **Why it works:** Hidden files are just regular files that start with a dot. `cat` easily reads them, displaying their secret contents directly to your terminal.
:::

**Task 3.3:** Print the `README.txt` file to the screen, but prepend line numbers to each line of output.
::: {.callout-note collapse="true"}
## Show answer
```bash
cat -n README.txt
```
> **Why it works:** 
> * `-n` (number) forces `cat` to prefix every line of output with its corresponding line number, which is highly useful for referencing specific rows in a dataset.
:::

**Task 3.4:** Safely peek inside the massive `Pfalciparum_3D7.fasta` reference file using a pager that disables line wrapping for easy reading.
::: {.callout-note collapse="true"}
## Show answer
```bash
less -S reference/Pfalciparum_3D7.fasta
```
> **Why it works:** `less` is a pager that lets you safely scroll through massive files without flooding your terminal.
> * `-S` (chop long lines) disables line wrapping. Instead of text spilling over, it stays on a single horizontal line that you can scroll through using your arrow keys.
:::

**Task 3.5:** Print `sample_manifest.tsv` starting from line 2 to isolate the sample records and exclude the header row.
::: {.callout-note collapse="true"}
## Show answer
```bash
tail -n +2 raw_data/sample_manifest.tsv
```
> **Why it works:** `tail` traditionally outputs the end of a file.
> * `-n +2` tells `tail` to start printing specifically from line 2 all the way to the end, effectively discarding the 1st line (the header).
:::

---

## TASK 4: SORTING & SEARCHING

**Task 4.1:** Sort the `batch1_samples.txt` file in the raw_data directory alphabetically and save the sorted output into a new file called `batch1_sorted.txt` in the archive directory.
::: {.callout-note collapse="true"}
## Show answer
```bash
sort raw_data/batch1_samples.txt > results/reports/archive/batch1_sorted.txt
```
> **Why it works:** `sort` naturally arranges lines alphabetically. 
> * `>` (redirection operator) captures the sorted output that would normally print to your screen and permanently writes it into the `batch1_sorted.txt` file instead.
:::

**Task 4.2:** Sort the sample manifest file specifically based on the values in its 3rd column.
::: {.callout-note collapse="true"}
## Show answer
```bash
sort -k3 raw_data/sample_manifest.tsv
```
> **Why it works:** 
> * `-k3` (key 3) instructs `sort` to evaluate only the 3rd column (which defaults to being separated by whitespace/tabs) when determining the alphabetical order.
:::

**Task 4.3:** Sort the sample manifest based on the 4th column, but in reverse (descending) order.
::: {.callout-note collapse="true"}
## Show answer
```bash
sort -k4 -r raw_data/sample_manifest.tsv
```
> **Why it works:** 
> * `-k4` targets the 4th column for sorting.
> * `-r` (reverse) flips the default ascending order, sorting the column in descending order (e.g., newest dates first or Z-to-A).
:::

**Task 4.4:** Display only the first 5 variant data lines of `SAMPLE_001.vcf`, excluding the VCF header lines (which all start with `#`).
::: {.callout-note collapse="true"}
## Show answer
```bash
grep -v '^#' variants/SAMPLE_001.vcf | head -n 5
```
> **Why it works:** 
> * `grep -v` (invert-match) aggressively filters out lines that contain the pattern.
> * `'^#'` targets lines starting with `#` (`^` signifies the "start of line").
> * `|` (pipe) sends that filtered data stream directly into `head`, which cleanly limits the display to the first 5 variant lines.
:::

**Task 4.5:** Count exactly how many non-header lines (actual variant calls) exist in `SAMPLE_001.vcf`.
::: {.callout-note collapse="true"}
## Show answer
```bash
grep -vc '^#' variants/SAMPLE_001.vcf
```
> **Why it works:** 
> * `-v` filters out the header lines.
> * `-c` (count) suppresses standard output and instead prints only the total number of lines that matched the criteria, instantly telling you the variant count.
:::

**Task 4.6:** Search through the `pipeline.log` file for the word 'WARNING' and prefix the output with the exact line numbers where they occurred.
::: {.callout-note collapse="true"}
## Show answer
```bash
grep -n 'WARNING' logs/pipeline.log
```
> **Why it works:** 
> * `-n` (line number) cleanly prefixes each matched line with its exact line number from the original file, making it easy to locate exactly where the warning occurred in the log.
:::

**Task 4.7:** Search the pipeline log for the word 'failed', ignoring case sensitivity (so it matches 'FAILED', 'Failed', etc.).
::: {.callout-note collapse="true"}
## Show answer
```bash
grep -i 'failed' logs/pipeline.log
```
> **Why it works:** 
> * `-i` (ignore case) ensures the search is case-insensitive, guaranteeing you catch "FAILED", "Failed", and "failed" without having to write multiple search queries.
:::

**Task 4.8:** Count how many sequences are present in the reference FASTA file by counting the number of FASTA header lines (which start with `>`).
::: {.callout-note collapse="true"}
## Show answer
```bash
grep -c '^>' reference/Pfalciparum_3D7.fasta
```
> **Why it works:** In biological FASTA files, every sequence is preceded by a header line starting with `>`. 
> * `^>` strictly targets these header lines, and `-c` tallies them up to give you the total number of chromosomes or contigs in the genome.
:::

**Task 4.9:** Search the entire `logs/` directory for the word 'ERROR', printing the matching line numbers alongside the file names.

(a) First, redirect this output into a new file called `error_summary.log` in the archive directory using standard redirection. Notice that nothing prints to your screen.
::: {.callout-note collapse="true"}
## Show answer
```bash
grep -rn 'ERROR' logs/ > results/reports/archive/error_summary.log
```
> **Why it works:** 
> * `-r` (recursive) comprehensively searches through every file inside the `logs/` directory.
> * `-n` prints line numbers.
> * `>` intercepts the search results and saves them silently into `error_summary.log`.
:::

(b) Now repeat the same search, but this time use `tee` to write to `error_summary_tee.log` while also displaying the matches on screen in real time.
::: {.callout-note collapse="true"}
## Show answer
```bash
grep -rn 'ERROR' logs/ | tee results/reports/archive/error_summary_tee.log
```
> **Why it works:** 
> * `| tee` acts identically to a T-junction in plumbing. It takes the output stream from `grep`, writes it into the specified file, *and* allows it to continue flowing out to your terminal screen for you to see.
:::

**Task 4.10:** Count all the lines across all FASTQ files in the `raw_data/` directory at once.
::: {.callout-note collapse="true"}
## Show answer
```bash
wc -l raw_data/*.fastq
```
> **Why it works:** `wc` (word count) calculates file metrics. 
> * `-l` restricts it to counting only lines.
> * `*.fastq` efficiently feeds every FASTQ file into the command, outputting the line count for each individual file alongside a grand total at the bottom.
:::

**Task 4.11:** Calculate the exact number of sequencing reads in `SAMPLE_001.fastq` by counting total lines.
::: {.callout-note collapse="true"}
## Show answer
```bash
expr $(wc -l < raw_data/SAMPLE_001.fastq) / 4
```
> **Why it works:** Every single sequencing read in a standard FASTQ file consists of exactly 4 lines.
> * `$(...)` executes the inner command first. `wc -l <` feeds the file in and counts lines without printing the filename (which would otherwise break the math).
> * `expr ... / 4` securely evaluates a basic mathematical expression, dividing the total lines by 4 to reveal the true number of biological reads.
:::

---

## TASK 5: BATCH PROCESSING & DATA INTERROGATION

*(Change into the archive directory)*
```bash
cd results/reports/archive
```

**Task 5.1:** Compare the two lists (`batch1_sorted.txt` and `batch2_samples.txt`) and output only the sample IDs that are unique to the second batch.
::: {.callout-note collapse="true"}
## Show answer
```bash
comm -13 batch1_sorted.txt ../../../raw_data/batch2_samples.txt
```
> **Why it works:** `comm` compares two sorted files line by line, generating three columns: unique to file 1, unique to file 2, and shared.
> * `-1` suppresses lines unique to file 1.
> * `-3` suppresses lines shared by both.
> * By eliminating those, only column 2 remains visible, displaying items uniquely found in the second file.
:::

**Task 5.2:** Compare the two lists and output only the sample IDs that are unique to the first batch.
::: {.callout-note collapse="true"}
## Show answer
```bash
comm -23 batch1_sorted.txt ../../../raw_data/batch2_samples.txt
```
> **Why it works:** 
> * `-2` suppresses lines unique to file 2.
> * `-3` suppresses lines shared by both.
> * This outputs only column 1, precisely isolating items exclusively found in the first file.
:::

**Task 5.3:** Extract only the 1st column (Sample ID) from the sample manifest file using `cut`.
::: {.callout-note collapse="true"}
## Show answer
```bash
cut -f1 ../../../raw_data/sample_manifest.tsv
```
> **Why it works:** `cut` extracts sections from lines of files based on delimiters (tabs by default).
> * `-f1` (field 1) strictly targets the first column, cleanly slicing the Sample IDs out of the dataset.
:::

**Task 5.4:** Extract the 3rd column (e.g. Field Site) from the sample manifest file using `cut`.
::: {.callout-note collapse="true"}
## Show answer
```bash
cut -f3 ../../../raw_data/sample_manifest.tsv
```
> **Why it works:** 
> * `-f3` explicitly extracts only the 3rd field, slicing out the Field Sites while ignoring the rest of the file contents.
:::

**Task 5.5:** Extract the 1st and 8th columns simultaneously from the manifest.
::: {.callout-note collapse="true"}
## Show answer
```bash
cut -f1,8 ../../../raw_data/sample_manifest.tsv
```
> **Why it works:** 
> * `-f1,8` utilizes a comma to select discrete, non-contiguous fields, allowing you to instantly extract just the first and eighth columns side-by-side.
:::

**Task 5.6:** Extract a continuous range of columns (1 through 4) from the manifest.
::: {.callout-note collapse="true"}
## Show answer
```bash
cut -f1-4 ../../../raw_data/sample_manifest.tsv
```
> **Why it works:** 
> * `-f1-4` utilizes a hyphen to select a continuous block, extracting columns 1, 2, 3, and 4 collectively without having to type each number.
:::

**Task 5.7:** Extract the Field Site column, sort the extracted sites alphabetically, and generate a frequency table counting how many samples belong to each site.
::: {.callout-note collapse="true"}
## Show answer
```bash
cut -f3 ../../../raw_data/sample_manifest.tsv | sort | uniq -c
```
> **Why it works:** This is a cornerstone bioinformatics aggregation pipeline.
> * `cut` isolates the data column you care about (Field Sites).
> * `sort` groups identical text strings together.
> * `uniq -c` efficiently collapses identical adjacent lines into a single record, prefixing them with an integer counting how many times they originally appeared.
:::

**Task 5.8:** Stitch two text files together side-by-side using a default tab delimiter (Hint: use `paste`).
::: {.callout-note collapse="true"}
## Show answer
```bash
paste batch1_sorted.txt ../../../raw_data/batch2_samples.txt
```
> **Why it works:** `paste` merges files horizontally. It automatically reads line 1 from file A and line 1 from file B, pasting them together horizontally separated by a standard tab character.
:::

**Task 5.9:** Stitch the same two files together, but use a comma (`,`) as the delimiter instead of a tab.
::: {.callout-note collapse="true"}
## Show answer
```bash
paste -d',' batch1_sorted.txt ../../../raw_data/batch2_samples.txt
```
> **Why it works:** 
> * `-d','` (delimiter) changes the default tab separator directly to a comma, allowing you to effortlessly generate CSV-style output on the fly.
:::

**Task 5.10:** Navigate back to the project root. Then search the entire project tree recursively to find all files starting with 'SAMPLE' and ending in '.fastq'.
::: {.callout-note collapse="true"}
## Show answer
```bash
cd ../../../
find . -name 'SAMPLE*.fastq'
```
> **Why it works:** `find` rigorously searches directory hierarchies.
> * `.` tells it to search downwards starting from your current directory.
> * `-name` specifies the search pattern. Single quotes (`'...'`) are crucial because they protect the wildcard `*` from being evaluated prematurely by your shell.
:::

**Task 5.11:** Find all FASTQ files anywhere in the project tree, and pass their names to `wc -l` to calculate a batch line count.
::: {.callout-note collapse="true"}
## Show answer
```bash
find . -name "*.fastq" | xargs wc -l
```
> **Why it works:** 
> * `find` locates the relative paths for all FASTQ files.
> * `xargs` neatly takes that resulting list of filenames and dynamically feeds them as trailing arguments to `wc -l`. This allows you to process thousands of files without hitting shell character limits.
:::

**Task 5.12:** Identify the total disk usage of the project folder and list its immediate subdirectories, sorted by size from largest to smallest.
::: {.callout-note collapse="true"}
## Show answer
```bash
du -h --max-depth=1 . | sort -hr
```
> **Why it works:** 
> * `du -h` (disk usage, human-readable) calculates directory sizes in kilobytes, megabytes, or gigabytes.
> * `--max-depth=1` aggressively prevents it from reporting on every single nested subdirectory.
> * `sort -hr` (human, reverse) intelligently sorts metric sizes (e.g., placing "1G" above "500M"), listing the heaviest directories conveniently at the top.
:::

**Task 5.13:** Isolate samples marked as 'FALSE' for QC in the manifest and save them to a new log file (`failed_qc.log`) located in the archive directory. If successful, securely append a completion timestamp to the bottom without overwriting data.
::: {.callout-note collapse="true"}
## Show answer
```bash
grep 'FALSE' raw_data/sample_manifest.tsv > results/reports/archive/failed_qc.log && echo "Log generated on $(date)" >> results/reports/archive/failed_qc.log
```
> **Why it works:** 
> * `>` overwrites or creates `failed_qc.log` with the initial `grep` results.
> * `&&` logically ensures the subsequent timestamp command only runs if the search command succeeded without error.
> * `$(date)` seamlessly injects the current system time into the string.
> * `>>` safely *appends* the echo string to the very bottom of the log file without erasing the data we just wrote.
:::

**Task 5.14:** Display a clean 2-level directory tree of the project structure without listing every nested file.
::: {.callout-note collapse="true"}
## Show answer
```bash
find . -maxdepth 2 -not -path '*/.*'
```
> **Why it works:** 
> * `-maxdepth 2` severely restricts the search to only the current folder and exactly one level deep.
> * `-not -path '*/.*'` filters out any hidden directories (like `.git`) and hidden files, providing an uncluttered overview of your project structure.
:::

**Task 5.15:** Display the total human-readable disk space usage for each file and subdirectory located directly inside the `results/` directory using wildcard expansion.
::: {.callout-note collapse="true"}
## Show answer
```bash
du -sh results/*
```
> **Why it works:** 
> * `du -s` (summarize) prevents it from traversing and detailing every file inside nested folders, only giving the grand total for each specified path.
> * `results/*` leverages a shell wildcard to pass every individual file and folder inside `results/` into the disk usage command as separate arguments.
:::

*ABI Summer School 2026 · Week 1: Linux / HPC*
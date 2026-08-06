<p align="center">
  <img src="linux_banner_image.png" alt="ABI Summer School 2026 · WEEK 1: Linux / HPC" width="100%" />
</p>

---

# INTRODUCTION TO LINUX BASICS

::: {.callout-note}
### The Scenario
> You are a research assistant on a multi-country
> *Plasmodium falciparum* malaria genomics study spanning field sites across
> East Africa. The lead researcher on the project has had to leave unexpectedly
> and the analysis is half-finished on the cluster.
>
> The supervisor meeting is Monday morning at 9am.
>
> You receive a message:
>
> > *"The project folder is on the cluster. Please find your way around it,
> > organise what was left behind, and make sure everything is in order before
> > the meeting. The folder is called ABI_summer_school_project."*
>
> You are now the person responsible for this project.
> Log in. Get to work.
:::


> **How this works**
> Each question tells you **what needs to be done** and you figure out the command

---


### Step 1 : Download the project

*The project has been uploaded to GitHub (https://github.com/TWG-ABI/ABI-Training). Your first job is to get it onto the cluster.*

**Q1:** Download the project zip file using `wget`.

::: {.callout-note collapse="true"}
## Show answer

```
wget https://github.com/TWG-ABI/ABI-Training/raw/refs/heads/main/week1/ABI_summer_school_project.zip
```

:::

**Q2:** List the files in your current directory to confirm, and check the file size.

::: {.callout-note collapse="true"}
## Show answer

```
ls -lh
```

> You should see `ABI_summer_school_project.zip` with its size.

:::

---

### Step 2 : Unzip the project

*The file arrived as a zip archive. It needs to be extracted before you can work with it.*

**Q1:** Unzip the downloaded file.

::: {.callout-note collapse="true"}
## Show answer

```
unzip ABI_summer_school_project.zip
```

:::

---

### Step 3 : Where are you?

*Before touching anything, make sure you know exactly where you are on the cluster.*

**Q1:** Print your current working directory - the full absolute path.

::: {.callout-note collapse="true"}
## Show answer

```
pwd
```

> Something like `/home/username`

:::

**Q2:** Move into the project folder using a **relative path**, then confirm your new location.

::: {.callout-note collapse="true"}
## Show answer

```
cd ABI_summer_school_project
pwd
```

:::

---

### Step 4 : What is here?

*You have never seen this project before. Get a proper overview of what is inside.*

**Q1:** List the contents of the project folder and show file types, sizes in human-readable format.

::: {.callout-note collapse="true"}
## Show answer

```
ls -lh
```

> You should see directories: `raw_data/`, `reference/`, `variants/`, `results/`, `logs/`, `scripts/`, and `README.txt`

:::

**Q2:** List with one item per line using a different `ls` option.

::: {.callout-note collapse="true"}
## Show answer

```
ls -1
```

> Each file/folder on its own line useful for counting.

:::

**Q3:** List all contents sorted by modification time, newest first.

::: {.callout-note collapse="true"}
## Show answer

```
ls -lt
```

> `-t` sorts by time, newest first.

:::

**Q4:** See everything inside the project - all subdirectories and their contents in one command.

::: {.callout-note collapse="true"}
## Show answer

```
ls -lhR
```

> The `-R` flag lists recursively through all subdirectories.

:::

**Q5:** Read the project README file without opening any editor.

::: {.callout-note collapse="true"}
## Show answer

```
cat README.txt
```

:::

---

### Step 5 : Navigate using absolute and relative paths

*Get comfortable moving around the cluster — not just inside the project folder.*

**Q1:** Move into `raw_data/` using a **relative path**. Print your location.

::: {.callout-note collapse="true"}
## Show answer

```
cd raw_data
pwd
```

:::

**Q2:** Go back up one level to the project root using a relative shortcut.

::: {.callout-note collapse="true"}
## Show answer

```
cd ..
```

> `..` always means 'one level up'.

:::

**Q3:** Jump straight to your home directory in one command.

::: {.callout-note collapse="true"}
## Show answer

```
cd ~
```

> Or just `cd` with no arguments - both go home.

:::

**Q4:** Now navigate into `reference/` using an **absolute path** (replace `username` with yours).

::: {.callout-note collapse="true"}
## Show answer

```
cd /home/username/ABI_summer_school_project/reference
```

> Absolute paths always start with `/`.

:::

**Q5:** Go back to the project root. Try the shortcut for the previous directory you were in.

::: {.callout-note collapse="true"}
## Show answer

```
cd -
```

> `cd -` takes you back to wherever you just were — like an undo for navigation.

:::

---

### Step 6 : View file contents

*The `raw_data/` folder has a sample manifest. Read through it to understand what samples are in the project.*

**Q1:** From the project root, print the entire sample manifest to the screen.

::: {.callout-note collapse="true"}
## Show answer

```
cat raw_data/sample_manifest.tsv
```

:::

**Q2:** From the project root, print two files at once - the manifest and the coverage report - using a single `cat` command.

::: {.callout-note collapse="true"}
## Show answer

```
cat raw_data/sample_manifest.tsv raw_data/coverage_report.tsv
```

> `cat` accepts multiple filenames separated by spaces.

:::

**Q3:** The manifest is long. Show only the **first 4 lines** (header + 3 samples).

::: {.callout-note collapse="true"}
## Show answer

```
head -n 4 raw_data/sample_manifest.tsv
```

:::

**Q4:** Show only the **last 3 lines** of the manifest.

::: {.callout-note collapse="true"}
## Show answer

```
tail -n 3 raw_data/sample_manifest.tsv
```

:::

**Q5:** Navigate into the `reference/` directory. From there, open the reference FASTA in a pager so you can scroll through it without flooding the screen.

::: {.callout-note collapse="true"}
## Show answer

```
cd reference
less Pfalciparum_3D7.fasta
```

> Arrow keys to scroll · `q` to quit · `/` then a word to search inside.

:::

**Q6:** Without leaving `reference/`, show the first 8 lines of `SAMPLE_001.fastq` which is located in `raw_data/`. You will need to use `../` to go up one level and then into `raw_data/`. Can you identify the 4 parts of a FASTQ read?

::: {.callout-note collapse="true"}
## Show answer

```
head -n 8 ../raw_data/SAMPLE_001.fastq
```

> Line 1: `@` header · Line 2: DNA sequence · Line 3: `+` separator · Line 4: quality scores

:::

**Q7:** Still in `reference/`, show the last 8 lines of the same file using relative paths.

::: {.callout-note collapse="true"}
## Show answer

```
tail -n 8 ../raw_data/SAMPLE_001.fastq
```

:::

---

### Step 7 : Use wildcards

*There are 10 FASTQ files in the project. Get a quick overview of all of them without typing each name.*

**Q1:** Navigate to `raw_data/`. From here, list all FASTQ files at once using a wildcard.

::: {.callout-note collapse="true"}
## Show answer

```
cd raw_data
ls -lh *.fastq
```

> `*` matches anything — so `*.fastq` matches every file ending in `.fastq`.

:::

**Q2:** From where you are, list all files in `variants/` ending in `.vcf`.

::: {.callout-note collapse="true"}
## Show answer

```
ls -lh ../variants/*.vcf
```

:::

**Q3:** Navigate into `results/qc/` (you are currently in `raw_data/`, so you'll need to go up and then down into `results/qc/`). From here, list all files in `reference/` whose names start with `Pf`. You'll need to go two levels up (`../../`)!

::: {.callout-note collapse="true"}
## Show answer

```
cd ../results/qc
ls -lh ../../reference/Pf*
```

:::

**Q4:** Go back to the project root. List all files in `raw_data/` that contain the word `SAMPLE` in their name.

::: {.callout-note collapse="true"}
## Show answer

```
cd ../../
ls raw_data/*SAMPLE*
```

> `*` on both sides matches anything before and after the word.

:::

---

### Step 8 : Find hidden files

*There is a personal note hidden somewhere in the project but nobody can find it. A normal `ls` is not showing everything.*

**Q1:** From the project root, list **all** files in `raw_data/` — including hidden ones.

::: {.callout-note collapse="true"}
## Show answer

```
ls -a raw_data/
```

> Files starting with `.` are hidden in Linux. They only appear with `-a`.

:::

**Q2:** Show the hidden files with full details and human-readable sizes.

::: {.callout-note collapse="true"}
## Show answer

```
ls -lha raw_data/
```

:::

**Q3:** Read the hidden note.

::: {.callout-note collapse="true"}
## Show answer

```
cat raw_data/.hidden_note.txt
```

:::

**Q4:** Search for any other hidden directories anywhere in the project.

::: {.callout-note collapse="true"}
## Show answer

```
ls -la
```

> You should spot `.backup/` in the project root — go inside and see what is there.

:::

---

### Step 9 : Create directories

*The `results/` folder is completely empty. The supervisor expects a proper structure before the meeting.*

**Q1:** From the project root, create a single directory called `qc/` inside `results/`.

::: {.callout-note collapse="true"}
## Show answer

```
mkdir results/qc
```

:::

**Q2:** Create two more directories — `alignments/` and `variants/` — inside `results/` in one command.

::: {.callout-note collapse="true"}
## Show answer

```
mkdir results/alignments results/variants
```

> Pass multiple paths to `mkdir` separated by spaces.

:::

**Q3:** Create `results/reports/archive/` — two levels deep — in one command.

::: {.callout-note collapse="true"}
## Show answer

```
mkdir -p results/reports/archive
```

> `-p` creates all parent directories that don't exist yet. Without it, this would fail.

:::

---

### Step 10 : Create and edit files

*A notes file is needed in `results/reports/` before the supervisor meeting.*

**Q1:** Move into `results/reports/`. Create an empty file called `analysis_notes.txt` here.

::: {.callout-note collapse="true"}
## Show answer

```
cd results/reports
touch analysis_notes.txt
```

> `touch` creates an empty file if it doesn't already exist.

:::

**Q2:** Open it in `nano` and write one line: `Analysis started by [your name], 8 June 2026`

::: {.callout-note collapse="true"}
## Show answer

```
nano analysis_notes.txt
```
Type some contents in the file and save it

> `Ctrl+O` → `Enter` to save · `Ctrl+X` to exit

:::

**Q3:** Confirm the file saved correctly.

::: {.callout-note collapse="true"}
## Show answer

```
cat analysis_notes.txt
```

:::

**Q4:** Navigate deep into `archive/` (so you are in `results/reports/archive/`). From here, create **three empty files** at once in `results/qc/`. You will need to go three levels up to the project root (`../../../`) and then down into `results/qc/` — `sample_001_qc.txt`, `sample_002_qc.txt`, `sample_003_qc.txt`.

::: {.callout-note collapse="true"}
## Show answer

```
cd archive
touch ../../../results/qc/sample_001_qc.txt ../../../results/qc/sample_002_qc.txt ../../../results/qc/sample_003_qc.txt
```

> `touch` also accepts multiple filenames.

:::

---

### Step 11 : Copy files and directories

*Key files need to be copied into the right places before the meeting.*

**Q1:** Navigate back to `results/reports/`. Copy `sample_manifest.tsv` from the `raw_data/` folder directly into your current directory using `.` to represent "here". You will need to use `../../` to reach the raw data.

::: {.callout-note collapse="true"}
## Show answer

```
cd ..
cp ../../raw_data/sample_manifest.tsv .
```

:::

**Q2:** Confirm both copies exist — the original and the new one.

::: {.callout-note collapse="true"}
## Show answer

```
ls -lh raw_data/sample_manifest.tsv results/reports/sample_manifest.tsv
```

:::

**Q3:** Navigate into `results/qc/`. From here, copy `SAMPLE_001.fastq` from the `raw_data/` folder (two levels up) into your current directory `.` but name it `SAMPLE_001_backup.fastq`.

::: {.callout-note collapse="true"}
## Show answer

```
cd ../qc
cp ../../raw_data/SAMPLE_001.fastq ./SAMPLE_001_backup.fastq
```

> You can rename a file while copying it by giving the destination a new filename.

:::

**Q4:** From where you are (`results/qc/`), copy the entire `logs/` directory into `results/` as a backup (you'll need to go two levels up to find `logs/`, and one level up for the destination `results/logs_backup/`), and verify it copied successfully. You need a flag for directories.

::: {.callout-note collapse="true"}
## Show answer

```
cp -r ../../logs ../logs_backup/
ls -lh ../logs_backup/
```

> `-r` means recursive — copies the directory and all its contents.

:::

**Q5:** Go back to the project root. Copy `SAMPLE_002.fastq` from `raw_data/` to `results/qc/` but ask for confirmation before overwriting if a file already exists.

::: {.callout-note collapse="true"}
## Show answer

```
cd ../../
cp -i raw_data/SAMPLE_002.fastq results/qc/
```

> `-i` stands for interactive — it prompts you before overwriting anything.
find the right way of using this command is cp -i ; the comand given above is wrong way of using it.

:::

---

### Step 12 : Create symbolic links

*The pipeline failed because it expected a file called `ref_index` inside `results/` — but it does not exist. A symbolic link is needed there pointing to the reference FASTA.*

**Q1:** From the project root, create a symbolic link called `ref_index` inside `results/` pointing to the reference FASTA.

::: {.callout-note collapse="true"}
## Show answer

```
ln -s ../reference/Pfalciparum_3D7.fasta results/ref_index
```

> `ln -s source linkname` — the source is where the link points, the link name is what you create.

:::

**Q2:** Verify the link was created. What does the `->` in the listing tell you?

::: {.callout-note collapse="true"}
## Show answer

```
ls -lh results/
```

> The `->` shows where the link points. A symlink is a pointer — no data is duplicated.

:::

**Q3:** Navigate into `results/reports/`. Create a symbolic link here called `manifest_link.tsv` that points to the original manifest in `raw_data/`. You'll need to tell the link how to get there using `../../`!

::: {.callout-note collapse="true"}
## Show answer

```
cd results/reports
ln -s ../../raw_data/sample_manifest.tsv manifest_link.tsv
```

:::

---

### Step 13 : Move and rename files

*Some files need to be renamed and reorganised.*

**Q1:** Navigate to `raw_data/`. Create a folder called `trimmed/` here.

::: {.callout-note collapse="true"}
## Show answer

```
cd ../../raw_data
mkdir trimmed
```

:::

**Q2:** Rename `SAMPLE_003.fastq` to `SAMPLE_003_trimmed.fastq` here in `raw_data/`.

::: {.callout-note collapse="true"}
## Show answer

```
mv SAMPLE_003.fastq SAMPLE_003_trimmed.fastq
```

:::

**Q3:** Move the renamed file into `trimmed/`.

::: {.callout-note collapse="true"}
## Show answer

```
mv SAMPLE_003_trimmed.fastq trimmed/
```

:::

**Q4:** Move into `results/reports/`. From here, move both `batch1_samples.txt` and `batch2_samples.txt` from `raw_data/` (two levels up!) directly into your current directory using `.`.

::: {.callout-note collapse="true"}
## Show answer

```
cd ../results/reports
mv ../../raw_data/batch1_samples.txt ../../raw_data/batch2_samples.txt .
```


:::

**Q5:** Go back to the project root. Move the entire `scripts/` directory into `results/`. Notice you do **not** need `-r` for `mv`.

::: {.callout-note collapse="true"}
## Show answer

```
cd ../../
mv scripts/ results/
```

> `mv` moves directories without any extra flags — unlike `cp` which needs `-r`.

:::

**Q6:** Move `results/logs_backup/` into a directory called `archive/` that doesn't exist yet.

::: {.callout-note collapse="true"}
## Show answer

```
mv results/logs_backup/ results/archive/
```

> `mv` creates the destination directory if it doesn't exist — unlike `cp -r`.

:::

---

### Step 14 : Delete files and directories

*Samples 008 and 009 failed QC and should be removed from the project.*

**Q1:** From the project root, delete `SAMPLE_008.fastq` from `raw_data/`.

::: {.callout-note collapse="true"}
## Show answer

```
rm raw_data/SAMPLE_008.fastq
```

:::

**Q2:** Delete `SAMPLE_009.fastq` and `SAMPLE_010.fastq` together in one command.

::: {.callout-note collapse="true"}
## Show answer

```
rm raw_data/SAMPLE_009.fastq raw_data/SAMPLE_010.fastq
```

> `rm` accepts multiple filenames.

:::

**Q3:** The `results/qc/` folder has some empty placeholder files from Step 10. Delete all three at once using a wildcard.

::: {.callout-note collapse="true"}
## Show answer

```
rm results/qc/sample_*_qc.txt
```

:::

**Q4:** Delete the `results/archive/` directory and everything inside it.

::: {.callout-note collapse="true"}
## Show answer

```
rm -r results/archive/
```

> `-r` removes a directory recursively. Without it, `rm` refuses to delete directories.

:::

**Q5:** Confirm the deletions — list `raw_data/` and check what FASTQ files remain.

::: {.callout-note collapse="true"}
## Show answer

```
ls -lh raw_data/*.fastq
```

> You should see SAMPLE_001, 002, 004, 005, 006, 007 (003 is in `trimmed/`, 008-010 deleted).

:::

---

### Step 15 : Sort files

*The sample lists need to be sorted before they can be compared.*

**Q1:** Take a look at `results/reports/batch2_samples.txt`. It is actually already in alphabetical order, so we do not need to sort it! (Feel free to verify this using `cat`).

::: {.callout-note collapse="true"}
## Show answer

```
cat results/reports/batch2_samples.txt
```

:::

**Q2:** However, `batch1_samples.txt` is messy. From the project root, sort `results/reports/batch1_samples.txt` alphabetically and print the result to the screen.

::: {.callout-note collapse="true"}
## Show answer

```
sort results/reports/batch1_samples.txt
```

:::

**Q3:** Now sort `results/reports/batch1_samples.txt` and save the output to `batch1_sorted.txt` in the same folder.

::: {.callout-note collapse="true"}
## Show answer

```
sort results/reports/batch1_samples.txt > results/reports/batch1_sorted.txt
```

:::

**Q4:** From the project root, sort the sample manifest by the `site` column (column 3).

::: {.callout-note collapse="true"}
## Show answer

```
sort -k3 raw_data/sample_manifest.tsv
```

> `-k3` sorts by the third column.

:::

**Q5:** Sort the manifest by collection date (column 4) in reverse order.

::: {.callout-note collapse="true"}
## Show answer

```
sort -k4 -r raw_data/sample_manifest.tsv
```

> `-r` reverses the sort order.

:::

---

### Step 16 : Compare sorted files with `comm`

*Samples were sent to two different sequencing batches. Find out which samples are unique to each batch and which appear in both.*

**Q1:** From the project root, use `comm` to compare the two sorted sample lists. What do the three columns mean?

::: {.callout-note collapse="true"}
## Show answer
 

```
comm results/reports/batch1_sorted.txt results/reports/batch2_samples.txt
```

> Column 1: only in batch1 · Column 2: only in batch2 · Column 3: in both files. Files **must** be sorted first.

:::

**Q2:** Show only samples that appear in **both** batches (suppress columns 1 and 2).

::: {.callout-note collapse="true"}
## Show answer

```
comm -12 results/reports/batch1_sorted.txt results/reports/batch2_samples.txt
```

> `-12` suppresses columns 1 and 2, leaving only the shared lines.

:::

**Q3:** Show only samples **unique to batch1** (not in batch2).

::: {.callout-note collapse="true"}
## Show answer

```
comm -23 results/reports/batch1_sorted.txt results/reports/batch2_samples.txt
```

> `-23` suppresses columns 2 and 3.

:::

**Q4:** Show only samples **unique to batch2**.

::: {.callout-note collapse="true"}
## Show answer

```
comm -13 results/reports/batch1_sorted.txt results/reports/batch2_samples.txt
```

> `-13` suppresses columns 1 and 3.

:::

---

### Step 17 : Join files with `join`

*The sample manifest and the coverage report need to be combined into one table, matched by sample ID.*

**Q1:** First, sort both files by their first column (sample ID) and save the outputs.

::: {.callout-note collapse="true"}
## Show answer

```
sort -k1 raw_data/sample_manifest.tsv > manifest_sorted.tsv
sort -k1 raw_data/coverage_report.tsv > coverage_sorted.tsv
```

> `join` requires both files to be sorted on the join field.

:::

**Q2:** Join the two sorted files on column 1 (sample ID).

::: {.callout-note collapse="true"}
## Show answer

```
join manifest_sorted.tsv coverage_sorted.tsv
```

> `join` matches lines where column 1 is the same in both files and merges them.

:::

**Q3:** Join but show **all** lines from the manifest even if there is no match in the coverage file.

::: {.callout-note collapse="true"}
## Show answer

```
join -a1 manifest_sorted.tsv coverage_sorted.tsv
```

> `-a1` includes unmatched lines from file 1 (the manifest).

:::

---

### Step 18 : Find files with `find`

*Audit everything in the project directory — find every file type and location.*

**Q1:** From the project root, find all `.fastq` files anywhere in the project.

::: {.callout-note collapse="true"}
## Show answer

```
find . -name '*.fastq'
```

:::

**Q2:** Find all `.vcf` files anywhere in the project.

::: {.callout-note collapse="true"}
## Show answer

```
find . -name '*.vcf'
```

:::

**Q3:** Find all hidden files anywhere in the project.

::: {.callout-note collapse="true"}
## Show answer

```
find . -name '.*' -type f
```

:::

**Q4:** Find only directories — no files.

::: {.callout-note collapse="true"}
## Show answer

```
find . -type d
```

:::

**Q5:** Find any file larger than 1 kilobyte.

::: {.callout-note collapse="true"}
## Show answer

```
find . -size +1k -type f
```

:::

**Q6:** Find files modified in the last 1 day.

::: {.callout-note collapse="true"}
## Show answer

```
find . -mtime -1 -type f
```

> `-mtime -1` means modified less than 1 day ago.

:::

**Q7:** Find files whose name starts with `SAMPLE` and ends with `.fastq`.

::: {.callout-note collapse="true"}
## Show answer

```
find . -name 'SAMPLE*.fastq'
```

:::

---

### Step 19 : Count lines with `wc`

*Get some quick counts across the data files.*

**Q1:** From the project root, how many lines does the sample manifest have, including the header?

::: {.callout-note collapse="true"}
## Show answer

```
wc -l raw_data/sample_manifest.tsv
```

> Answer: 11 lines (1 header + 10 samples)

:::

**Q2:** How many lines does `SAMPLE_001.fastq` have? Given each read is 4 lines, how many reads does it contain?

::: {.callout-note collapse="true"}
## Show answer

```
wc -l raw_data/SAMPLE_001.fastq
```

> Divide the line count by 4 to get the number of reads.

:::

**Q3:** Count lines across all remaining FASTQ files at once using a wildcard.

::: {.callout-note collapse="true"}
## Show answer

```
wc -l raw_data/*.fastq
```

> You get a count per file plus a total at the bottom.

:::

**Q4:** Count lines in all VCF files.

::: {.callout-note collapse="true"}
## Show answer

```
wc -l variants/*.vcf
```

:::

---

### Step 20 : Search with `grep`

*Search and interrogate the data files.*

**Q1:** From the project root, show all lines in `SAMPLE_001.vcf` that contain the word `PASS`.

::: {.callout-note collapse="true"}
## Show answer

```
grep 'PASS' variants/SAMPLE_001.vcf
```

:::

**Q2:** Count how many lines contain `PASS` — use a `grep` flag, no separate command.

::: {.callout-note collapse="true"}
## Show answer

```
grep -c 'PASS' variants/SAMPLE_001.vcf
```

> `-c` counts matching lines directly. Answer: 9

:::

**Q3:** Show only the **variant data lines** — lines that do NOT start with `#`.

::: {.callout-note collapse="true"}
## Show answer

```
grep -v '^#' variants/SAMPLE_001.vcf
```

> `-v` inverts the match · `^#` means 'starts with #'

:::

**Q4:** Count the variant data lines (non-header lines) in `SAMPLE_001.vcf` in one command.

::: {.callout-note collapse="true"}
## Show answer

```
grep -vc '^#' variants/SAMPLE_001.vcf
```

> Combine `-v` and `-c`. Answer: 13

:::

**Q5:** Show all WARNING lines in `pipeline.log` with their line numbers.

::: {.callout-note collapse="true"}
## Show answer

```
grep -n 'WARNING' logs/pipeline.log
```

> `-n` shows line numbers alongside matches.

:::

**Q6:** Search for 'failed' in the pipeline log — uppercase or lowercase.

::: {.callout-note collapse="true"}
## Show answer

```
grep -i 'failed' logs/pipeline.log
```

> `-i` makes the search case-insensitive.

:::

**Q7:** How many sequences (chromosomes) are in the reference FASTA? In FASTA format every sequence header starts with `>`.

::: {.callout-note collapse="true"}
## Show answer

```
grep -c '^>' reference/Pfalciparum_3D7.fasta
```

> Answer: 5 chromosomes

:::

**Q8:** Search for `SAMPLE_008` across **all files** in the project at once.

::: {.callout-note collapse="true"}
## Show answer

```
grep -r 'SAMPLE_008' .
```

> `-r` searches recursively through all files in a directory.

:::

**Q9:** Search for `ERROR` in `logs/` and show the filename alongside each match.

::: {.callout-note collapse="true"}
## Show answer

```
grep -rn 'ERROR' logs/
```

> `-n` shows line numbers · `-r` searches all files in the directory.

:::

---

### Step 21 : Extract columns with `cut`

*Specific columns need to be pulled out of the tab-separated files.*

**Q1:** From the project root, extract only the `sample_id` column (column 1) from the sample manifest.

::: {.callout-note collapse="true"}
## Show answer

```
cut -f1 raw_data/sample_manifest.tsv
```

:::

**Q2:** Extract the `site` column (column 3).

::: {.callout-note collapse="true"}
## Show answer

```
cut -f3 raw_data/sample_manifest.tsv
```

:::

**Q3:** Extract both `sample_id` and `pass_qc` columns (columns 1 and 8) at the same time.

::: {.callout-note collapse="true"}
## Show answer

```
cut -f1,8 raw_data/sample_manifest.tsv
```

:::

**Q4:** Extract a range of columns — columns 1 through 4.

::: {.callout-note collapse="true"}
## Show answer

```
cut -f1-4 raw_data/sample_manifest.tsv
```

> `-f1-4` extracts columns 1, 2, 3, and 4 in one go.

:::

---

### Step 22 : Combine files with `paste`

*Build a quick combined reference table from two files.*

**Q1:** From the project root, use `paste` to combine `results/reports/batch1_sorted.txt` and `results/reports/batch2_samples.txt` side by side.

::: {.callout-note collapse="true"}
## Show answer

```
paste results/reports/batch1_sorted.txt results/reports/batch2_samples.txt
```

> `paste` merges files column by column — each line of file 1 next to the matching line of file 2.

:::

**Q2:** Paste the two files using a comma as a separator instead of a tab.

::: {.callout-note collapse="true"}
## Show answer

```
paste -d',' results/reports/batch1_sorted.txt results/reports/batch2_samples.txt
```

> `-d` sets the delimiter character.

:::

---

---

## YOU MADE IT!

You made it through the entire project directory.
The folder is organised, the data is interrogated, and the meeting is saved.

---

### Commands used today

| Category | Commands & options |
|---|---|
| Download & extract | `wget` · `unzip` |
| Location | `pwd` |
| Navigation | `cd` · `cd ..` · `cd ~` · `cd -` |
| Listing | `ls -l` · `ls -lh` · `ls -1` · `ls -t` · `ls -lt` · `ls -a` · `ls -lha` · `ls -R` · `ls -lhR` |
| Viewing files | `cat` · `head -n` · `tail -n` · `less` |
| Wildcards | `*.fastq` · `*.vcf` · `Pf*` · `*SAMPLE*` · `SAMPLE*.fastq` |
| Creating directories | `mkdir` · `mkdir -p` |
| Creating files | `touch` · `nano` |
| Copying | `cp` · `cp -r` · `cp -i` |
| Symbolic links | `ln -s` |
| Moving & renaming | `mv` |
| Deleting | `rm` · `rm -r` |
| Sorting | `sort` · `sort -k` · `sort -r` |
| Comparing | `comm` · `comm -12` · `comm -23` · `comm -13` |
| Joining | `join` · `join -a1` |
| Finding | `find -name` · `find -type` · `find -size` · `find -mtime` |
| Counting | `wc -l` |
| Searching | `grep` · `grep -c` · `grep -v` · `grep -vc` · `grep -n` · `grep -i` · `grep -r` · `grep -rn` |
| Extracting columns | `cut -f` · `cut -f1-4` |
| Combining files | `paste` · `paste -d` |

---

*ABI Summer School 2026 · Week 1: Linux / HPC*

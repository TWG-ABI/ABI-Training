<p align="center">
  <img src="linux_banner_image.png" alt="ABI Summer School 2026 · WEEK 1: Linux / HPC" width="100%" />
</p>

---

# LINUX BASICS RECAP

::: {.callout-note}
> ### Pipes and Brace Expansion
>
> Now that you are comfortable navigating the Linux file system and managing files, it is time to transition into real data analysis.
> 
> Genomics projects often involve massive amounts of data. Executing tasks one command at a time, or manually typing out dozens of filenames, is highly inefficient and prone to errors. 
>
> In this module, you will learn how to chain multiple programs together into a single continuous workflow using **Pipes** (`|`), and how to automatically generate sequences of data using **Brace Expansion** (`{}`). These are essential skills for scaling up your workflows and working efficiently on the cluster.
>
> Navigate to your project directory, and let's get started.
:::

## Brace Expansion

*Typing out long lists of files or repetitive folder names is prone to typos. Learn to expand them automatically.*

---

### Step 1 : Creating bulk directories

**Q1:** From the project root, create four directories inside `results/` at once using brace expansion: `fastqc`, `trimmomatic`, `bwa`, and `gatk`.

::: {.callout-note collapse="true"}
## Show answer

```
mkdir -p results/{fastqc,trimmomatic,bwa,gatk}
```

> **Tip:** Do not put spaces after the commas in brace expansion! `{a,b}` works, `{a, b}` does not.

:::

---

### Step 2 : Creating sequential files

**Q1:** Create five empty log files in `logs/` named `run_day_1.log` through `run_day_5.log` using brace expansion.

::: {.callout-note collapse="true"}
## Show answer

```
touch logs/run_day_{1..5}.log
```

:::

---

### Step 3 : The backup shortcut

*A quick trick to make backups without typing a filename twice.*

**Q1:** Navigate to `raw_data/`. Copy `sample_manifest.tsv` to a new file called `sample_manifest.tsv.backup` using the `{,.backup}` trick.

::: {.callout-note collapse="true"}
## Show answer

```
cd ../raw_data
cp sample_manifest.tsv{,.backup}
```

> This expands to `cp sample_manifest.tsv sample_manifest.tsv.backup`. It works because the first item in the brace is completely empty!

:::

---

## The Power of Pipes (`|`)

*Programs in Linux are designed to do one thing well. The pipe operator (`|`) takes the standard output of one command and feeds it directly into the standard input of the next.*

---

### Step 4 : Piping to  `grep`, `less` and `wc`

**Q1:** Go back to the project root. You want to view all lines in `pipeline.log` that contain the word `WARNING`. Use `grep` to find them, and pipe the output to `less` so you can scroll through them safely.

::: {.callout-note collapse="true"}
## Show answer

```
cd ..
grep "WARNING" logs/pipeline.log | less
```

:::

**Q2:** Navigate into `variants/`. Search for all lines in `SAMPLE_001.vcf` that DO NOT start with `#` (the data lines) using `grep -v`.

::: {.callout-note collapse="true"}
## Show answer

```
cd variants
grep -v "^#" SAMPLE_001.vcf
```

> `^` inside grep means "starts with".

:::

**Q3:** Pipe that output into another `grep` to find only the variants marked as `PASS`.

::: {.callout-note collapse="true"}
## Show answer

```
grep -v "^#" SAMPLE_001.vcf | grep "PASS"
```

:::

**Q4:** Pipe that final output into `wc -l` to count exactly how many PASS variants this sample has.

::: {.callout-note collapse="true"}
## Show answer

```
grep -v "^#" SAMPLE_001.vcf | grep "PASS" | wc -l
```

:::

---

## Advanced Combinations

*Putting everything together into powerful one-liners.*

---

### Step 6 : `find` + Pipes

**Q1:** Go back to the project root. Use `find` to list all `.fastq` files anywhere in the project, and pipe the output to `wc -l` to count how many FASTQ files exist.

::: {.callout-note collapse="true"}
## Show answer

```
cd ..
find . -name "*.fastq" | wc -l
```

:::

---

### Step 7 : Brace Expansion + Pipes

**Q1:** From the project root, search for the sequence `ATG` across specifically `SAMPLE_001.fastq`, `SAMPLE_002.fastq`, and `SAMPLE_003.fastq` in the `raw_data/` folder using brace expansion.

::: {.callout-note collapse="true"}
## Show answer

```
grep "ATG" raw_data/SAMPLE_{001,002,003}.fastq
```

> Alternatively, `raw_data/SAMPLE_00{1..3}.fastq` also works!

:::

**Q2:** Pipe that search into `wc -l` to count how many total times `ATG` appears across all three files combined.

::: {.callout-note collapse="true"}
## Show answer

```
grep "ATG" raw_data/SAMPLE_{001..003}.fastq | wc -l
```

:::

---

## YOU MADE IT!

You have mastered the pipe and the brace. 

---

### Commands used today

| Category | Commands & operators |
|---|---|
| Brace Expansion (Lists) | `{name1,name2,name3}` |
| Brace Expansion (Ranges) | `{1..5}` · `{a..z}` |
| Brace Expansion (Append) | `{,.bak}` |
| The Pipe | `|` |
| Viewing | `less` |
| Counting | `wc -l` |
| Filtering | `grep` · `grep -v` |
| Finding | `find -name` |

---
*ABI Summer School 2026 · Week 1: Linux / HPC*

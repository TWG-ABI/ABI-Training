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

# Bash Scripting II: Advanced Text, Dynamic Inputs & Automation

::: {.callout-note}
## Overview & Learning Objectives
In Part I, we learned how to write basic Bash scripts, submit jobs on the HPC cluster using Slurm, and manage simple variables and user input.

Now, we take our scripting to an advanced level. We will learn how to **escape special characters**, capture dynamic inputs using **Command Substitution and Positional Arguments**, perform **Mathematical calculations**, implement **Conditional decision making (`if` statements)**, and automate large-scale batch processing using **Loops**.
:::

---

## Part 1: Text Formatting & Escaping Special Characters

Sometimes you need to print a newline, a tab, or print a character that usually has a special syntax meaning in Bash (such as `$`, `"`, or `\`). We do this by "escaping" the character using a backslash `\`.

* **Escaping:** The backslash `\` removes the special meaning of the character immediately following it, or turns normal characters into special formatting characters.
* To use special formatting escape sequences with `echo`, you must include the `-e` flag (enable escapes).

### Common Escape Sequences:
* `\n`: Newline (moves text to the next line)
* `\t`: Horizontal Tab (indents text into clean columns)
* `\\`: Prints a literal backslash
* `\"`: Prints a literal double quote
* `\$`: Prints a literal dollar sign (prevents variable expansion)
* `\a`: Alert (triggers a terminal bell/beep)

---

### Practical 1: The Formatter (`format.sh`)

1. Open a new file called `format.sh`:
   ```bash
   nano format.sh
   ```
2. Type the following code:
   ```bash
   #!/bin/bash
   # ---description----
   # Demonstrating escape sequences and special character formatting
   # Usage: bash format.sh

   PRICE=100
   echo "The cost is \$${PRICE}"            # We escape the $ so it prints literally
   echo -e "Sample1\tSample2\tSample3"       # Prints with tabs between columns
   echo -e "Line1\nLine2\nLine3"             # Prints on three separate lines
   ```
3. Save and exit `nano` (`Ctrl+O`, `Enter`, `Ctrl+X`).
4. Run the script:
   ```bash
   bash format.sh
   ```

---

## Part 2: Dynamic Inputs - Command Substitution & Positional Arguments

Before building automated pipelines, our scripts must be able to dynamically capture information from two sources:
1. **The Terminal Command Line** (Positional Arguments passed when launching the script)
2. **Other Linux Commands** (Command Substitution capturing live output)

---

### 1. Command Substitution (`$()`)
Sometimes you do not want to store static text in a variable; you want to save the *live output* of a Linux command (such as a line count from `wc -l`, or the current timestamp from `date`).

* By wrapping a command inside `$(...)`, Linux executes that command first, captures its Standard Output, and substitutes that result into your variable.
* *(Historical note: Older scripts used backticks `` `command` ``, but `$()` is the modern standard because it is cleaner and can be easily nested).*

NOTE:simple command substitution script example
---

### 2. Positional Arguments (`$1`, `$2`, `$@`, `$#`)
When you launch a script from the terminal, you can pass file paths or parameters directly after the script name (for example: `bash count_lines.sh sample1.fastq sample2.fastq`). 

Inside your script, Bash automatically assigns these inputs to special built-in variables:

| Variable | Purpose | Example |
| :--- | :--- | :--- |
| `$1` | The **first** argument passed | `ABI_summer_school_project/raw_data/SAMPLE_001.fastq` |
| `$2` | The **second** argument passed | `ABI_summer_school_project/raw_data/SAMPLE_002.fastq` |
| `$@` | A list of **all** arguments provided | `SAMPLE_001.fastq SAMPLE_002.fastq` |
| `$#` | The **total count** of arguments provided | `2` |

NOTE: simple example script here on positional arguments
---

### Practical 2: Counting Lines with Dynamic Arguments (`count_lines.sh`)

Let's see Command Substitution and Positional Arguments working together on actual bioinformatics files:
* **Scenario:** You have two FASTQ files for a single sample (read 1 and read 2) and you need to count the total number of reads across both files.

1. Open a new file `count_lines.sh`:
   ```bash
   nano count_lines.sh
   ```
2. Type the following code:
   ```bash
   #!/bin/bash
   # ---description----
   # Counts lines in files passed as positional arguments
   # Usage: bash count_lines.sh file1 file2

   # Check if at least 2 arguments were provided
   echo "Arguments received: $@"
   echo "Total argument count: $#"

   # Command substitution capturing line counts of $1 and $2
   NUM_ONE=$(cat $1 | wc -l)
   NUM_TWO=$(cat $2 | wc -l)

   echo "----------------------------------------"
   echo "File 1 ($1) has $NUM_ONE lines."
   echo "File 2 ($2) has $NUM_TWO lines."
   echo "----------------------------------------"
   ```
3. Save and exit `nano`.
4. Run the script by passing two files from your project folder:
   ```bash
   bash count_lines.sh ABI_summer_school_project/raw_data/SAMPLE_001.fastq ABI_summer_school_project/raw_data/SAMPLE_002.fastq
   ```

---

## Part 3: Arithmetic in Bash

By default, Bash treats all variables as text strings. If you type `VAL="10+5"`, Bash stores a string of four characters, not the number 15! We must use specific syntax to perform mathematical calculations.

### Arithmetic Operators
* `+` : Addition
* `-` : Subtraction
* `*` : Multiplication
* `/` : Integer Division (decimals are truncated/dropped)
* `**` : Exponentiation (Power)
* `%` : Modulo (Remainder of division)

---

### Arithmetic Substitution `$(( ))` & Evaluation `(( ))`

1. **`$(( expression ))` (Substitution):** Calculates the mathematical formula and substitutes the numeric result back into your script or variable.
2. **`(( expression ))` (Evaluation):** Evaluates mathematical logic directly without printing. It is primarily used for incrementing counters (e.g. `((COUNT++))`) or modifying variables.

---

### Practical 3: Math & Counters (`arithmetic.sh`)

::: {.callout-note}
## Challenge Scenario
You are processing sequencing data where a sample yielded $20$ million total reads, and $4$ million reads successfully mapped to the reference genome. 

How can we write a script `arithmetic.sh` that calculates basic mathematical metrics (sum, product, division) and dynamically increments step counters as our pipeline progresses?
:::

1. Open a new file `arithmetic.sh`:
   ```bash
   nano arithmetic.sh
   ```
2. Type the following code:
   ```bash
   #!/bin/bash
   # ---description----
   # Demonstrating arithmetic operations and variable incrementing
   # Usage: bash arithmetic.sh

   # 1. Calculating values with $(( ))
   A=20
   B=4
   SUM=$((A + B))
   PRODUCT=$((A * B))
   DIV=$((A / B))

   echo "Sum: $SUM"
   echo "Product: $PRODUCT"
   echo "Division: $DIV"

   # 2. Incrementing counters with (( ))
   COUNT=1
   echo "Initial count: $COUNT"

   ((COUNT++))      # Adds 1 to COUNT
   echo "Count after ++: $COUNT"

   ((COUNT += 5))   # Adds 5 to COUNT
   echo "Count after += 5: $COUNT"
   ```
3. Save, exit `nano`, and run:
   ```bash
   bash arithmetic.sh
   ```

---

## Part 4: Decision Making (If Statements)

Bioinformatics pipelines need to make intelligent decisions based on file existence, quality thresholds, or user arguments. We control script execution flow using `if` statements.

### 1. Basic Syntax Structures

::: {.callout-tip}
## Syntax Rule for `[ condition ]`
Always leave spaces after `[` and before `]`. Every `if` block must conclude with `fi` (`if` spelled backward)!
:::

* **Simple `if`:**
  ```bash
  if [ condition ]; then
      # Code to run if true
  fi
  ```
* **`if...else`:**
  ```bash
  if [ condition ]; then
      # Code to run if true
  else
      # Code to run if false
  fi
  ```
* **`if...elif...else`:**
  ```bash
  if [ condition1 ]; then
      # Code for condition 1
  elif [ condition2 ]; then
      # Code for condition 2
  else
      # Fallback code
  fi
  ```

---

### 2. Comparison Operators

Bash uses distinct operators for comparing numbers versus comparing strings:

#### Numeric Comparison Operators:
* `-eq` : Equal to
* `-ne` : Not equal to
* `-gt` : Greater than
* `-ge` : Greater than or equal to
* `-lt` : Less than
* `-le` : Less than or equal to

#### String Comparison Operators:
* `==` : Exact string match
* `!=` : Strings do not match

#### Example Script: Quality Control Check on Project Data (`qc_check.sh`)

::: {.callout-note}
## Practical Scenario
Let's inspect sample `SAMPLE_001` from our project file `ABI_summer_school_project/raw_data/sample_manifest.tsv` to verify if it meets our quality criteria:
1. **String comparison (`==`):** Is the organism `Plasmodium_falciparum`?
2. **Numeric comparison (`-ge`):** Is the sequencing read length at least $150\text{ bp}$?
:::

1. Open `qc_check.sh`:
   ```bash
   nano qc_check.sh
   ```
2. Type the following code:
   ```bash
   #!/bin/bash
   # ---description----
   # Demonstrating string and numeric comparison operators on project files
   # Usage: bash qc_check.sh

   MANIFEST="ABI_summer_school_project/raw_data/sample_manifest.tsv"

   # Extract organism and read length for SAMPLE_001 from the manifest
   ORGANISM=$(grep "SAMPLE_001" "$MANIFEST" | cut -f2)
   READ_LENGTH=$(grep "SAMPLE_001" "$MANIFEST" | cut -f6)

   echo "Checking quality metrics for SAMPLE_001..."

   # 1. String comparison: Check organism
   if [ "$ORGANISM" == "Plasmodium_falciparum" ]; then
       echo "Organism Check:    [PASS] Target parasite ($ORGANISM)."
   else
       echo "Organism Check:    [FAIL] Non-target organism ($ORGANISM)."
   fi

   # 2. Numeric comparison: Check read length
   if [ "$READ_LENGTH" -ge 150 ]; then
       echo "Read Length Check: [PASS] $READ_LENGTH bp meets minimum threshold (>= 150 bp)."
   else
       echo "Read Length Check: [FAIL] $READ_LENGTH bp is too short!"
   fi
   ```
3. Save and exit `nano` (`Ctrl+O`, `Enter`, `Ctrl+X`).
4. Run the script:
   ```bash
   bash qc_check.sh
   ```

---

### 3. File Test Operators
Before processing a file, your script should always verify that the file exists to prevent pipeline crashes!

| Operator | Evaluates to True if: |
| :--- | :--- |
| `-e FILE` | The file or directory **e**xists |
| `-f FILE` | It is a regular **f**ile |
| `-d DIR` | It is a **d**irectory |
| `-s FILE` | The file exists and is not empty (**s**ize > 0) |

#### Example Script: Validating Input Directories & Files (`validate_inputs.sh`)

> **Scenario:** Before starting an alignment pipeline, check whether the `raw_data/` directory and `sample_manifest.tsv` exists.

```bash
#!/bin/bash
# Demonstrating file test operators (-d, -f)
DATA_DIR="ABI_summer_school_project/raw_data"
MANIFEST="ABI_summer_school_project/raw_data/sample_manifest.tsv"

# Check if directory exists
if [ -d "$DATA_DIR" ]; then
    echo "Raw data directory is present."
fi

# Check if file exists
if [ -f "$MANIFEST" ]; then
    echo "Manifest file exists."
fi
```

---

### 4. Logical Operators (AND / OR / NOT)
* **AND (`&&` / `-a`):** True only if *both* conditions are true.
* **OR (`||` / `-o`):** True if *at least one* condition is true.
* **NOT (`!`):** Inverts the result (e.g. `[ ! -f "$FILE" ]` means "if file does NOT exist").

---

### Practical 4: Logic & File Testing (`check_sample.sh`)

::: {.callout-note}
## Challenge Scenario
Before launching a pipeline, you need to perform safety checks:
1. **AND (`&&`):** Both the input directory AND the primary sample file must exist.
2. **OR (`||`):** Check if either `SAMPLE_001` OR `SAMPLE_002` is missing.
3. **NOT (`!`):** Check if the output folder `results/` does NOT exist, and create it.
:::

1. Open `check_sample.sh`:
   ```bash
   nano check_sample.sh
   ```
2. Type the following code:
   ```bash
   #!/bin/bash
   # ---description----
   # Verifies directories and files using logical operators (&&, ||, !)
   # Usage: bash check_sample.sh

   DIR="ABI_summer_school_project/raw_data"
   FILE1="ABI_summer_school_project/raw_data/SAMPLE_001.fastq"
   FILE2="ABI_summer_school_project/raw_data/SAMPLE_002.fastq"
   OUT_DIR="ABI_summer_school_project/results"

   echo "=== Quick Check ==="

   # 1. Logical AND (&&): Directory AND sample file must both exist
   if [ -d "$DIR" ] && [ -f "$FILE1" ]; then
       echo "Check 1 (AND): [PASS] Raw data folder and SAMPLE_001 are both present."
   else
       echo "Check 1 (AND): [FAIL] Missing directory or primary sample file!"
   fi

   # 2. Logical OR (||): Alert if either file 1 OR file 2 is missing
   if [ ! -f "$FILE1" ] || [ ! -f "$FILE2" ]; then
       echo "Check 2 (OR):  [FAIL] Missing one or both required sample files!"
   else
       echo "Check 2 (OR):  [PASS] Both SAMPLE_001 and SAMPLE_002 are present."
   fi

   # 3. Logical NOT (!): Check if output results folder does NOT exist
   if [ ! -d "$OUT_DIR" ]; then
       echo "Check 3 (NOT): Results directory does not exist. Creating $OUT_DIR..."
       mkdir -p "$OUT_DIR"
   else
       echo "Check 3 (NOT): [PASS] Results directory already exists."
   fi

   echo "================================="
   ```
3. Save, exit `nano` (`Ctrl+O`, `Enter`, `Ctrl+X`), and run:
   ```bash
   bash check_sample.sh
   ```

---

### Practical Exercise: Age Classifier

Now it's your turn to write an `if/elif/else` logic chain from scratch!

**Task Instructions:**
1. Create a script called `age_classifier.sh`.
2. Use `read -p "Enter your age: " AGE` to ask the user for their age.
3. Write an `if/elif/else` block that categorizes the user:
   * Less than 13: `"You are a child"`
   * 13 to 19 (inclusive): `"You are a teenager"`
   * 20 to 35 (inclusive): `"You are a youth"`
   * 36 to 55 (inclusive): `"You are an adult"`
   * Greater than 55: `"You are an elder"`

*(Hint: Use `-lt`, `-ge`, `-le`, and combine them with `-a` or `&&`).*

Test your script with values: `10`, `16`, `27`, `42`, and `65`.

---

## Part 5: Automation (Loops)

Loops allow your script to repeat the same set of analysis commands across dozens or hundreds of sample files automatically.

---

### 1. The `for` Loop

A `for` loop iterates over a list of items. For each item in the list, it runs the code block once.

#### Looping Over Static Lists & Brace Expansion `{1..N}`:
```bash
# Loop over a list of words:
for ORGANISM in "Plasmodium" "Anopheles" "Human"; do
    echo "Analyzing: $ORGANISM"
done

# Loop over numbers using brace expansion:
for i in {1..5}; do
    echo "Processing batch $i..."
done
```

---

### 2. Looping Over Files with Command Substitution

In real bioinformatics workflows, sample IDs are often listed in a text file. We can combine Command Substitution with a `for` loop to construct dynamic file paths:

1. Open `string_loop.sh`:
   ```bash
   nano string_loop.sh
   ```
2. Type the following code:
   ```bash
   #!/bin/bash
   # ---description----
   # Reads sample IDs from a file and dynamically builds input/output paths
   # Usage: bash string_loop.sh

   # Read sample names from batch file using command substitution
   SAMPLES=$(cat ABI_summer_school_project/raw_data/batch1_samples.txt)

   for SAMPLE in $SAMPLES; do
       INPUT="ABI_summer_school_project/raw_data/${SAMPLE}.fastq"
       OUTPUT="ABI_summer_school_project/results/${SAMPLE}_aligned.sam"
       
       echo "Aligning ${INPUT} -> Output: ${OUTPUT}"
   done
   ```
3. Save, exit `nano`, and run:
   ```bash
   bash string_loop.sh
   ```

---

### 3. The `while` Loop with a Counter

A `while` loop continues executing as long as its condition remains true. It is commonly used with counter variables or polling jobs:

```bash
#!/bin/bash
COUNT=1
while [ $COUNT -le 3 ]; do
    echo "Processing iteration $COUNT..."
    ((COUNT++))   # Increment counter to prevent an infinite loop!
done
```

#### Example Scenario: Monitoring a Job with a `while` Loop

> **Scenario:** Let's say you submitted an alignment job and want a script that polls the process every second until 5 checks are completed:

```bash
#!/bin/bash
# Simulating job monitoring with a while loop
ATTEMPT=1
MAX_ATTEMPTS=5

echo "Monitoring background alignment job..."
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "Check $ATTEMPT of $MAX_ATTEMPTS: Job still running..."
    sleep 1
    ((ATTEMPT++))
done
echo "Job completed successfully!"
```

---

### 4. Loop Flow Control: `break` & `continue`

* **`continue`:** Instantly stops the current iteration and jumps to the next item (perfect for skipping missing or corrupted files).
* **`break`:** Instantly terminates the loop completely.

```bash
# Example skipping missing files with continue:
for i in {1..5}; do
    FILE="ABI_summer_school_project/raw_data/SAMPLE_00${i}.fastq"
    if [ ! -f "$FILE" ]; then
        echo "WARNING: $FILE is missing! Skipping..."
        continue
    fi
    echo "Processing $FILE..."
done
```

---

## Part 6: Comprehensive Final Pipeline

Let's integrate Variables, Positional Arguments, Arithmetic Counters, If File Tests, and Loops into a complete, robust sample processing pipeline!

::: {.callout-important}
## 5-Minute Challenge: Build a Batch FASTQ Quality Inspector!

**Objective:** Write a batch script called `pipeline.sh` that iterates through samples `1` to `3` in `ABI_summer_school_project/raw_data/` and performs the following tasks:
1. Check if a sample exists. If missing, log a warning, increment count, and skip to the next iteration using `continue`.
2. If the file is present, count total lines using command substitution.
3. Calculate total reads by dividing lines by 4.
4. Print an `[OK]` status message and increment count.
5. Display a final summary of total processed and skipped samples.
:::

1. Open `pipeline.sh`:
   ```bash
   nano pipeline.sh
   ```
2. Type the following code:
   ```bash
   #!/bin/bash
   # ---description----
   # Automated bioinformatics batch processing pipeline
   # Usage: bash pipeline.sh

   PROCESSED_COUNT=0
   SKIPPED_COUNT=0

   echo "=================================================="
   echo "STARTING BIOINFORMATICS BATCH PIPELINE"
   echo "=================================================="

   # Loop over three sample fastq files
   for ID in {1..3}; do
       FILE="ABI_summer_school_project/raw_data/SAMPLE_00${ID}.fastq"
       
       # Test if file exists
       if [ ! -f "$FILE" ]; then
           echo -e "[\e[31mSKIPPED\e[0m]\t$FILE not found."
           ((SKIPPED_COUNT++))
           continue
       fi
       
       # Count lines using command substitution
       TOTAL_LINES=$(cat "$FILE" | wc -l)
       TOTAL_READS=$((TOTAL_LINES / 4))  # FASTQ format has 4 lines per read
       
       echo -e "[\e[32mOK\e[0m]\tProcessing $FILE ($TOTAL_READS reads)..."
       ((PROCESSED_COUNT++))
   done

   echo "=================================================="
   echo "PIPELINE SUMMARY"
   echo "=================================================="
   echo "Samples Successfully Processed: $PROCESSED_COUNT"
   echo "Samples Skipped:                $SKIPPED_COUNT"
   echo "=================================================="
   ```
3. Save, exit `nano`, and run:
   ```bash
   bash pipeline.sh
   ```

---

*ABI Summer School 2026 · Module 1: Linux & HPC*

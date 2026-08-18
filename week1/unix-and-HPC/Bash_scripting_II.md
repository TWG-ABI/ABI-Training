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

### Practical 1: The TSV Generator

::: {.callout-note}
## Challenge Task
Write a script called `generate_tsv.sh` in your `scripts/` directory that creates a new file called `mock_metadata.tsv` containing the following exact output:

```text
SampleID	Treatment	Status
SAMPLE_001	Drug_A		Pass

```

*(Hint: Do not just write multiple echo lines. Try to use a single `echo` command with the correct flag and escape sequences (`\t` and `\n`) to generate the columns and rows!)*
:::

::: {.callout-tip collapse="true"}
## Show Answer

1. Open a new file called `generate_tsv.sh`:

   ```bash
   nano scripts/generate_tsv.sh

   ```
2. Type the following code:

   ```bash
   #!/bin/bash
   # ---description----
   # Demonstrating escape sequences by generating a TSV file
   
   # Use \t for columns and \n for new rows
   echo -e "SampleID\tTreatment\tStatus\nSAMPLE_001\tDrug_A\t\tPass" > mock_metadata.tsv

   ```
3. Save, exit `nano`, and run the script:

   ```bash
   bash generate_tsv.sh
   
   # Verify the TSV was created properly!
   cat mock_metadata.tsv

   ```

*(Note: We used two tabs `\t\t` before "Pass" so that the columns visually align perfectly in the terminal since "Drug_A" is a short word. For a true machine-readable TSV loaded into Python or R, you would only use a single tab per column!)*
:::

---

## Part 2: Command Substitution, Positional Arguments and Arithmetic in Bash

Before building automated pipelines, our scripts must be able to dynamically capture information from various sources:
1. **The Terminal Command Line** (Positional Arguments passed when launching the script)
2. **Other Linux Commands** (Command Substitution capturing live output)

---

### 1. Command Substitution (`$()`)
* By wrapping a command inside `$(...)`, Linux executes that command first, captures its Standard Output, and substitutes that result into your variable.
*(Historical note: Older scripts used backticks `` `command` ``, but `$()` is the modern standard because it is cleaner and can be easily nested).*
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
---

### Practical 2: Counting Lines with Dynamic Arguments

Let's see Command Substitution and Positional Arguments working together.
::: {.callout-note}
## Challenge Task
Write a script called `file_report.sh` that takes two files as positional arguments: a FASTQ file (`$1`) and a manifest file (`$2`). 

Your script should:
1. Print the total count of arguments provided and the arguments themselves.
2. Use Command Substitution to calculate the total number of lines in the FASTQ file (`$1`).
3. Use Command Substitution to search the manifest file (`$2`) and extract the metadata row specifically for `"SAMPLE_001"`.
4. Output a clean report matching the example below.
:::

::: {.callout-tip collapse="true"}
## Show Answer

1. Open a new file `file_report.sh`:

   ```bash
   nano file_report.sh

   ```
2. Type the following code:

   ```bash
   #!/bin/bash
   # ---description----
   # Generates a metadata report using positional arguments and command substitution
   
   echo "Total arguments provided: $#"
   echo "Arguments received: $@"
   echo ""
   echo "--- Sample Report ---"
   
   # Use command substitution to capture the metrics
   LINES=$(cat $1 | wc -l)
   METADATA=$(grep "SAMPLE_001" $2)
   
   echo "FASTQ Lines: $LINES"
   echo "Manifest Metadata: $METADATA"
   echo "---------------------"

   ```
3. Save, exit `nano`, and test the script using two files from your project folder:

   ```bash
   bash file_report.sh SAMPLE_001.fastq sample_manifest.tsv

   ```
:::

---

### 3. Arithmetic in Bash

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
## Challenge Task
Write a script `arithmetic.sh` that calculates basic mathematical metrics (sum, product, division) and dynamically increments step counters.
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

## Part 3: Decision Making

Bioinformatics pipelines need to make intelligent decisions based on quality thresholds or file presence. We control script execution flow using `if` statements.

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

#### Example Script: Using If/Else with Arithmetic

> **Scenario:** We want to calculate the failure rate of a server job queue. If the failure rate is greater than 0, we alert the user.

1. Open `check_jobs.sh`:

   ```bash
   nano check_jobs.sh

   ```
2. Type the following code:

   ```bash
   #!/bin/bash
   # ---description----
   # Demonstrates if/else logic and arithmetic calculations
   
   TOTAL_JOBS=200
   FAILED_JOBS=10
   
   # Calculate failure percentage using $(( ))
   FAIL_RATE=$(( (FAILED_JOBS * 100) / TOTAL_JOBS ))
   
   echo -e "\e[103mJob Failure Rate: $FAIL_RATE%\e[0m"
   
   # Check if failure rate is exactly 0
   if [ "$FAIL_RATE" == "0" ]; then
       echo -e "\e[32m[OK] All jobs completed successfully.\e[0m"
   else
       echo -e "\e[31m[ALERT] Some jobs failed. Please review the error logs!\e[0m"
   fi

   ```
3. Save, exit `nano`, and run:

   ```bash
   bash check_jobs.sh

   ```

*(Note on Terminal Colors: `\e[32m` turns the text green, `\e[31m` turns it red, and `\e[103m` adds a yellow background! We put `\e[0m` at the very end to reset the formatting so your terminal prompt doesn't stay colored. The `-e` flag inside `echo` is required to activate these special formatting codes.)*

#### ANSI Color Reference Table

| Color | Foreground (Text) | Background | Bright Text | Bright Background |
| :--- | :--- | :--- | :--- | :--- |
| **Red** | `31` | `41` | `91` | `101` |
| **Green** | `32` | `42` | `92` | `102` |
| **Yellow** | `33` | `43` | `93` | `103` |

*Syntax example: `\e[31m` (Red text), `\e[103m` (Bright Yellow background).*

---

### 2. File Test Operators
Before processing a file, your script should always verify that the file exists to prevent pipeline crashes!

| Operator | Evaluates to True if: |
| :--- | :--- |
| `-e FILE` | The file or directory **e**xists |
| `-f FILE` | It is a regular **f**ile |
| `-d DIR` | It is a **d**irectory |
| `-s FILE` | The file exists and is not empty (**s**ize > 0) |

#### Example Script: Validating Input Directories & Files (`validate_inputs.sh`)

> **Task:** Check whether the `raw_data/` directory and `sample_manifest.tsv` exists.

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

### 3. Logical Operators (AND / OR / NOT)
* **AND (`&&` / `-a`):** True only if *both* conditions are true.
* **OR (`||` / `-o`):** True if *at least one* condition is true.
* **NOT (`!`):** Inverts the result (e.g. `[ ! -f "$FILE" ]` means "if file does NOT exist").

---

### Practical Exercise: Age Classifier

Now it's your turn to write a decision logic chain from scratch!

::: {.callout-note}
## Challenge Task
1. Create a script called `age_classifier.sh`.
2. Prompt the user to enter their age interactively.
3. Write a classifier that categorizes the user based on their age as:
   * **Invalid:** If the age is less than `0` OR greater than `120`: `"Invalid age entered"`
   * **Child:** If the age is NOT greater than or equal to `13`: `"You are a child"`
   * **Teenager:** Between `13` and `19`: `"You are a teenager"`
   * **Youth:** Between `20` and `35`: `"You are a youth"`
   * **Adult:** Between `36` and `55`: `"You are an adult"`
   * **Elder:** Greater than `55`: `"You are an elder"`


Test your script with values: `-5`, `10`, `16`, `27`, `42`, `65`, and `150`.
:::

---

### 4. The `case` Statement

When you have a variable that could match many specific strings or numbers (like a menu selection or file extension), writing a long chain of `elif` statements becomes messy. The `case` statement offers a much cleaner way to handle multiple exact matches.

::: {.callout-tip}
## Syntax Rule for `case`
Each matching block ends with a double semicolon `;;`. The entire case statement is closed backward with `esac`. The asterisk `*)` acts as the "catch-all" or default fallback (like an `else` statement).
:::

#### Example Script: The Interactive Pipeline Menu (`menu.sh`)

> **Scenario:** Let's create an interactive menu for a bioinformatics toolbelt where the user selects a pipeline to run.

1. Open `menu.sh`:

   ```bash
   nano menu.sh

   ```
2. Type the following code:

   ```bash
   #!/bin/bash
   # ---description----
   # Demonstrating the case statement for building menus
   # Usage: bash menu.sh
   
   echo "============================"
   echo "    PIPELINE LAUNCHER       "
   echo "============================"
   echo "1. Run Quality Control"
   echo "2. Run Alignment"
   echo "3. Run Variant Calling"
   echo "============================"
   
   read -p "Enter your choice (1/2/3): " CHOICE
   
   case $CHOICE in
       1)
           echo "Starting FastQC module..."
           ;;
       2)
           echo "Starting BWA Alignment..."
           ;;
       3)
           echo "Starting GATK Variant Calling..."
           ;;
       *)
           echo "Error: Invalid choice! Please select 1, 2, or 3."
           ;;
   esac

   ```
3. Save, exit `nano` (`Ctrl+O`, `Enter`, `Ctrl+X`), and run:

   ```bash
   bash menu.sh

   ```

---

## Part 4: Automation (Loops)

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

```bash
# Example stopping the loop if a critical condition is met with break:
for i in {1..5}; do
    echo "Running analysis on sample $i..."
    if [ "$i" -eq 3 ]; then
        echo "CRITICAL ERROR: System overload! Aborting loop."
        break
    fi
done

```

---


*ABI Summer School 2026 · Week 1: Linux & HPC*

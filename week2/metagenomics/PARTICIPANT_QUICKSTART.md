# Participant quick start (ACE)

**Materials:** `week2/metagenomics` in [TWG-ABI/ABI-Training](https://github.com/TWG-ABI/ABI-Training).  
**No database downloads.** Shared data: `/etc/ace-data/ABI-SummerSchool-26/metagenomics/`.

## Update your local copy

```bash
cd /path/to/ABI-Training
git pull origin main
```

## Folder map

| Path | Use |
|------|-----|
| `lectures/` | PDF slides |
| `practicals/` | Read these Markdown guides |
| `scripts/` | Run these on the cluster |
| `course_env.sh` | `source` for shared DB paths |

## Every session

```bash
source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
cd /path/to/ABI-Training/week2/metagenomics
```

## Day 3 — shotgun

**Read:** `practicals/day3_shotgun-metagenomics.md`  

**Preferred (step-by-step):**

```bash
sbatch scripts/01_raw_qc.sh          # wait / check MultiQC
sbatch scripts/02_qc-trim.sh
sbatch scripts/03_host-read_removal.sh
sbatch scripts/04_kraken2.sh
sbatch scripts/05_species_abundance.sh
sbatch scripts/06_assembly.sh
# optional: DEMO_SAMPLE=SRR27027504 sbatch scripts/06_assembly.sh
```

**Optional all-in-one:** `sbatch scripts/sbatch_day3.sh` (or `bash scripts/day3_shotgun.sh`)

Outputs: `${COURSE_WORK_DIR}/day3_results/` (`01_qc` … `06_quast`)  
Note an assembled sample under `06_assembly/<SAMPLE>/` for Day 4.

## Day 4 — MAGs

**Read:** `practicals/day4_metagenome-assembled-genomes.md`  
**Run:**

```bash
bash scripts/day4_mags.sh
# or: sbatch scripts/sbatch_day4.sh
# DEMO_SAMPLE=SRR27027504 bash scripts/day4_mags.sh
```

Outputs: `${COURSE_WORK_DIR}/day4_results/`

## Day 5 — function

**Read:** `practicals/day5_functional-analysis.md`  
**Plots:** `practicals/day5_functional-analysis-visualisation.md`  
**Run:**

```bash
# module load q2-humann3/...   # if needed
bash scripts/day5_functional.sh
# or: sbatch scripts/sbatch_day5.sh
```

Outputs: `${COURSE_WORK_DIR}/day5_results/`

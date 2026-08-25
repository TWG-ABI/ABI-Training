# ABI Summer School: Metagenomics Analysis Practicals

Week 2 materials in [TWG-ABI/ABI-Training](https://github.com/TWG-ABI/ABI-Training) — `week2/metagenomics/`.

## What this is

A 5-day course (amplicon → shotgun → MAGs → function) with three layers:

| Folder | Contents |
|--------|----------|
| `lectures/` | Slide decks as **PDF** (open anywhere; no PowerPoint required) |
| `practicals/` | Annotated teaching Markdown (*what* / *why*) |
| `scripts/` | Runnable `.sh` (and later `.R` / `.Rmd`) for ACE |

Plus root helpers: `course_env.sh`, `PARTICIPANT_QUICKSTART.md`, `README.md`.

## Directory layout

```
week2/metagenomics/
├── README.md
├── PARTICIPANT_QUICKSTART.md
├── course_env.sh                 # source this on ACE (no #SBATCH here)
├── .gitignore                    # ignores *.pptx
├── lectures/
│   ├── Day1_Foundations_Amplicon.pdf
│   ├── Day2_Diversity_Analysis.pdf
│   ├── Day3_Shotgun_Assembly.pdf
│   ├── Day4_MAGs.pdf
│   └── Day5_Functional_Analysis.pdf
├── practicals/
│   ├── day1_qc.md
│   ├── day1_qiime2-amplicon.md
│   ├── day2_diversity-analysis.md
│   ├── day3_shotgun-metagenomics.md
│   ├── day4_metagenome-assembled-genomes.md
│   ├── day5_functional-analysis.md
│   ├── day5_functional-analysis-visualisation.md
│   └── data-overview.md          # dataset provenance (not a download task)
└── scripts/
    ├── 01_raw_qc.sh … 06_assembly.sh   # Day 3 step scripts (preferred)
    ├── day3_shotgun.sh / sbatch_day3.sh  # optional all-in-one
    ├── day4_mags.sh    / sbatch_day4.sh
    └── day5_functional.sh / sbatch_day5.sh
```

**Why `practicals/`?** Matches the Kampala course wording and “hands-on lab” language. Alternatives you might see elsewhere: `tutorials/`, `labs/`, `guides/` — `practicals/` is the clearest for this summer school.

Editable `.pptx` stay on instructors’ machines (gitignored); publish PDFs only.

## Contents by day

| Day | Lecture | Practical(s) | Script |
|-----|---------|--------------|--------|
| 1 | `lectures/Day1_…pdf` | `practicals/day1_qc.md`, `day1_qiime2-amplicon.md` | — |
| 2 | `lectures/Day2_…pdf` | `practicals/day2_diversity-analysis.md` | R in the Markdown (extract to `scripts/` later if useful) |
| 3 | `lectures/Day3_…pdf` | `practicals/day3_shotgun-metagenomics.md` | `scripts/01_…`–`06_….sh` (or all-in-one) |
| 4 | `lectures/Day4_…pdf` | `practicals/day4_metagenome-assembled-genomes.md` | `scripts/day4_mags.sh` |
| 5 | `lectures/Day5_…pdf` | `practicals/day5_functional-analysis.md` (+ visualisation) | `scripts/day5_functional.sh` |

## How participants update a local clone

```bash
cd /path/to/ABI-Training
git pull origin main
```

## Shared environment (ACE)

```bash
source /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
# or from this folder: source ./course_env.sh
```

Put the same `source` **inside** every `#SBATCH` job after the SLURM headers.  
Write outputs under `${COURSE_WORK_DIR}` — never into shared `COURSE_DBS`.

See **`PARTICIPANT_QUICKSTART.md`** for Day 3–5 run commands.

## Instructor: stage `course_env.sh` on ACE

```bash
cp course_env.sh /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
chmod a+rX /etc/ace-data/ABI-SummerSchool-26/metagenomics/course_env.sh
```

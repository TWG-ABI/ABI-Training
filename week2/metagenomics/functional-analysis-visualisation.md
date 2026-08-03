# Day 5 Practical — Part 2: Functional Analysis Visualisation & Mini-Project

## Purpose

Part 1 of Day 5 generated raw functional annotation outputs (Prokka, eggNOG-mapper,
HUMAnN3, AMR screening). This notebook turns those outputs into interpretable figures —
MAG quality/taxonomy summaries, COG functional category distributions, pathway heatmaps,
and AMR gene breakdowns — and closes with a template participants adapt for their own
mini-project datasets.


## 1. MAG Quality Summary

```r
library(tidyverse)
library(ggplot2)
library(pheatmap)
library(RColorBrewer)
theme_set(theme_bw(base_size=12))
```
`tidyverse` bundles `dplyr`, `stringr`, `tidyr`, etc. used throughout for data wrangling;
`pheatmap` handles the clustered heatmaps in Sections 1 and 3.

```r
checkm_file <- "day5_results/../day4_results/checkm2/quality_report.tsv"

if (file.exists(checkm_file)) {
  checkm <- read.table(checkm_file, header=TRUE, sep="\t", stringsAsFactors=FALSE)
} else {
  set.seed(42)
  checkm <- data.frame(
    Name = paste0("bin.", 1:15),
    Completeness = c(95,92,88,78,65,55,45,35,91,85,70,60,30,25,20),
    Contamination = c(2,4,3,6,8,4,9,3,1,5,7,2,8,11,5),
    Genome_Size = runif(15, 2e6, 6e6),
    GC = runif(15, 40, 70),
    stringsAsFactors = FALSE
  )
}
```
Loads the CheckM2 quality report produced in Day 4. As with the Day 2 notebook, a
**simulated fallback** dataset (15 bins spanning high/medium/low quality, plausible genome
sizes and GC%) lets this notebook run standalone for teaching even before a student has
generated real MAGs — the hard-coded Completeness/Contamination values are deliberately
spread across all three MIMAG tiers so the resulting plots are illustrative.

```r
checkm <- checkm %>%
  mutate(
    Quality = case_when(
      Completeness >= 90 & Contamination < 5  ~ "High Quality",
      Completeness >= 50 & Contamination < 10 ~ "Medium Quality",
      TRUE ~ "Low Quality"
    ),
    Quality = factor(Quality, levels=c("High Quality","Medium Quality","Low Quality"))
  )

cat("MAG Quality Summary:\n")
print(table(checkm$Quality))
```
Re-applies the same MIMAG tier logic used in the Day 4 shell script (now in R), and prints
a quick count of bins per tier. Setting `Quality` as an ordered factor keeps tier labels in
a sensible order in all subsequent legends/plots rather than alphabetical.

```r
ggplot(checkm, aes(x=Contamination, y=Completeness, color=Quality, size=Genome_Size)) +
  geom_point(alpha=0.8) +
  geom_hline(yintercept=c(50,90), linetype=2, color="grey50", size=0.5) +
  geom_vline(xintercept=c(5,10), linetype=2, color="grey50", size=0.5) +
  scale_color_manual(values=c("High Quality"="#1A936F","Medium Quality"="#0096C7","Low Quality"="#E63946")) +
  scale_size_continuous(range=c(3,10), labels=scales::comma) +
  labs(title="MAG Quality Assessment (CheckM2)",
       subtitle="Dashed lines = MIMAG thresholds (50/90% completeness, 5/10% contamination)",
       x="Contamination (%)", y="Completeness (%)", size="Genome Size (bp)") +
  annotate("text", x=0.5, y=93, label="High Quality", ...) +
  annotate("text", x=0.5, y=53, label="Medium Quality", ...)
```
A completeness-vs-contamination scatter plot — the standard way to visualise MAG quality —
with each point sized by genome size (larger points = bigger recovered genomes) and
coloured by quality tier. The dashed reference lines mark the exact MIMAG thresholds (50%
and 90% completeness; 5% and 10% contamination), and text annotations label the
high/medium-quality regions directly on the plot so the thresholds are self-explanatory
without needing to check a legend.

### 1.2 GTDB-Tk Taxonomy Integration

```r
gtdbtk_file <- "day5_results/../day4_results/gtdbtk/gtdbtk.bac120.summary.tsv"

if (file.exists(gtdbtk_file)) {
  gtdb <- read.table(gtdbtk_file, header=TRUE, sep="\t", stringsAsFactors=FALSE)
  gtdb <- gtdb %>%
    mutate(
      Phylum = str_extract(classification, "p__[^;]+") %>%
               str_remove("p__") %>% str_trim()
    ) %>%
    select(user_genome, Phylum, classification)
} else {
  # Simulated taxonomy
  ...
}
```
GTDB-Tk's `classification` column is a single semicolon-delimited string (e.g.
`d__Bacteria;p__Proteobacteria;c__...`). `str_extract` pulls out just the phylum-level
token (`p__[^;]+` matches from `p__` up to the next semicolon), then `str_remove`/`str_trim`
strip the `p__` prefix and any surrounding whitespace, leaving a clean phylum name for
plotting. Again, a simulated fallback (6 plausible soil/environmental phyla) is provided.

```r
mag_summary <- checkm %>%
  left_join(gtdb, by=c("Name"="user_genome"))

ggplot(mag_summary %>% filter(!is.na(Phylum)),
       aes(x=Phylum, fill=Quality)) +
  geom_bar(position="stack") +
  scale_fill_manual(values=c("High Quality"="#1A936F","Medium Quality"="#0096C7","Low Quality"="#E63946")) +
  labs(title="MAG Taxonomy (GTDB-Tk) by Quality Tier", x="Phylum", y="Number of MAGs") +
  coord_flip()
```
Joins the CheckM2 quality table with GTDB-Tk taxonomy by matching bin name to
`user_genome`, then produces a stacked bar chart of MAG count per phylum, coloured by
quality tier — answering "which phyla is my sequencing/binning effort actually good at
recovering high-quality genomes from?" `coord_flip()` turns vertical bars horizontal so
long phylum names remain readable.

---

## 2. COG Category Distribution (eggNOG-mapper)

```r
eggnog_file <- "day5_results/eggnog/all_MAGs_eggnog.emapper.annotations"

if (file.exists(eggnog_file)) {
  egg <- read.table(eggnog_file, header=TRUE, sep="\t", comment.char="#",
                    stringsAsFactors=FALSE, quote="")
  cog_col <- if ("COG_category" %in% names(egg)) "COG_category" else names(egg)[grep("COG", names(egg))[1]]
  cog_data <- egg[[cog_col]]
} else {
  # Simulated COG categories
  ...
}
```
Reads the real eggNOG-mapper annotation table from Day 5 Part 1 if present. Because
eggNOG-mapper's exact column naming has varied slightly across versions, the script first
checks for an exact `COG_category` column and, failing that, searches for any column name
containing "COG" — a defensive pattern that keeps the notebook working across tool
versions. `comment.char="#"` skips the file's metadata header lines.

```r
cog_labels <- c(
  J="Translation", K="Transcription", L="DNA replication/repair",
  M="Cell wall/membrane", N="Cell motility", O="Post-translational mod.",
  ...
)

cog_counts <- table(unlist(strsplit(paste(cog_data, collapse=""), "")))
```
A single gene can be assigned *multiple* COG letters concatenated together (e.g. `"KL"`
means both Transcription and DNA replication/repair) — `strsplit(..., "")` on the
collapsed string breaks every multi-letter code back into individual single-letter
categories before tallying, so a gene annotated with two categories is correctly counted
once toward each.

```r
cog_df <- data.frame(Code=names(cog_counts), Count=as.numeric(cog_counts)) %>%
  filter(Code %in% names(cog_labels)) %>%
  mutate(
    Label = cog_labels[Code],
    Category = case_when(
      Code %in% c("J","K","L") ~ "Information Storage",
      Code %in% c("C","G","E","F","H","I","P","Q") ~ "Metabolism",
      Code %in% c("M","N","O","T","U","V","W") ~ "Cellular Processes",
      TRUE ~ "Poorly Characterized"
    )
  ) %>%
  arrange(desc(Count))
```
Maps each single-letter COG code to a human-readable label and groups codes into the four
standard high-level COG super-categories (Information Storage & Processing, Metabolism,
Cellular Processes & Signaling, Poorly Characterized) — this super-category grouping is
what colours the final bar chart, giving a functional overview at a glance rather than 20+
individual codes competing for attention.

```r
ggplot(cog_df, aes(x=reorder(Label, Count), y=Count, fill=Category)) +
  geom_bar(stat="identity") +
  scale_fill_manual(values=c("Information Storage"="#0096C7","Metabolism"="#1A936F",
                              "Cellular Processes"="#6D28D9","Poorly Characterized"="#64748B")) +
  coord_flip() +
  labs(title="COG Functional Category Distribution", x=NULL, y="Number of Genes")
```
`reorder(Label, Count)` sorts bars by gene count rather than alphabetically, so the most
abundant functional categories appear at the top once flipped — a standard, easily
scannable ranked bar chart.

---

## 3. HUMAnN3 Pathway Analysis

```r
# Simulate HUMAnN3 pathway data for multiple samples
# Replace with: read.table("day5_results/humann3/.../pathabundance.tsv", ...)

pathways <- c("PWY-6609: adenine and adenosine salvage III", ...)
samples  <- paste0("Sample_", c("Forest1","Forest2","Forest3","Agri1","Agri2","Agri3"))
land_use <- c("Forest","Forest","Forest","Agriculture","Agriculture","Agriculture")
```
**Unlike the previous sections, this block is entirely simulated** — Part 1's HUMAnN3
step only processed a single demo sample, but a pathway *comparison* needs multiple
samples across two conditions. This is explicitly a teaching stand-in: the comment tells
students exactly where to substitute a real multi-sample `pathabundance.tsv` once they
have one (e.g. from their own mini-project with forest vs agricultural soil samples).

```r
pw_mat <- matrix(
  abs(rnorm(length(pathways)*length(samples), mean=0.05, sd=0.03)) +
    outer(seq(0.01, 0.08, length.out=length(pathways)),
          c(1,1,1,2,2,2) * rnorm(length(samples), 1, 0.2)),
  nrow=length(pathways), ncol=length(samples),
  dimnames=list(str_trunc(pathways, 50), samples)
)
pw_mat[pw_mat < 0] <- 0
```
Constructs a synthetic pathway-abundance matrix with a deliberate group effect baked in:
the `outer()` term multiplies an increasing pathway-level baseline by a land-use-dependent
factor (`1` for Forest samples, `2` for Agriculture), so Agricultural samples show
systematically higher abundance for later-indexed pathways — this ensures the demo
heatmap/boxplots below actually show a visible Forest-vs-Agriculture pattern rather than
pure noise. `str_trunc(pathways, 50)` shortens the long MetaCyc pathway names for
readability in plot labels; negative values (an artefact of the random simulation) are
clipped to zero since real abundances can't be negative.

```r
ann_col <- data.frame(LandUse=land_use, row.names=samples)
ann_colors <- list(LandUse=c("Forest"="#1A936F","Agriculture"="#EA6C16"))

pheatmap(
  log10(pw_mat + 1e-5),
  annotation_col = ann_col,
  annotation_colors = ann_colors,
  cluster_rows = TRUE, cluster_cols = TRUE,
  color = colorRampPalette(c("#023E8A","white","#E63946"))(50),
  main = "KEGG Pathway Abundances — log10(CPM)\nForest vs Agricultural Soil"
)
```
Log10-transforms abundances (again with a small pseudocount to avoid `log10(0)`) and
displays a clustered heatmap with a colour-coded annotation bar marking each sample's land
use — clustering columns should visually group Forest samples together and Agriculture
samples together if the underlying (here, simulated) signal is strong enough.

### 3.2 Boxplot Comparison

```r
pw_long <- as.data.frame(pw_mat) %>%
  rownames_to_column("Pathway") %>%
  pivot_longer(-Pathway, names_to="Sample", values_to="Abundance") %>%
  mutate(LandUse = ifelse(grepl("Forest", Sample), "Forest", "Agriculture"))

top_pw <- pw_long %>%
  group_by(Pathway) %>%
  summarise(cv=sd(Abundance)/mean(Abundance)) %>%
  arrange(desc(cv)) %>%
  slice_head(n=4) %>%
  pull(Pathway)
```
Reshapes the wide pathway matrix into long format, recovers each sample's land-use group
from its name (`grepl("Forest", Sample)`), then ranks pathways by **coefficient of
variation** (SD ÷ mean) to find the 4 *most variable* pathways across all samples — a
simple, distribution-agnostic way to surface pathways most likely to differ between
groups without running a full statistical test first.

```r
pw_long %>%
  filter(Pathway %in% top_pw) %>%
  ggplot(aes(x=LandUse, y=Abundance, fill=LandUse)) +
  geom_boxplot(alpha=0.8) +
  geom_jitter(width=0.2, size=2.5, alpha=0.7) +
  facet_wrap(~Pathway, scales="free_y", ncol=2,
             labeller=labeller(Pathway=function(x) str_wrap(x, 35))) +
  scale_fill_manual(values=c("Forest"="#1A936F","Agriculture"="#EA6C16"))
```
Plots those top 4 variable pathways as faceted boxplots (with jittered points showing
individual samples), directly comparing Forest vs Agriculture abundance for each — the
same boxplot + jitter + facet pattern used for alpha diversity in the Day 2 notebook,
reused here for pathway abundances. `str_wrap` wraps long pathway names onto multiple
lines within each facet strip so they don't get truncated or overlap.

---

## 4. AMR Gene Analysis

```r
# Simulated AMR gene data (replace with RGI output)
amr_data <- data.frame(
  Gene = sample(c("tetA","blaTEM-1","aadA","sul1","qnrS","mcr-1","vanA",
                  "mecA","ermB","cmlA"), 50, replace=TRUE),
  Drug_Class = sample(c("tetracycline","beta-lactam","aminoglycoside","sulfonamide",
                        "fluoroquinolone","colistin","glycopeptide",
                        "methicillin","macrolide","phenicol"), 50, replace=TRUE),
  Mechanism = sample(c("efflux pump","enzymatic inactivation","target protection",
                       "target alteration"), 50, replace=TRUE),
  Identity = runif(50, 80, 100)
)
```
Again a simulated dataset (the comment flags exactly where to substitute real RGI output
from Day 5 Part 1) — 50 synthetic AMR gene hits spanning well-known resistance gene
families (e.g. `mecA` for methicillin resistance, `mcr-1` for colistin resistance),
each with a drug class, resistance mechanism, and a simulated sequence identity score.

```r
amr_data %>%
  count(Drug_Class, Mechanism) %>%
  ggplot(aes(x=reorder(Drug_Class, n), y=n, fill=Mechanism)) +
  geom_bar(stat="identity") +
  scale_fill_brewer(palette="Set2") +
  coord_flip() +
  labs(title="AMR Genes by Drug Class and Resistance Mechanism", x=NULL, y="Number of Genes")
```
Counts gene hits per drug-class/mechanism combination, then plots a stacked bar chart
ranked by total hits per drug class — showing not just *which* drug classes have the most
resistance genes, but *how* resistance is achieved (efflux, enzymatic inactivation, target
protection/alteration) for each.

---

## 5. Mini-Project Template

```r
eval=FALSE
```
This entire chunk is marked `eval=FALSE` — it is never executed when the notebook is
knit. It exists purely as **copy-paste scaffolding**: a condensed, commented skeleton of
the full Day 2 diversity workflow (load data → build phyloseq → alpha diversity → beta
diversity/PCoA → PERMANOVA → taxonomy bar plot → differential abundance → save figures)
that participants copy into their own mini-project notebook and uncomment/adapt with
their own file paths and grouping variable, without having to hunt back through the
earlier notebooks for the right function calls.

---

## Session Info

```r
sessionInfo()
```
Records R/package versions for reproducibility, matching the convention used in the Day 2
notebook.

---

## Notes on Simulated Data

Several sections of this notebook (HUMAnN3 pathways, AMR genes) rely entirely on
simulated data rather than a real-file fallback, since Part 1's HUMAnN3/AMR steps only
process a single demo sample or may be skipped if the relevant tool isn't installed. When
adapting this notebook for real course data, replace the `pathways`/`pw_mat` and
`amr_data` simulation blocks with `read.table()` calls against your actual
`pathabundance.tsv` and RGI/AMRFinder output files.

# Day 2 Practical: Diversity Analysis with phyloseq & vegan

**Input:** QIIME2 exports from Day 1 (`feature-table.tsv`, `taxonomy.tsv`) + sample metadata

## Purpose

Having produced ASVs and taxonomy assignments in QIIME2 (Day 1), this notebook moves into
**R** to answer the ecological questions that motivate most microbiome studies:

1. How diverse is the community *within* each sample (alpha diversity)?
2. How different are communities *between* samples/groups (beta diversity)?
3. What taxa dominate, and does composition differ by group?
4. Which specific taxa are significantly enriched or depleted between groups
   (differential abundance)?

## 1. Load Libraries & Data

```r
library(phyloseq)   # Microbiome data management
library(vegan)      # Community ecology statistics
library(ggplot2)    # Plotting
library(dplyr)      # Data manipulation
library(tidyr)      # Reshaping data
library(pheatmap)   # Heatmaps
library(ggpubr)     # Publication-quality plots
library(RColorBrewer)
library(ANCOMBC)    # Differential abundance
```
**phyloseq** is the central data structure for this whole notebook — it bundles the ASV
count table, taxonomy, sample metadata, and (optionally) a phylogenetic tree into one
object so that filtering, subsetting, and diversity calculations stay consistent across
all three. **vegan** supplies the underlying community-ecology statistics (PERMANOVA,
ordination methods). **ANCOMBC** provides a compositionally-aware differential abundance
test, which is generally preferred over naive t-tests for sparse, compositional
microbiome count data.

### 1.1 Load QIIME2 Artifacts into phyloseq

```r
DAY1_DIR <- "../day1/day1_results/qiime2/exported"
DAY2_DIR <- "day2_results/qiime2"
META_FILE <- "../day1/metadata.tsv"

otu_file <- file.path(DAY1_DIR, "feature_table/feature-table.tsv")
if (file.exists(otu_file)) {
  otu_raw <- read.table(otu_file, header = TRUE, sep = "\t",
                        skip = 1, row.names = 1, check.names = FALSE)
  OTU <- otu_table(as.matrix(otu_raw), taxa_are_rows = TRUE)
} else {
  # Demo: simulate data for practice
  ...
}
```
Reads the TSV feature table exported at the end of Day 1 (`skip = 1` because the exported
BIOM-to-TSV conversion adds a comment header line) and wraps it in phyloseq's `otu_table`
class. **Importantly, every data-loading block in this notebook has a fallback that
simulates plausible demo data** (Poisson-distributed counts, random phyla, two groups) if
the real file isn't found — this lets the notebook run end-to-end during the course even
before students have generated their own Day 1 outputs, while defaulting to the real data
once it exists.

```r
tax_file <- file.path(DAY1_DIR, "taxonomy/taxonomy.tsv")
if (file.exists(tax_file)) {
  tax_raw <- read.table(tax_file, header = TRUE, sep = "\t",
                        row.names = 1, stringsAsFactors = FALSE)
  tax_split <- do.call(rbind, strsplit(tax_raw$Taxon, "; "))
  colnames(tax_split) <- c("Kingdom","Phylum","Class","Order","Family","Genus","Species")[
    seq_len(ncol(tax_split))]
  TAX <- tax_table(as.matrix(tax_split))
  taxa_names(TAX) <- rownames(tax_raw)
}
```
SILVA-format taxonomy strings look like `k__Bacteria; p__Firmicutes; c__Clostridia; ...`
joined by `"; "`. This splits each string on that delimiter into separate rank columns
(Kingdom → Species) and assembles phyloseq's `tax_table` class, aligning row names (ASV
IDs) with the feature table.

```r
if (file.exists(META_FILE)) {
  meta_raw <- read.table(META_FILE, header = TRUE, sep = "\t",
                         row.names = 1, stringsAsFactors = FALSE)
  META <- sample_data(meta_raw)
}
```
Loads the sample metadata (e.g. group, subject ID, age group) as phyloseq's `sample_data`
class — this is what group comparisons (Healthy vs IBD in the demo) are built on.

```r
ps <- phyloseq(OTU, TAX, META)
ps
cat(sprintf("Samples: %d\n", nsamples(ps)))
cat(sprintf("Taxa:    %d\n", ntaxa(ps)))
```
Combines all three components into a single `phyloseq` object and prints a quick summary
— sample count, taxon count, and the distinct groups present — as a sanity check before
proceeding.

### 1.2 Filter & Rarefy

```r
ps_filt <- prune_samples(sample_sums(ps) >= 1000, ps)
ps_filt <- prune_taxa(taxa_sums(ps_filt) >= 5, ps_filt)
```
Two standard quality filters: drop samples with fewer than 1000 total reads (too shallow
to reliably estimate diversity), then drop ASVs with a total count under 5 across all
samples (likely sequencing noise/artifacts rather than real organisms).

```r
rarefy_depth <- min(sample_sums(ps_filt))
ps_rare <- rarefy_even_depth(ps_filt, sample.size = rarefy_depth,
                              rngseed = 42, verbose = FALSE)
```
**Rarefaction** subsamples every remaining sample down to the same sequencing depth (the
minimum depth across samples) *without replacement*, so that differences in diversity
between samples reflect real biology rather than differences in how deeply each sample
was sequenced. `rngseed = 42` makes the random subsampling reproducible. This is a
long-debated step in microbiome methodology — some newer methods prefer normalisation
over rarefaction — but it remains a widely taught baseline approach.

---

## 2. Alpha Diversity

### 2.1 Calculate Metrics

```r
alpha_div <- estimate_richness(ps_rare,
  measures = c("Observed", "Chao1", "Shannon", "Simpson"))
alpha_div$group <- sample_data(ps_rare)$group
alpha_div$Sample <- rownames(alpha_div)
```
Four complementary within-sample diversity metrics:
- **Observed** — raw ASV count (richness only, ignores evenness).
- **Chao1** — a richness *estimator* that corrects for unseen rare taxa, based on the
  number of singletons/doubletons.
- **Shannon** — entropy-based index combining richness and evenness; more sensitive to
  rare taxa than Simpson.
- **Simpson** — probability that two randomly drawn reads belong to different taxa; more
  weighted toward dominant taxa.

### 2.2 Visualise Alpha Diversity

```r
alpha_long <- alpha_div %>%
  pivot_longer(cols = c(Observed, Chao1, Shannon, Simpson),
               names_to = "Metric", values_to = "Value")

ggplot(alpha_long, aes(x = group, y = Value, fill = group)) +
  geom_boxplot(alpha = 0.8, outlier.shape = 21) +
  geom_jitter(width = 0.2, size = 2, alpha = 0.6) +
  facet_wrap(~Metric, scales = "free_y") +
  scale_fill_manual(values = c("Healthy" = "#0096C7", "IBD" = "#E63946")) +
  labs(title = "Alpha Diversity by Group", x = NULL, y = "Diversity Value")
```
Reshapes the four metrics into long format so all can be faceted into one figure.
Boxplots show group medians/quartiles, jittered points show individual samples on top
(so no data is hidden by summary statistics), and `scales = "free_y"` lets each metric use
its own y-axis range since Shannon, Simpson, Chao1, and raw counts are on very different
scales.

### 2.3 Statistical Test (Kruskal-Wallis)

```r
kw_result <- kruskal.test(Shannon ~ group, data = alpha_div)

if (length(unique(alpha_div$group)) > 2) {
  pw_result <- pairwise.wilcox.test(alpha_div$Shannon, alpha_div$group,
                                    p.adjust.method = "BH")
}
```
The **Kruskal-Wallis test** is a non-parametric alternative to ANOVA — appropriate here
because diversity indices are rarely normally distributed and sample sizes are often
small. If there are more than two groups, pairwise Wilcoxon tests follow up with
Benjamini-Hochberg (BH/FDR) correction for multiple comparisons.

---

## 3. Beta Diversity

### 3.1 Compute Distance Matrices

```r
dist_bray <- phyloseq::distance(ps_rare, method = "bray")
dist_jaccard <- phyloseq::distance(ps_rare, method = "jaccard", binary = TRUE)
# dist_wuf <- phyloseq::distance(ps_rare, method = "wunifrac")  # needs a tree
```
- **Bray-Curtis** — abundance-weighted dissimilarity; the most commonly used metric for
  compositional microbiome data.
- **Jaccard** (binary) — presence/absence only, ignoring relative abundance.
- **UniFrac** (commented out here) — incorporates phylogenetic distance between taxa;
  requires a rooted tree in the phyloseq object (produced in Day 1, Step 5), which isn't
  attached to this demo `ps_rare` object.

### 3.2 PCoA Ordination

```r
ord_pcoa <- ordinate(ps_rare, method = "PCoA", distance = dist_bray)
eig <- ord_pcoa$values$Eigenvalues
var_exp <- round(eig / sum(eig[eig > 0]) * 100, 1)

plot_ordination(ps_rare, ord_pcoa, color = "group") +
  geom_point(size = 4, alpha = 0.85) +
  stat_ellipse(aes(color = group), level = 0.95, linetype = 2) +
  labs(x = sprintf("PC1 [%.1f%%]", var_exp[1]),
       y = sprintf("PC2 [%.1f%%]", var_exp[2]))
```
**Principal Coordinates Analysis (PCoA)** projects the Bray-Curtis distance matrix into a
low-dimensional space that preserves between-sample distances as well as possible. The
percentage of variance explained by each axis (computed from eigenvalues) is reported in
the axis labels so readers can judge how much of the total community variation the plot
actually captures. 95% confidence ellipses per group give a visual sense of group
separation/overlap.

### 3.3 NMDS

```r
ord_nmds <- ordinate(ps_rare, method = "NMDS", distance = dist_bray)
cat(sprintf("NMDS Stress: %.4f\n", ord_nmds$stress))
```
**Non-metric Multidimensional Scaling (NMDS)** is an alternative ordination that
prioritises preserving the *rank order* of distances rather than their exact magnitudes —
often more robust for messy ecological data than PCoA, at the cost of not returning a
"variance explained" per axis. Instead, its goodness-of-fit is judged by **stress**: below
0.1 is a good fit, 0.1–0.2 is acceptable, above 0.2 suggests the ordination doesn't
represent the data well and more dimensions may be needed. The script's `ifelse`
directly prints that interpretation.

### 3.4 PERMANOVA

```r
perm_result <- adonis2(dist_bray ~ group, data = meta_df_vegan, permutations = 999)

disp <- betadisper(dist_bray, meta_df_vegan$group)
disp_test <- permutest(disp, permutations = 999)
```
**PERMANOVA** (`adonis2`) formally tests whether `group` explains a significant proportion
of the variance in the Bray-Curtis distance matrix — the statistical backbone behind
"do these groups have different community composition?" claims, reporting both a p-value
and an R² (effect size). Because PERMANOVA is sensitive to differences in within-group
*dispersion* (not just centroid location), **PERMDISP** (`betadisper` + `permutest`) checks
whether group variances are homogeneous — if PERMDISP is significant, a significant
PERMANOVA result could reflect unequal spread rather than a true compositional shift, so it
should be interpreted cautiously (as the script's closing message notes).

---

## 4. Taxonomy Composition

### 4.1 Phylum-Level Bar Plot

```r
ps_phylum <- tax_glom(ps_rare, taxrank = "Phylum")
ps_phylum_rel <- transform_sample_counts(ps_phylum, function(x) x / sum(x))
ps_melt <- psmelt(ps_phylum_rel)

top_phyla <- ps_melt %>%
  group_by(Phylum) %>%
  summarise(mean_abund = mean(Abundance)) %>%
  arrange(desc(mean_abund)) %>%
  slice_head(n = 10) %>%
  pull(Phylum)

ps_melt_top <- ps_melt %>%
  mutate(Phylum = ifelse(Phylum %in% top_phyla, Phylum, "Other")) %>%
  group_by(Sample, group, Phylum) %>%
  summarise(Abundance = sum(Abundance), .groups = "drop")
```
`tax_glom` collapses all ASVs sharing the same Phylum into one row (summing counts), then
`transform_sample_counts` converts raw counts to relative abundance (proportions summing
to 1 per sample) so bar heights are comparable across samples of different depth.
`psmelt` reshapes the phyloseq object into a long data frame ggplot can use directly. To
keep the plot legible, only the 10 most abundant phyla (by mean relative abundance) are
kept individually; everything else is collapsed into an "Other" category.

```r
ggplot(ps_melt_top, aes(x = Sample, y = Abundance, fill = Phylum)) +
  geom_bar(stat = "identity", width = 0.9) +
  facet_wrap(~group, scales = "free_x") +
  scale_fill_manual(values = pal)
```
A stacked bar chart of relative abundance per sample, faceted by group so compositional
differences between Healthy and IBD samples (in the demo) are visually easy to compare
side by side.

### 4.2 Heatmap of Top 30 Genera

```r
ps_genus <- tax_glom(ps_rare, taxrank = "Genus")
ps_genus_rel <- transform_sample_counts(ps_genus, function(x) x / sum(x))
top30 <- names(sort(taxa_sums(ps_genus_rel), decreasing = TRUE)[1:30])
ps_top30 <- prune_taxa(top30, ps_genus_rel)
```
Same idea as the bar plot but at genus resolution, restricted to the top 30 most abundant
genera (by summed relative abundance across all samples) — a heatmap with hundreds of
genera would be unreadable.

```r
pheatmap(
  log10(otu_mat + 1e-4),
  annotation_col = ann_col,
  annotation_colors = ann_colors,
  cluster_rows = TRUE,
  cluster_cols = TRUE,
  color = colorRampPalette(c("#023E8A", "white", "#C0392B"))(50)
)
```
Values are log10-transformed (`+ 1e-4` avoids `log10(0)` for absent taxa) because relative
abundances typically span several orders of magnitude — without the log transform, rare
but biologically interesting genera would be invisible next to a few dominant ones.
Both rows (genera) and columns (samples) are hierarchically clustered, which tends to
group samples with similar community profiles together, and a column annotation bar
colour-codes each sample by group for visual cross-reference against the clustering.

---

## 5. Differential Abundance (ANCOM-BC)

```r
ancom_res <- ancombc2(
  data = ps_filt,
  fix_formula = "group",
  p_adj_method = "BH",
  verbose = FALSE
)

res_df <- ancom_res$res %>%
  filter(!is.na(q_val)) %>%
  arrange(q_val)
```
**ANCOM-BC2** tests each taxon individually for a significant association with `group`
while explicitly correcting for the compositional nature of microbiome data (the fact
that an increase in one taxon's relative abundance mechanically forces others down, which
naive tests like a t-test on relative abundances would misinterpret as a real biological
change). Note this runs on `ps_filt` (filtered but *not* rarefied) — ANCOM-BC has its own
internal bias-correction and generally should be run on filtered raw counts rather than
rarefied data. `p_adj_method = "BH"` again applies FDR correction across the many
taxon-level tests.

```r
res_df %>%
  mutate(Significance = case_when(
    q_val < 0.001 & abs(lfc) > 1 ~ "High",
    q_val < 0.05  ~ "Moderate",
    TRUE ~ "NS"
  )) %>%
  ggplot(aes(x = lfc, y = -log10(q_val), color = Significance)) +
  geom_point(size = 2, alpha = 0.7) +
  geom_hline(yintercept = -log10(0.05), linetype = 2) +
  geom_vline(xintercept = c(-1, 1), linetype = 2)
```
A standard **volcano plot**: x-axis is effect size (log2 fold change between groups),
y-axis is statistical significance (-log10 of the adjusted p-value, so more significant
points sit higher). Dashed reference lines mark the q < 0.05 significance threshold and a
2-fold change cutoff (`|lfc| > 1` on a log2 scale), and points are colour-coded into
High/Moderate/Not Significant tiers combining both criteria — taxa in the upper-left and
upper-right corners are both strongly and significantly different between groups.

---

## 6. Session Info

```r
sessionInfo()
```
Records the exact R version and package versions used to produce the report — important
for reproducibility, since diversity/statistical results can shift subtly between package
versions (e.g. `vegan` or `ANCOMBC` updates).

---

## Discussion Questions

1. **Alpha diversity**: Are Shannon diversity values significantly different between
   groups? What does this tell us biologically?
2. **Beta diversity**: Do the samples cluster by group in the PCoA? What percentage of
   variance do PC1 and PC2 explain?
3. **PERMANOVA**: Is the grouping factor a significant driver of community composition
   (p < 0.05)? What is the R² (effect size)?
4. **Composition**: What are the top 3 phyla? Does the ratio of Firmicutes to
   Bacteroidetes differ between groups?
5. **Differential abundance**: Which taxa are most significantly enriched/depleted? What
   is their potential biological role?

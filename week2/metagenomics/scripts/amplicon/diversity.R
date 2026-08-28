# ============================================================
# CLEAR R ENVIRONMENT
# ============================================================

# Start with a clean R session by removing objects from the
# current environment. This helps prevent objects or results
# from previous analyses from affecting the current workflow.

rm(list = ls())


# ============================================================
# LOAD REQUIRED PACKAGES
# ============================================================

# Load packages required for microbiome data processing,
# ecological diversity analysis, statistical testing, data
# manipulation, and visualization.

library(ggplot2)
library(vegan)
library(ggpubr)
library(ggrepel)
library(dplyr)
library(tidyr)
library(tidyverse)
library(stringr)
library(pheatmap)
library(ANCOMBC)
library(phyloseq)
library(DESeq2)

# ============================================================
# LOAD CUSTOM FUNCTIONS
# ============================================================

# Load functions defined in the local helper-functions.R file.
# These functions are used later in the analysis, including the
# taxa_level() function for working with taxonomic levels.

source('helper-functions.R')

# ============================================================
# DEFINE INPUT AND OUTPUT PATHS
# ============================================================

# Define the locations of the QIIME2 results and metadata.
# QIIME2_DIR contains the exported feature table and taxonomy
# files, while META_FILE contains the sample metadata.

QIIME2_DIR <- "~/metagenomics/amplicon/results/diversity-analysis"
DIVERSITY_DIR <- "~/metagenomics/amplicon/results/diversity-analysis"
META_FILE <- "~/metagenomics/amplicon/results/diversity-analysis/metadata.tsv"

# ============================================================
# IMPORT FEATURE TABLE
# ============================================================

# Import the ASV feature table exported from QIIME2 and convert
# it into a phyloseq otu_table object. The feature table contains
# ASV abundances across samples, with ASVs represented as rows
# and samples as columns.

# importing the feature table
otu_file <- file.path(QIIME2_DIR, "feature-table.tsv")
otu_raw <- read.table(otu_file, header = TRUE, sep = "\t", skip = 1, row.names = 1, check.names = FALSE)
ASV <- otu_table(as.matrix(otu_raw), taxa_are_rows = TRUE)

# ============================================================
# IMPORT AND PROCESS TAXONOMIC CLASSIFICATIONS
# ============================================================

# Import the taxonomy assignments exported from QIIME2.
# The semicolon-separated taxonomy strings are split into the
# seven standard taxonomic ranks and the QIIME2 rank prefixes
# (e.g., k__, p__, g__) are removed. Missing classifications
# are represented as NA before the taxonomy is converted into
# a phyloseq tax_table object.

tax_file <- file.path(QIIME2_DIR, "taxonomy.tsv")
tax_raw <- read.table(tax_file, header = TRUE, sep = "\t", row.names = 1, stringsAsFactors = FALSE, check.names = FALSE)
tax_list <- strsplit(tax_raw$Taxon, ";\\s*")
tax_list <- lapply(tax_list, function(x) { x <- trimws(x); length(x) <- 7; x })
tax_split <- do.call(rbind, tax_list)
colnames(tax_split) <- c("Kingdom", "Phylum", "Class", "Order", "Family", "Genus", "Species")
tax_split <- apply(tax_split, 2, function(x) sub("^[dkpcofgs]__", "", x))
tax_split[tax_split == ""] <- NA
tax_split <- as.data.frame(tax_split, stringsAsFactors = FALSE)
rownames(tax_split) <- rownames(tax_raw)
TAX <- tax_table(as.matrix(tax_split))
taxa_names(TAX) <- rownames(tax_raw)

# ============================================================
# IMPORT SAMPLE METADATA
# ============================================================

# Import the sample metadata and convert it into a phyloseq
# sample_data object. Sample identifiers are used as row names
# so that the metadata can be matched to the corresponding
# samples in the feature table.

meta_raw <- read.table(META_FILE, header = TRUE, sep = "\t",row.names = 1, stringsAsFactors = FALSE)
meta_raw$group <- factor(meta_raw$group)
META <- sample_data(meta_raw)

# ============================================================
# CREATE PHYLOSEQ OBJECT
# ============================================================

# Combine the ASV abundance table, taxonomic classifications,
# and sample metadata into a single phyloseq object. This object
# provides the main data structure used for the downstream
# microbiome diversity and community composition analyses.

physeq <- phyloseq(ASV, TAX, META)
physeq

# ============================================================
# FILTERING AND RAREFACTION
# ============================================================

# The following optional steps can be used to remove samples with
# low sequencing depth, remove very low-abundance taxa, and
# rarefy the remaining samples to a common sequencing depth.
#
# These steps are currently commented out, so no filtering or
# rarefaction is performed in the current analysis. Instead,
# ps_rare is assigned directly from the original phyloseq object.

#ps_filt <- prune_samples(sample_sums(ps) >= 1000, ps)
#ps_filt <- prune_taxa(taxa_sums(ps_filt) >= 5, ps_filt)
#ps_filt
#rarefy_depth <- min(sample_sums(ps_filt))
#ps_rare <- rarefy_even_depth(ps_filt, sample.size = rarefy_depth,
#                             verbose = FALSE)

# for this demo, we did not rarefy given the small number of retained 
# reads as discussed - so to complete the workflow, we continue with 
# the original phyloseq object
ps_rare <- physeq

# ============================================================
# ALPHA DIVERSITY
# ============================================================

# Calculate within-sample diversity using four measures:
# Observed richness, Chao1 richness, Shannon diversity, and
# Simpson diversity. The resulting diversity estimates are
# combined with the disease-state grouping information and
# reshaped into long format for visualization.

# Alpha diversity  
alpha_div <- estimate_richness(ps_rare, measures = c("Observed", "Chao1", "Shannon", "Simpson"))
alpha_div$group <- sample_data(ps_rare)$group
alpha_div$Sample <- rownames(alpha_div)

alpha_long <- alpha_div %>%
  pivot_longer(cols = c(Observed, Chao1, Shannon, Simpson),
               names_to = "Metric", values_to = "Value")


# ============================================================
# VISUALIZE ALPHA DIVERSITY
# ============================================================

# Visualize the four alpha-diversity measures across disease-state
# groups using boxplots with individual samples overlaid.
# Each diversity metric is displayed in a separate facet, with
# independent y-axis scales to accommodate differences in the
# numerical ranges of the metrics.

ggplot(alpha_long, aes(group, Value, fill = group)) +
  geom_boxplot(width = 0.6, alpha = 0.75, outlier.shape = NA, colour = "black") +
  geom_jitter(aes(colour = group), width = 0.12, size = 2.2, alpha = 0.7, show.legend = FALSE) +
  facet_wrap(~Metric, scales = "free_y", nrow = 2) +
  scale_fill_manual(values = c(Exacerbation = "#D55E00", Stable = "#0072B2")) +
  scale_colour_manual(values = c(Exacerbation = "#D55E00", Stable = "#0072B2")) +
  labs(title = "Alpha Diversity by Disease State", x = NULL, y = "Diversity Value", fill = "Disease state") +
  theme_classic(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    strip.background = element_rect(fill = "grey95", colour = "black"),
    strip.text = element_text(face = "bold"),
    legend.position = "none",
    axis.text.x = element_text(face = "bold"),
    panel.spacing = unit(1.2, "lines"),
    panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.7)
  )


# ============================================================
# STATISTICAL TESTING OF ALPHA DIVERSITY
# ============================================================

# Test whether Simpson and Shannon diversity differ between the
# disease-state groups using the Kruskal-Wallis test. This is a
# non-parametric test for comparing the distributions of a
# continuous variable between groups.

# test for difference in Alpha diversity between/accross groups 
kruskal.test(Simpson ~ group, data = alpha_div)
kruskal.test(Shannon ~ group, data = alpha_div)


# ============================================================
# BETA DIVERSITY
# ============================================================

# Calculate Bray-Curtis dissimilarity between samples to quantify
# differences in microbial community composition. Alternative
# distance measures are also shown below but are currently
# commented out. Weighted UniFrac would additionally require a
# phylogenetic tree.

#### Beta diversity

# compute distance/dissimilarity metrics
dist_bray <- phyloseq::distance(ps_rare, method = "bray")
#dist_jaccard <- phyloseq::distance(ps_rare, method = "jaccard", binary = TRUE)
# dist_wuf <- phyloseq::distance(ps_rare, method = "wunifrac")  # needs a tree


# ============================================================
# PRINCIPAL COORDINATES ANALYSIS (PCoA)
# ============================================================

# Perform PCoA using the Bray-Curtis distance matrix to visualize
# similarities and differences in microbial community composition
# among samples. Eigenvalues are used to calculate the percentage
# of variation explained by each principal coordinate.

ord_pcoa <- ordinate(ps_rare, method = "PCoA", distance = dist_bray)
eig <- ord_pcoa$values$Eigenvalues
var_exp <- round(eig / sum(eig[eig > 0]) * 100, 1)

ord_df <- plot_ordination(ps_rare, ord_pcoa, justDF = TRUE)

ord_df$group <- meta_raw$group[match(
  rownames(ord_df), rownames(meta_raw)
)]

ggplot(ord_df, aes(x = Axis.1, y = Axis.2, colour = group)) +
  geom_point(size = 4, alpha = 0.85) +
  scale_colour_manual(
    values = c(
      Exacerbation = "#D55E00",
      Stable = "#0072B2"
    )
  ) +
  labs(
    title = "PCoA of Bray-Curtis Dissimilarity",
    x = sprintf("PC1 [%.1f%%]", var_exp[1]),
    y = sprintf("PC2 [%.1f%%]", var_exp[2]),
    colour = "Disease state"
  ) +
  theme_classic(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5),
    axis.title = element_text(face = "bold"),
    legend.title = element_text(face = "bold")
  )

# ============================================================
# NON-METRIC MULTIDIMENSIONAL SCALING (NMDS)
# ============================================================

# Perform NMDS using the same Bray-Curtis dissimilarity matrix.
# The resulting stress value provides an indication of how well
# the two-dimensional ordination represents the original
# community dissimilarities.

# try other ordination methods  - make corresponding ordination plots
ord_nmds <- ordinate(ps_rare, method = "NMDS", distance = dist_bray)
cat(sprintf("NMDS Stress: %.4f\n", ord_nmds$stress))


# ============================================================
# TEST FOR DIFFERENCES IN COMMUNITY COMPOSITION
# ============================================================

# Use PERMANOVA to test whether overall microbial community
# composition differs between disease-state groups.
#
# Because PERMANOVA can also be influenced by differences in
# within-group dispersion, betadisper() and permutest() are used
# to test whether the groups have significantly different
# multivariate dispersion.

# check for difference in community composition across sample groups

disp <- betadisper(dist_bray, meta_raw$group)
disp_test <- permutest(disp, permutations = 999)
disp_test

perm_result <- adonis2(dist_bray ~ group, data = meta_raw, permutations = 999)
perm_result


# ============================================================
# TEST FOR HOMOGENEITY OF DISPERSION
# ============================================================

# Repeat the multivariate dispersion analysis to explicitly assess
# whether the variability of community composition within the
# disease-state groups differs.

# test for homogenity of variance - 
disp <- betadisper(dist_bray, meta_raw$group)
disp_test <- permutest(disp, permutations = 999)
disp_test


# ============================================================
# COMMUNITY COMPOSITION AT PHYLUM LEVEL
# ============================================================

# Agglomerate ASVs at the phylum level and convert the resulting
# counts to relative abundances within each sample. The data are
# then converted to a long-format data frame for visualization.
#
# The ten most abundant phyla across samples are retained as
# individual categories, while all remaining phyla are combined
# into an "Other" category.

# community composition 
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


# ============================================================
# VISUALIZE PHYLUM-LEVEL COMMUNITY COMPOSITION
# ============================================================

# Generate stacked bar plots showing the relative abundance of
# the dominant phyla across individual samples. Samples are
# separated into panels according to disease-state group.

ggplot(ps_melt_top, aes(x = Sample, y = Abundance, fill = Phylum)) +
  geom_bar(stat = "identity", width = 0.9) +
  facet_wrap(~group, scales = "free_x") +
  theme(axis.text.x = element_text(angle = 90))+
  scale_fill_brewer(palette = 'Set2')


# ============================================================
# AGGLOMERATE ASVs AT GENUS LEVEL
# ============================================================

# The conventional phyloseq tax_glom() approach is shown below
# but is currently commented out.
#
# Instead, the taxa_level() function from the helper functions
# file is used to obtain the genus-level representation and
# retain the desired genus labels.

# ps_genus <- tax_glom(ps_rare, taxrank = "Genus")
# Let us label the agglomerated ASVs with the actual taxa labels using the taxa_level 
# taxa_level function from the microbiomeSeq package

ps_genus <- taxa_level(physeq, "Genus")


# ============================================================
# SELECT THE TOP 50 GENERA
# ============================================================

# Convert genus-level abundances to relative abundance and
# identify the 50 most abundant genera. These genera are retained
# for visualization in the heatmap.

ps_genus_rel <- transform_sample_counts(ps_genus, function(x) x / sum(x))
top50 <- names(sort(taxa_sums(ps_genus_rel), decreasing = TRUE)[1:50])
ps_top50 <- prune_taxa(top50, ps_genus_rel)


# ============================================================
# GENUS-LEVEL HEATMAP
# ============================================================

# Generate a clustered heatmap of the 50 most abundant genera.
# A log10 transformation is applied to compress the abundance
# range and make differences among taxa easier to visualize.
# A small pseudocount is added to avoid taking the logarithm of
# zero. Both taxa and samples are hierarchically clustered.

pheatmap(
  log10(t(otu_table(ps_top50))+ 1e-4),
  #annotation_col = ann_col,
  #annotation_colors = ann_colors,
  cluster_rows = TRUE,
  cluster_cols = TRUE,
  color = colorRampPalette(c("#023E8A", "white", "#C0392B"))(50)
)


# ============================================================
# DIFFERENTIAL ABUNDANCE ANALYSIS WITH DESEQ2
# ============================================================

# Convert the genus-level phyloseq object into a DESeq2 object
# using disease state as the explanatory variable. DESeq2 is
# subsequently used to model differences in genus-level counts
# between the Exacerbation and Stable groups.

# 2. Convert phyloseq object using your correct column name
diagdds <- phyloseq_to_deseq2(ps_genus, ~ group)


# ============================================================
# ESTIMATE SIZE FACTORS
# ============================================================

# Estimate sample-specific size factors using the "poscounts"
# method. This method is commonly used for sparse count data
# containing many zero values, as is typical of microbiome
# datasets.

# 3. Calculate size factors (poscounts handles zero-rich microbiome data)
diagdds <- estimateSizeFactors(diagdds, type = "poscounts")


# ============================================================
# RUN DESEQ2 DIFFERENTIAL ABUNDANCE TEST
# ============================================================

# Fit the DESeq2 model using the Wald test. The resulting model
# is used to evaluate whether the abundance of each genus differs
# between the disease-state groups.

# 4. Run the differential abundance test
diagdds <- DESeq(diagdds, test = "Wald", fitType = "parametric")


# ============================================================
# EXTRACT EXACERBATION VS STABLE RESULTS
# ============================================================

# Extract the specific contrast comparing Exacerbation against
# Stable samples. Positive log2 fold-change values indicate taxa
# with higher abundance in Exacerbation, whereas negative values
# indicate higher abundance in Stable samples.
#
# cooksCutoff = FALSE prevents DESeq2 from excluding results
# based on its Cook's distance outlier criterion.

# Extract results: Exacerbation relative to Stable
res <- results(diagdds, contrast = c("group", "Exacerbation", "Stable"), cooksCutoff = FALSE)


# ============================================================
# PREPARE DESEQ2 RESULTS
# ============================================================

# Convert the DESeq2 results to a data frame, retain taxa with
# available log2 fold-change and adjusted p-values, and assign
# each taxon a direction according to the sign of its fold change.

# Prepare results
res_df <- as.data.frame(res) %>%
  rownames_to_column("Taxon") %>%
  filter(!is.na(log2FoldChange), !is.na(padj)) %>%
  mutate(Direction = case_when(
    log2FoldChange > 0 ~ "Exacerbation",
    log2FoldChange < 0 ~ "Stable",
    TRUE ~ "Not significant"
  ))


# ============================================================
# INSPECT DIFFERENTIAL ABUNDANCE RESULTS
# ============================================================

# Display the differential abundance results ordered by adjusted
# p-value. The current code uses padj < 0.9 as the filtering
# threshold; this is retained exactly as specified in the original
# analysis script.

# ============================================================
# VOLCANO PLOT
# ============================================================

# The volcano plot below is currently commented out.
#
# If enabled, it would display log2 fold change against the
# negative log10 of the adjusted p-value. A horizontal line at
# adjusted p = 0.05 would indicate the selected significance
# threshold, while taxa meeting this threshold would be labelled.

# ============================================================
# VOLCANO PLOT 
# ============================================================

# ggplot(res_df, aes(log2FoldChange, -log10(padj), colour = Direction)) +
#   geom_point(size = 3, alpha = .8) +
#   geom_hline(yintercept = -log10(.05), linetype = "dashed") +
#   geom_vline(xintercept = 0, linetype = "dashed") +
#   geom_text_repel(data = res_df %>% filter(padj < 0.05), aes(label = Taxon), size = 3, max.overlaps = 20) +
#   scale_colour_manual(values = c(Exacerbation = "#D55E00", Stable = "#0072B2", `Not significant` = "grey70")) +
#   labs(title = "Differential Abundance: Exacerbation vs Stable", x = "Log2 Fold Change", y = expression(-log[10]("Adjusted P-value")), colour = "Higher in") +
#   theme_classic(base_size = 14)


# ============================================================
# WATERFALL PLOT
# ============================================================

# Arrange taxa according to their log2 fold change so that taxa
# enriched in Stable samples appear toward one end and taxa
# enriched in Exacerbation samples appear toward the other.
# Taxon names are converted to an ordered factor to preserve
# this ordering in the plot.

waterfall_df <- res_df %>%
  arrange(log2FoldChange) %>%
  mutate(Taxon = factor(Taxon, levels = Taxon))


# ============================================================
# VISUALIZE DIFFERENTIAL ABUNDANCE
# ============================================================

# Display genus-level log2 fold changes as bars. Positive bars
# represent higher abundance in Exacerbation, while negative
# bars represent higher abundance in Stable samples.
#
# Taxon names are displayed vertically at the zero line rather
# than as conventional x-axis labels to improve readability.

ggplot(waterfall_df, aes(Taxon, log2FoldChange, fill = Direction)) +
  geom_col() +
  geom_hline(yintercept = 0) +
  geom_text(data = subset(waterfall_df, log2FoldChange > 0), aes(y = 0, label = Taxon), angle = 90, hjust = 1.1, size = 3) +
  geom_text(data = subset(waterfall_df, log2FoldChange < 0), aes(y = 0, label = Taxon), angle = 90, hjust = -0.1, size = 3) +
  scale_fill_manual(values = c(Exacerbation = "#D55E00", Stable = "#0072B2", `Not significant` = "grey70")) +
  labs(title = "Differentially Abundant Taxa: Exacerbation vs Stable", x = NULL, y = "Log2 Fold Change", fill = "Disease state") +
  theme_classic(base_size = 14) +
  theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(), legend.position = 'right')


# ============================================================
# COMPARISON WITH OTHER DIFFERENTIAL ABUNDANCE METHODS
# ============================================================

# Use ANCOMBC and ALDEx2 for differential abundance analysis
# and compare their results to the DESeq2 results. Comparing
# multiple differential abundance approaches can help assess the
# robustness and consistency of taxa identified as differentially
# abundant across methods.

# Use ANCOMBC and ALDEx2 for differential abundance analysis and compare to DESEQ2 results

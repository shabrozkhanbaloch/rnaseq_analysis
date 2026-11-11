# ============================================================================
# plot_gene_coverage.R
# Read coverage of selected genes: wild type against mutant
# ============================================================================
# WHAT THIS SCRIPT DRAWS
#   One small plot per gene. Each plot shows the "read coverage": for every
#   position of the gene, how many reads lie on top of it. The wild type is
#   drawn in blue and the mutant without sRNA154 in orange. A gene that is
#   less active in the mutant has a lower orange mountain.
#   With the six genes in genes_to_plot.csv this is the same content as
#   Figure 3 of the paper (Prasse et al. 2017).
#
# WHICH GENES
#   The genes are listed in the table genes_to_plot.csv, next to this
#   script. To plot other genes, edit that table (it opens in Excel or any
#   text editor). You do not need to change this script.
#
# HOW TO RUN IT
#   The analysis must have been run first, because this script reads files
#   that the analysis writes. rnaseq.sh runs it as its last step. To run it
#   on its own, go into this folder first:
#     cd 02_publication_rna_seq_analysis_archaea
#     conda activate reademption
#     Rscript plot_gene_coverage.R
#
# WHAT IT WRITES
#   results/gene_coverage_wt_vs_mutant.pdf
#   results/figures/09_gene_coverage_wt_vs_mutant.png
#
# R BASICS USED BELOW
#   x <- 5              store the value 5 under the name x
#   table$column        one column of a table
#   table[rows, ]       only some rows of a table
#   f(a, b)             run the function f with the inputs a and b
#   for (i in 1:6) { }  repeat the part in { } six times, i = 1, 2, ... 6
#   # text              a note for humans, R skips it
# ============================================================================

library(ggplot2)   # the plotting package


# ----------------------------------------------------------------------------
# STEP 1 - settings and the list of genes
# ----------------------------------------------------------------------------

# The two samples to draw. Like the paper, we show one replicate per strain.
sample_wt  <- "wt_R1"
sample_mut <- "mut_R1"

# How many letters (nucleotides) to show left and right of each gene.
flank <- 150

# Read the gene table. It has three columns:
#   gene               the name to print above the plot
#   locus_tag          the gene's number in the genome annotation
#   paper_fold_change  the fold change (mutant / wild type) in the paper
genes <- read.csv("genes_to_plot.csv")


# ----------------------------------------------------------------------------
# STEP 2 - look up where each gene lies, and its fold change in our run
# ----------------------------------------------------------------------------
# The annotation file (GFF) has one row per gene. Its columns have no
# names, so R calls them V1, V2, ... We need:
#   V3 = kind of entry, V4 = start, V5 = end, V7 = strand (+ or -),
#   V9 = description, which contains the text "locus_tag=<number>".
#
# Sys.glob() finds a file from a name with "*" (= any text) in it.

annotation_file <- Sys.glob("READemption_analysis/input/*annotations/*.gff")
annotation <- read.delim(annotation_file, header = FALSE, comment.char = "#", quote = "")
annotation <- annotation[annotation$V3 == "gene", ]      # keep only the gene rows

# The DESeq2 result table of step 8 has the fold change of every gene.
deseq <- read.delim("results/deseq_comp_mut_vs_wt_with_annotation_and_countings.csv",
                    comment.char = "#", quote = "", check.names = FALSE)

# Go through our genes one by one and fill in the missing columns.
for (i in 1:nrow(genes)) {
    # The text to search for, for example ";locus_tag=MM_RS05025;"
    search_text <- paste0(";locus_tag=", genes$locus_tag[i], ";")

    # grepl() answers TRUE for every row whose description contains the text.
    row <- annotation[grepl(search_text, annotation$V9, fixed = TRUE), ]
    genes$start[i]  <- row$V4
    genes$end[i]    <- row$V5
    genes$strand[i] <- row$V7

    # DESeq2 writes the change as "log2 fold change". 2 ^ value turns it
    # into a plain fold change: 0.5 = half as active, 2 = twice as active.
    row <- deseq[grepl(search_text, deseq$Attributes, fixed = TRUE), ]
    genes$our_fold_change[i] <- 2 ^ row$log2FoldChange
}

# The title of each small plot: gene name and both fold changes.
genes$title <- sprintf("%s     fold change mutant / wild type: this run %.2f, paper %.2f",
                       genes$gene, genes$our_fold_change, genes$paper_fold_change)


# ----------------------------------------------------------------------------
# STEP 3 - read the coverage files
# ----------------------------------------------------------------------------
# Step 6 of the analysis wrote two coverage files per sample: one for reads
# on the forward strand of the DNA and one for the reverse strand. A file
# looks like this:
#     track type=wiggle_0 name="wt_R1_forward"       <- title line
#     variableStep chrom=NC_003901.1 span=1          <- name of the DNA molecule
#     137 0.5                                        <- position and coverage
#     138 0.5
# Positions that are not listed have coverage 0. On the reverse strand the
# coverage is written as a negative number.
#
# We use the "tnoar_min_normalized" files. In these, all samples are scaled
# to the same total number of reads, so they can be compared fairly.
#
# Note: this simple way of reading works because Methanosarcina mazei has
# only one DNA molecule. A genome with several chromosomes or plasmids has
# several "variableStep" lines per file and would need more care.

coverage_folder <- Sys.glob("READemption_analysis/output/*coverage-tnoar_min_normalized")

# read_coverage() reads one file and gives back a table with the columns
# "position" and "coverage". skip = 2 jumps over the first two lines.
read_coverage <- function(sample, strand) {
    file <- Sys.glob(file.path(coverage_folder, paste0(sample, "_*_", strand, ".wig")))
    table <- read.table(file, skip = 2, col.names = c("position", "coverage"))
    table$coverage <- abs(table$coverage)        # abs() removes the minus sign
    table
}

message("Reading the coverage files, this takes a moment ...")
coverage <- list(
    wt_forward  = read_coverage(sample_wt,  "forward"),
    wt_reverse  = read_coverage(sample_wt,  "reverse"),
    mut_forward = read_coverage(sample_mut, "forward"),
    mut_reverse = read_coverage(sample_mut, "reverse")
)


# ----------------------------------------------------------------------------
# STEP 4 - cut out the region of each gene
# ----------------------------------------------------------------------------
# ggplot wants one long table with one row per point to draw. We build it
# piece by piece: for every gene and both strains, one row per position
# with the columns title, strain, position and coverage.

plot_data <- data.frame()                       # an empty table to start with

for (i in 1:nrow(genes)) {
    positions <- (genes$start[i] - flank):(genes$end[i] + flank)

    # A gene on the "+" strand is read from the forward file, a gene on
    # the "-" strand from the reverse file.
    strand <- if (genes$strand[i] == "+") "forward" else "reverse"

    for (strain in c("wt", "mut")) {
        full_table <- coverage[[paste0(strain, "_", strand)]]

        # match() looks up each position of the region in the coverage
        # table. Positions that are not in the table give NA ("not
        # available"), which we replace by 0.
        values <- full_table$coverage[match(positions, full_table$position)]
        values[is.na(values)] <- 0

        piece <- data.frame(title = genes$title[i], strain = strain,
                            position = positions, coverage = values)
        plot_data <- rbind(plot_data, piece)    # rbind() adds rows to a table
    }
}

# Fix the order: genes as in the gene table, wild type before mutant.
plot_data$title  <- factor(plot_data$title, levels = genes$title)
genes$title      <- factor(genes$title,     levels = genes$title)
plot_data$strain <- factor(plot_data$strain, levels = c("wt", "mut"),
                           labels = c("wild type", "mutant (no sRNA154)"))

# A black arrow under each plot will mark the gene itself. It is drawn a
# little below zero, and points in the direction the gene is read.
for (i in 1:nrow(genes)) {
    highest <- max(plot_data$coverage[plot_data$title == genes$title[i]])
    genes$arrow_height[i] <- -0.06 * highest
    genes$arrow_from[i]   <- if (genes$strand[i] == "+") genes$start[i] else genes$end[i]
    genes$arrow_to[i]     <- if (genes$strand[i] == "+") genes$end[i]   else genes$start[i]
}


# ----------------------------------------------------------------------------
# STEP 5 - draw the figure
# ----------------------------------------------------------------------------
# A ggplot is built by adding layers with "+":
#   ggplot(...)       which table to use, and which columns go on x and y
#   geom_area()       draw filled mountains, one colour per strain
#   geom_segment()    draw the black gene arrows
#   facet_wrap()      make one small plot per gene, two next to each other;
#                     scales = "free" gives every gene its own axes
#   the rest          colours, labels and general look

figure <- ggplot(plot_data, aes(x = position, y = coverage)) +
    geom_area(aes(fill = strain), position = "identity", alpha = 0.75) +
    geom_segment(data = genes,
                 aes(x = arrow_from, xend = arrow_to, y = arrow_height, yend = arrow_height),
                 arrow = arrow(length = unit(0.08, "inches")), linewidth = 1) +
    facet_wrap(~ title, ncol = 2, scales = "free") +
    scale_fill_manual(values = c("wild type" = "#4C72B0", "mutant (no sRNA154)" = "#DD8452")) +
    labs(x = "position on the genome", y = "reads (coverage)", fill = NULL,
         caption = "Black arrow: position and reading direction of the gene") +
    theme_bw() +
    theme(legend.position = "top", strip.text = element_text(hjust = 0))

ggsave("results/gene_coverage_wt_vs_mutant.pdf", figure, width = 11, height = 10)
ggsave("results/figures/09_gene_coverage_wt_vs_mutant.png", figure,
       width = 11, height = 10, dpi = 110)


# ----------------------------------------------------------------------------
# STEP 6 - print the numbers
# ----------------------------------------------------------------------------
message("Fold changes (mutant / wild type):")
print(data.frame(gene     = genes$gene,
                 paper    = genes$paper_fold_change,
                 this_run = round(genes$our_fold_change, 2)),
      row.names = FALSE)
message("Figure written to results/gene_coverage_wt_vs_mutant.pdf")

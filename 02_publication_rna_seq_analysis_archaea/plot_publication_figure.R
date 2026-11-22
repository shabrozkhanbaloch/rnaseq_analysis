# ============================================================================
# plot_publication_figure.R
# One journal-style figure with the main results of example 02
# ============================================================================
# WHAT THIS SCRIPT DRAWS
#   One figure with three parts ("panels"), as a scientific journal prints it:
#     a  Volcano plot: every tested gene as a dot. Genes that changed are
#        coloured, and the most important ones are named.
#     b  Our fold changes against the fold changes printed in the paper,
#        for the genes of the paper's complete list (Table S1).
#     c  Read coverage over six nitrogen genes, wild type against mutant
#        (the content of the paper's Figure 3).
#
# WHY A SEPARATE FIGURE
#   The plots that READemption draws by itself are good for a first look,
#   but journals have rules: a fixed width, small sans-serif text, colours
#   that colour-blind readers can tell apart, nothing cut off. This script
#   follows those rules. It draws nothing new: every number comes from the
#   result tables of the analysis.
#
# HOW TO RUN IT
#   The analysis must have been run first. Then:
#     cd 02_publication_rna_seq_analysis_archaea
#     conda activate reademption
#     Rscript plot_publication_figure.R
#
# WHAT IT WRITES
#   results/publication_figure.pdf           for print (stays sharp at any size)
#   results/figures/10_publication_figure.png   for the web (600 dpi)
#
# OPTIONS
#   - The size of the figure is set in STEP 1 (183 mm is the width of a
#     full page in Nature; 89 mm would be one column).
#   - The genes named in panel a are listed in STEP 1.
#   - The genes of panel c come from genes_to_plot.csv, next to this script.
# ============================================================================

library(ggplot2)   # the plotting package
library(grid)      # comes with R; used to place the three panels on one page


# ----------------------------------------------------------------------------
# STEP 1 - settings
# ----------------------------------------------------------------------------

figure_width_mm  <- 183     # full page width of Nature
figure_height_mm <- 165

# When does a gene count as "changed"? The same rule as on the results page:
# padj below 0.05 and at least a two-fold change (log2 fold change of 1).
padj_limit <- 0.05
log2_limit <- 1

# Colours from the Okabe-Ito palette, which colour-blind readers can tell apart.
colour_down    <- "#0072B2"   # blue: less active in the mutant
colour_up      <- "#D55E00"   # vermillion: more active in the mutant
colour_other   <- "#BDBDBD"   # light grey: not changed
colour_wt      <- "#7F7F7F"   # grey: wild type
colour_mut     <- "#009E73"   # green: mutant

# The genes named in panel a, with the position of each name (label_x,
# label_y), chosen by hand so that no name covers a dot.
#   Less active in the mutant: the nitrogen genes of the paper's Table 1.
#     Two more genes of that table, nrpA and nifH, have no padj (see the
#     legend), so they cannot be drawn in panel a; they are in panel c.
#   More active in the mutant: the three strongest genes. Two of them have
#     no gene name, so their number in the genome annotation is printed.
named_genes <- data.frame(
    label     = c("glnA1",      "glnK1",      "glnA2",      "amtB2",      "amtB1",      "MM_RS17330", "MM_RS06595", "aroD"),
    locus_tag = c("MM_RS05025", "MM_RS03825", "MM_RS16575", "MM_RS04990", "MM_RS03830", "MM_RS17330", "MM_RS06595", "MM_RS06585"),
    label_x   = c(-2.50,        -3.55,        -0.80,        -3.00,        -2.45,        3.25,         1.75,         2.45),
    label_y   = c(71.8,         11.0,         23.0,         6.5,          3.6,          33.5,         37.5,         20.5),
    # Gene names are printed in italics, annotation numbers upright.
    style     = c("italic",     "italic",     "italic",     "italic",     "italic",     "plain",      "plain",      "italic")
)

# The two samples of panel c. Like the paper, one replicate per strain.
sample_wt  <- "wt_R1"
sample_mut <- "mut_R1"
flank <- 150       # nucleotides shown left and right of each gene

# The look shared by all panels: white background, thin black axes, 7 pt text.
journal_theme <- theme_classic(base_size = 7) +
    theme(axis.line         = element_line(linewidth = 0.3, colour = "black"),
          axis.ticks        = element_line(linewidth = 0.3, colour = "black"),
          axis.text         = element_text(size = 6, colour = "black"),
          axis.title        = element_text(size = 7),
          legend.text       = element_text(size = 6),
          legend.title      = element_blank(),
          legend.key.size   = unit(3, "mm"),
          legend.background = element_blank(),
          plot.margin       = margin(4, 4, 2, 4, "mm"))

# geom_text() wants its text size in millimetres; this turns 6 pt into mm.
text_6pt <- 6 / .pt


# ----------------------------------------------------------------------------
# STEP 2 - panel a: the volcano plot
# ----------------------------------------------------------------------------

deseq <- read.delim("results/deseq_comp_mut_vs_wt_with_annotation_and_countings.csv",
                    comment.char = "#", quote = "", check.names = FALSE)

# Pull the gene's number out of the long description column, for example
# "...;locus_tag=MM_RS05025;..." gives "MM_RS05025".
deseq$locus_tag <- sub(".*;locus_tag=([^;]+).*", "\\1", deseq$Attributes)

# Only genes with a padj can be placed on the plot.
volcano <- deseq[!is.na(deseq$padj), ]
volcano$height <- -log10(volcano$padj)

# Sort every gene into one of three groups.
volcano$group <- "other"
volcano$group[volcano$padj < padj_limit & volcano$log2FoldChange <= -log2_limit] <- "down"
volcano$group[volcano$padj < padj_limit & volcano$log2FoldChange >=  log2_limit] <- "up"
number_down <- sum(volcano$group == "down")
number_up   <- sum(volcano$group == "up")
volcano$group <- factor(volcano$group, levels = c("down", "up", "other"),
                        labels = c(paste0("less active in mutant (", number_down, ")"),
                                   paste0("more active in mutant (", number_up, ")"),
                                   "not changed"))
# Draw the grey dots first, so the coloured ones lie on top.
volcano <- volcano[order(volcano$group, decreasing = TRUE), ]

# The named genes: join the table of names with their place on the plot.
named <- merge(named_genes, volcano, by = "locus_tag")

panel_a <- ggplot(volcano, aes(x = log2FoldChange, y = height)) +
    geom_hline(yintercept = -log10(padj_limit), linetype = "dashed",
               linewidth = 0.25, colour = "grey40") +
    geom_vline(xintercept = c(-log2_limit, log2_limit), linetype = "dashed",
               linewidth = 0.25, colour = "grey40") +
    geom_point(aes(colour = group), size = 0.7, stroke = 0, alpha = 0.85) +
    geom_segment(data = named, aes(xend = label_x, yend = label_y),
                 linewidth = 0.2, colour = "black") +
    geom_point(data = named, shape = 21, size = 1.3, stroke = 0.35,
               colour = "black", fill = NA) +
    geom_label(data = named, aes(x = label_x, y = label_y, label = label, fontface = style),
               size = text_6pt, label.size = 0,
               label.padding = unit(0.6, "mm"), fill = "white") +
    scale_colour_manual(values = setNames(c(colour_down, colour_up, colour_other),
                                          levels(volcano$group))) +
    scale_x_continuous(limits = c(-4, 4), breaks = -4:4) +
    scale_y_continuous(limits = c(0, 78), expand = c(0, 0)) +
    labs(x = expression(log[2] ~ "fold change (mutant / wild type)"),
         y = expression(-log[10] ~ "adjusted " * italic(P))) +
    guides(colour = guide_legend(override.aes = list(size = 1.6, alpha = 1))) +
    journal_theme +
    theme(legend.position = "inside", legend.position.inside = c(0.98, 0.98),
          legend.justification = c(1, 1))


# ----------------------------------------------------------------------------
# STEP 3 - panel b: our fold changes against the paper's
# ----------------------------------------------------------------------------

paper <- read.csv("results/paper_comparison_table_S1.csv")
# One gene of the paper is not in today's genome annotation, so it has no
# value in our run and is left out here.
paper <- paper[!is.na(paper$our_fold_change_mut_vs_wt), ]

# The correlation, calculated on the log2 values (as on the results page).
r <- cor(log2(paper$paper_fold_change_mut_vs_wt), log2(paper$our_fold_change_mut_vs_wt))

paper$verdict <- factor(paper$verdict, levels = c("reproduced", "not reproduced"))
levels(paper$verdict) <- paste0(levels(paper$verdict), " (", table(paper$verdict), ")")

fold_ticks <- c(0.0625, 0.125, 0.25, 0.5, 1, 2, 4, 8)

panel_b <- ggplot(paper, aes(x = paper_fold_change_mut_vs_wt, y = our_fold_change_mut_vs_wt)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed",
                linewidth = 0.25, colour = "grey40") +
    geom_point(aes(shape = verdict, colour = verdict), size = 1.2, stroke = 0.4) +
    annotate("text", x = 0.0625, y = 8, hjust = 0, vjust = 1, size = text_6pt,
             label = sprintf("r = %.2f, n = %d genes", r, nrow(paper))) +
    scale_shape_manual(values = c(16, 1)) +
    scale_colour_manual(values = c("black", colour_up)) +
    scale_x_continuous(trans = "log2", breaks = fold_ticks, limits = c(0.0625, 8),
                       labels = c("1/16", "1/8", "1/4", "1/2", "1", "2", "4", "8")) +
    scale_y_continuous(trans = "log2", breaks = fold_ticks, limits = c(0.0625, 8),
                       labels = c("1/16", "1/8", "1/4", "1/2", "1", "2", "4", "8")) +
    labs(x = "fold change in the paper (mutant / wild type)",
         y = "fold change in this run (mutant / wild type)") +
    coord_fixed() +
    journal_theme +
    theme(legend.position = "inside", legend.position.inside = c(0.98, 0.02),
          legend.justification = c(1, 0))


# ----------------------------------------------------------------------------
# STEP 4 - panel c: read coverage over six nitrogen genes
# ----------------------------------------------------------------------------
# The same data as plot_gene_coverage.R, which explains every line. The one
# difference: positions are counted from the start of the gene, in the
# direction the gene is read, so every gene runs from left to right.

genes <- read.csv("genes_to_plot.csv")

annotation_file <- Sys.glob("READemption_analysis/input/*annotations/*.gff")
annotation <- read.delim(annotation_file, header = FALSE, comment.char = "#", quote = "")
annotation <- annotation[annotation$V3 == "gene", ]

for (i in 1:nrow(genes)) {
    search_text <- paste0(";locus_tag=", genes$locus_tag[i], ";")
    row <- annotation[grepl(search_text, annotation$V9, fixed = TRUE), ]
    genes$start[i]  <- row$V4
    genes$end[i]    <- row$V5
    genes$strand[i] <- row$V7
    genes$our_fold_change[i] <- 2 ^ deseq$log2FoldChange[deseq$locus_tag == genes$locus_tag[i]]
}

# The title of each small plot, written so that the gene name is printed
# in italics: fold change in this run, and in the paper.
genes$title <- sprintf('paste(bolditalic("%s"), "   %.2f (paper %.2f)")',
                       genes$gene, genes$our_fold_change, genes$paper_fold_change)

coverage_folder <- Sys.glob("READemption_analysis/output/*coverage-tnoar_min_normalized")

read_coverage <- function(sample, strand) {
    file <- Sys.glob(file.path(coverage_folder, paste0(sample, "_*_", strand, ".wig")))
    table <- read.table(file, skip = 2, col.names = c("position", "coverage"))
    table$coverage <- abs(table$coverage)
    table
}

message("Reading the coverage files, this takes a moment ...")
coverage <- list(
    wt_forward  = read_coverage(sample_wt,  "forward"),
    wt_reverse  = read_coverage(sample_wt,  "reverse"),
    mut_forward = read_coverage(sample_mut, "forward"),
    mut_reverse = read_coverage(sample_mut, "reverse")
)

plot_data <- data.frame()
for (i in 1:nrow(genes)) {
    positions <- (genes$start[i] - flank):(genes$end[i] + flank)
    forward   <- genes$strand[i] == "+"
    strand    <- if (forward) "forward" else "reverse"

    # Distance from the first letter of the gene, in reading direction.
    from_start <- if (forward) positions - genes$start[i] else genes$end[i] - positions

    for (strain in c("wt", "mut")) {
        full_table <- coverage[[paste0(strain, "_", strand)]]
        values <- full_table$coverage[match(positions, full_table$position)]
        values[is.na(values)] <- 0
        piece <- data.frame(title = genes$title[i], strain = strain,
                            position = from_start, coverage = values)
        plot_data <- rbind(plot_data, piece)
    }
}

plot_data$title  <- factor(plot_data$title, levels = genes$title)
plot_data$strain <- factor(plot_data$strain, levels = c("wt", "mut"),
                           labels = c("wild type", "mutant (no sRNA154)"))

# A black arrow under each plot marks the gene: from its first to its last letter.
for (i in 1:nrow(genes)) {
    highest <- max(plot_data$coverage[plot_data$title == genes$title[i]])
    genes$arrow_height[i] <- -0.07 * highest
    genes$length[i]       <- genes$end[i] - genes$start[i]
}
genes$title <- factor(genes$title, levels = genes$title)

panel_c <- ggplot(plot_data, aes(x = position, y = coverage)) +
    geom_area(aes(fill = strain), position = "identity", alpha = 0.7) +
    geom_segment(data = genes, aes(x = 0, xend = length, y = arrow_height, yend = arrow_height),
                 arrow = arrow(length = unit(1.2, "mm"), type = "closed"), linewidth = 0.5) +
    facet_wrap(~ title, ncol = 3, scales = "free", labeller = label_parsed) +
    scale_fill_manual(values = c("wild type" = colour_wt, "mutant (no sRNA154)" = colour_mut)) +
    scale_x_continuous(expand = c(0.02, 0)) +
    labs(x = "position from the start of the gene (nucleotides)",
         y = "read coverage (normalised)") +
    journal_theme +
    theme(legend.position   = "top",
          legend.margin     = margin(0, 0, 0, 0),
          legend.box.margin = margin(0, 0, -2, 0, "mm"),
          strip.background  = element_blank(),
          strip.text        = element_text(size = 6.5, hjust = 0, margin = margin(0, 0, 1, 0, "mm")),
          panel.spacing     = unit(3, "mm"))


# ----------------------------------------------------------------------------
# STEP 5 - put the three panels on one page and save
# ----------------------------------------------------------------------------
# viewport() marks a rectangle on the page: x and y are its lower left
# corner, width and height its size, all as a share of the page (0 to 1).
# Panels a and b share the upper part, panel c fills the lower part.

draw_figure <- function() {
    grid.newpage()
    print(panel_a, vp = viewport(x = 0,    y = 0.54, width = 0.54, height = 0.46, just = c("left", "bottom")))
    print(panel_b, vp = viewport(x = 0.54, y = 0.54, width = 0.46, height = 0.46, just = c("left", "bottom")))
    print(panel_c, vp = viewport(x = 0,    y = 0,    width = 1,    height = 0.54, just = c("left", "bottom")))

    # The panel letters, bold, as journals print them.
    letter <- gpar(fontsize = 8, fontface = "bold")
    grid.text("a", x = 0.012, y = 0.985, gp = letter)
    grid.text("b", x = 0.552, y = 0.985, gp = letter)
    grid.text("c", x = 0.012, y = 0.525, gp = letter)
}

# The PDF: sizes are given in inches, so millimetres are divided by 25.4.
pdf("results/publication_figure.pdf",
    width = figure_width_mm / 25.4, height = figure_height_mm / 25.4)
draw_figure()
invisible(dev.off())

# The PNG: 600 dots per inch, the resolution journals ask for.
png("results/figures/10_publication_figure.png",
    width = figure_width_mm, height = figure_height_mm, units = "mm", res = 600)
draw_figure()
invisible(dev.off())

message("Figure written: results/publication_figure.pdf")
message("                results/figures/10_publication_figure.png")
message(sprintf("Panel a: %d genes less active, %d more active. Panel b: r = %.2f, %d genes.",
                number_down, number_up, r, nrow(paper)))

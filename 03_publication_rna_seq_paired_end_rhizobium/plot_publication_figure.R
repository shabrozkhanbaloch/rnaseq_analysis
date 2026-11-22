# ============================================================================
# plot_publication_figure.R
# One journal-style figure with the main results of example 03
# ============================================================================
# WHAT THIS SCRIPT DRAWS
#   One figure with three parts ("panels"), as a scientific journal prints it:
#     a  Volcano plot, apigenin against control: every tested gene as a
#        dot. Genes that changed are coloured and named.
#     b  Volcano plot, salt against control, drawn the same way. The
#        nodulation (nod) genes are marked with a black ring.
#     c  Our fold changes against the fold changes printed in the paper,
#        for the nodulation genes of the paper's Tables 1 to 3.
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
#     cd 03_publication_rna_seq_paired_end_rhizobium
#     conda activate reademption
#     Rscript plot_publication_figure.R
#
# WHAT IT WRITES
#   results/publication_figure.pdf              for print (stays sharp at any size)
#   results/figures/11_publication_figure.png   for the web (600 dpi)
#
# OPTIONS
#   - The size of the figure is set in STEP 1 (183 mm is the width of a
#     full page in Nature; 89 mm would be one column).
#   - The genes named in panels a and b are listed in STEP 1.
# ============================================================================

library(ggplot2)   # the plotting package
library(grid)      # comes with R; used to place the panels on one page


# ----------------------------------------------------------------------------
# STEP 1 - settings
# ----------------------------------------------------------------------------

figure_width_mm  <- 183     # full page width of Nature
figure_height_mm <- 150

# When does a gene count as "changed"? The same rule as on the results page
# and in the paper: padj below 0.05 and at least a four-fold change (log2
# fold change of 2).
padj_limit <- 0.05
log2_limit <- 2

# Colours from the Okabe-Ito palette, which colour-blind readers can tell apart.
colour_down  <- "#0072B2"   # blue: less active than in the control
colour_up    <- "#D55E00"   # vermillion: more active than in the control
colour_other <- "#BDBDBD"   # light grey: not changed

# The genes named in the two volcano plots, with the position of each name
# (label_x, label_y), chosen by hand so that no name covers a dot.
#   Gene names (printed in italics) are the paper's names. Genes without a
#   name are printed with their number in the genome annotation, without
#   the first part "RTCIAT899_", which is the same for every gene.
named_apigenin <- data.frame(
    label     = c("nodA2", "nodB",  "nodF",  "hsnT",  "nodE",  "nodC",  "nodA1"),
    locus_tag = c("RTCIAT899_RS20545", "RTCIAT899_RS20745", "RTCIAT899_RS20555", "RTCIAT899_RS20550",
                  "RTCIAT899_RS20560", "RTCIAT899_RS20750", "RTCIAT899_RS20740"),
    label_x   = c(3.30,    2.55,    4.45,    1.95,    4.45,    1.75,    1.55),
    label_y   = c(6.29,    3.95,    3.75,    3.20,    2.45,    2.50,    1.85),
    style     = "italic"
)
named_salt <- data.frame(
    label     = c("RS20960", "RS02515", "nodC",  "nodB",  "nodU",  "RS27050", "RS27025"),
    locus_tag = c("RTCIAT899_RS20960", "RTCIAT899_RS02515", "RTCIAT899_RS20750", "RTCIAT899_RS20745",
                  "RTCIAT899_RS20760", "RTCIAT899_RS27050", "RTCIAT899_RS27025"),
    label_x   = c(4.05,      3.20,      2.95,    2.60,    2.30,    -4.15,     -4.25),
    label_y   = c(9.70,      9.00,      7.60,    6.50,    5.50,    5.40,      3.90),
    style     = c("plain",   "plain",   "italic", "italic", "italic", "plain", "plain")
)

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
          plot.title        = element_text(size = 7, hjust = 0.5),
          plot.margin       = margin(4, 4, 2, 4, "mm"))

# geom_text() wants its text size in millimetres; this turns 6 pt into mm.
text_6pt <- 6 / .pt


# ----------------------------------------------------------------------------
# STEP 2 - the comparison table with the paper
# ----------------------------------------------------------------------------
# It is needed twice: to know which genes are nodulation genes (panel b),
# and for the comparison itself (panel c).

paper <- read.csv("results/paper_comparison_nod_genes.csv")

# The genes whose name starts with "nod", plus hsnT, which belongs to them.
nod_genes <- paper$locus_tag_now[grepl("^nod", paper$gene) | paper$gene == "hsnT"]


# ----------------------------------------------------------------------------
# STEP 3 - panels a and b: the two volcano plots
# ----------------------------------------------------------------------------
# Both plots are drawn the same way, so the drawing is written once, as a
# function: draw_volcano(condition, named genes, show the nod rings or not).

draw_volcano <- function(condition, named_genes, mark_nod_genes) {
    file  <- sprintf("results/deseq_comp_%s_vs_control_with_annotation_and_countings.csv", condition)
    deseq <- read.delim(file, comment.char = "#", quote = "", check.names = FALSE)

    # Pull the gene's number out of the long description column, for example
    # "...;locus_tag=RTCIAT899_RS20545;..." gives "RTCIAT899_RS20545".
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
    message(sprintf("%s: %d genes tested, %d more active, %d less active",
                    condition, nrow(volcano), number_up, number_down))

    volcano$group <- factor(volcano$group, levels = c("up", "down", "other"),
                            labels = c(paste0("more active (", number_up, ")"),
                                       paste0("less active (", number_down, ")"),
                                       "not changed"))
    # Draw the grey dots first, so the coloured ones lie on top.
    volcano <- volcano[order(volcano$group, decreasing = TRUE), ]

    named <- merge(named_genes, volcano, by = "locus_tag")
    # The nod genes that changed get a black ring (only where asked for).
    ringed <- volcano[volcano$locus_tag %in% nod_genes & volcano$group != "not changed", ]
    if (!mark_nod_genes) ringed <- named

    ggplot(volcano, aes(x = log2FoldChange, y = height)) +
        geom_hline(yintercept = -log10(padj_limit), linetype = "dashed",
                   linewidth = 0.25, colour = "grey40") +
        geom_vline(xintercept = c(-log2_limit, log2_limit), linetype = "dashed",
                   linewidth = 0.25, colour = "grey40") +
        # show.legend = TRUE keeps a group in the legend even when it has no gene.
        geom_point(aes(colour = group), size = 0.7, stroke = 0, alpha = 0.85, show.legend = TRUE) +
        geom_segment(data = named, aes(xend = label_x, yend = label_y),
                     linewidth = 0.2, colour = "black") +
        geom_point(data = ringed, shape = 21, size = 1.3, stroke = 0.35,
                   colour = "black", fill = NA) +
        geom_label(data = named, aes(x = label_x, y = label_y, label = label, fontface = style),
                   size = text_6pt, label.size = 0,
                   label.padding = unit(0.6, "mm"), fill = "white") +
        scale_colour_manual(values = setNames(c(colour_up, colour_down, colour_other),
                                              levels(volcano$group)), drop = FALSE) +
        scale_x_continuous(limits = c(-5.2, 5.2), breaks = seq(-4, 4, 2)) +
        scale_y_continuous(limits = c(0, 10.5), breaks = seq(0, 10, 2), expand = c(0, 0)) +
        labs(title = paste(condition, "against control"),
             x = bquote(log[2] ~ "fold change (" * .(condition) * " / control)"),
             y = expression(-log[10] ~ "adjusted " * italic(P))) +
        guides(colour = guide_legend(override.aes = list(size = 1.6, alpha = 1))) +
        journal_theme +
        theme(legend.position = "inside", legend.position.inside = c(0.02, 0.98),
              legend.justification = c(0, 1))
}

panel_a <- draw_volcano("apigenin", named_apigenin, mark_nod_genes = FALSE)
panel_b <- draw_volcano("salt",     named_salt,     mark_nod_genes = TRUE)


# ----------------------------------------------------------------------------
# STEP 4 - panel c: our fold changes against the paper's
# ----------------------------------------------------------------------------

# Leave out the genes that cannot be compared one to one: one gene is not
# in today's genome annotation, and nodQ1 and nodQ2 are one gene today.
paper <- paper[paper$locus_tag_now != "not in the current annotation" &
               !paper$gene %in% c("nodQ1", "nodQ2"), ]

# The table writes fold changes the way the paper does: 8.73* means 8.73
# times more active (the star marks significance in the paper), -2 means
# half as active. as_fold() removes the star and turns -2 into 0.5.
as_fold <- function(text) {
    number <- as.numeric(sub("*", "", text, fixed = TRUE))
    ifelse(number < 0, -1 / number, number)
}

compare <- rbind(
    data.frame(condition = "apigenin", gene = paper$gene,
               paper = as_fold(paper$paper_fold_change_apigenin),
               ours  = as_fold(paper$our_fold_change_apigenin)),
    data.frame(condition = "salt", gene = paper$gene,
               paper = as_fold(paper$paper_fold_change_salt),
               ours  = as_fold(paper$our_fold_change_salt))
)

# The correlation per condition, calculated on the log2 values (as on the
# results page), printed in the corner of each small plot.
corner <- data.frame(condition = c("apigenin", "salt"))
for (i in 1:2) {
    rows <- compare[compare$condition == corner$condition[i], ]
    corner$text[i] <- sprintf("r = %.2f, n = %d genes",
                              cor(log2(rows$paper), log2(rows$ours)), nrow(rows))
    message(corner$condition[i], ": ", corner$text[i])
}

# The three genes that differ most from the paper are named (see the
# results page). The third has no name; it is RS20960 in panel b.
outliers <- compare[(compare$condition == "salt"     & compare$gene == "araC2") |
                    (compare$condition == "apigenin" & compare$gene == "rpsL")  |
                    (compare$condition == "salt"     & paper$locus_tag_now == "RTCIAT899_RS20960"), ]
outliers$style <- ifelse(outliers$gene == "HP", "plain", "italic")
outliers$gene[outliers$gene == "HP"] <- "RS20960"

facet_names <- c(apigenin = "apigenin against control", salt = "salt against control")
fold_ticks  <- c(0.125, 0.25, 0.5, 1, 2, 4, 8, 16, 32)
fold_labels <- c("1/8", "1/4", "1/2", "1", "2", "4", "8", "16", "32")

panel_c <- ggplot(compare, aes(x = paper, y = ours)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed",
                linewidth = 0.25, colour = "grey40") +
    geom_point(size = 1.1, stroke = 0, colour = "black", alpha = 0.8) +
    geom_text(data = outliers, aes(label = gene, fontface = style), size = text_6pt,
              hjust = 0, nudge_x = 0.25) +
    geom_text(data = corner, aes(x = 0.1, y = 40, label = text), size = text_6pt,
              hjust = 0, vjust = 1) +
    facet_wrap(~ condition, labeller = as_labeller(facet_names)) +
    scale_x_continuous(trans = "log2", breaks = fold_ticks, labels = fold_labels, limits = c(0.1, 40)) +
    scale_y_continuous(trans = "log2", breaks = fold_ticks, labels = fold_labels, limits = c(0.1, 40)) +
    labs(x = "fold change in the paper", y = "fold change in this run") +
    coord_fixed() +
    journal_theme +
    theme(strip.background = element_blank(),
          strip.text       = element_text(size = 7),
          panel.spacing    = unit(8, "mm"))


# ----------------------------------------------------------------------------
# STEP 5 - put the panels on one page and save
# ----------------------------------------------------------------------------
# viewport() marks a rectangle on the page: x and y are its lower left
# corner, width and height its size, all as a share of the page (0 to 1).
# Panels a and b share the upper part, panel c lies in the lower part.

draw_figure <- function() {
    grid.newpage()
    print(panel_a, vp = viewport(x = 0,    y = 0.50, width = 0.5,  height = 0.50, just = c("left", "bottom")))
    print(panel_b, vp = viewport(x = 0.5,  y = 0.50, width = 0.5,  height = 0.50, just = c("left", "bottom")))
    print(panel_c, vp = viewport(x = 0.11, y = 0,    width = 0.78, height = 0.50, just = c("left", "bottom")))

    # The panel letters, bold, as journals print them.
    letter <- gpar(fontsize = 8, fontface = "bold")
    grid.text("a", x = 0.012, y = 0.983, gp = letter)
    grid.text("b", x = 0.512, y = 0.983, gp = letter)
    grid.text("c", x = 0.012, y = 0.483, gp = letter)
}

# The PDF: sizes are given in inches, so millimetres are divided by 25.4.
pdf("results/publication_figure.pdf",
    width = figure_width_mm / 25.4, height = figure_height_mm / 25.4)
draw_figure()
invisible(dev.off())

# The PNG: 600 dots per inch, the resolution journals ask for.
png("results/figures/11_publication_figure.png",
    width = figure_width_mm, height = figure_height_mm, units = "mm", res = 600)
draw_figure()
invisible(dev.off())

message("Figure written: results/publication_figure.pdf")
message("                results/figures/11_publication_figure.png")

# ============================================================================
# plot_figure3_coverage.R
# Reproduce Figure 3 of Prasse et al. 2017 from our own run
# ============================================================================
# WHAT THIS SCRIPT DRAWS
#   Figure 3 of the paper shows six nitrogen-metabolism genes. For each gene
#   there are two small plots, wild type on top and the sRNA154 deletion
#   mutant below. Each plot shows the "read coverage": for every position of
#   the gene, how many reads lie on top of it. A gene that is less active in
#   the mutant has a lower mountain in the lower plot.
#
# WHAT IT NEEDS
#   The analysis must have been run first (bash rnaseq.sh). This script only
#   reads files that the analysis has already written:
#     - the coverage files of step 6 (one number per genome position)
#     - the gene annotation (where each gene starts and ends)
#     - the DESeq2 result table of step 8 (the fold changes)
#
# HOW TO RUN IT
#   rnaseq.sh runs it as its last step. To run it on its own:
#     conda activate reademption
#     Rscript 02_publication_rna_seq_analysis_archaea/plot_figure3_coverage.R
#
# WHAT IT WRITES
#   results/figure3_coverage.pdf           the figure as PDF
#   results/figures/09_figure3_coverage.png  the same figure as picture
#
# R BASICS USED BELOW
#   x <- 5            store the value 5 under the name x
#   c(1, 2, 3)        a list of values ("vector")
#   f(a, b)           run the function f with the inputs a and b
#   table$column      one column of a table
#   # text            a note for humans, R skips it
# ============================================================================


# ----------------------------------------------------------------------------
# 1. Settings
# ----------------------------------------------------------------------------

# Find the folder this script is in, so it works from any folder.
# commandArgs() lists how Rscript was started; one entry is "--file=<path>".
start_options <- commandArgs(trailingOnly = FALSE)
script_path   <- sub("^--file=", "", start_options[grep("^--file=", start_options)])
script_dir    <- if (length(script_path) == 1) dirname(normalizePath(script_path)) else "."

project <- file.path(script_dir, "READemption_analysis")
results <- file.path(script_dir, "results")

# Which samples to draw. The paper shows one replicate of each strain, so we
# do the same and take replicate 1.
sample_wt  <- "wt_R1"
sample_mut <- "mut_R1"

# How many letters (nucleotides) to show left and right of each gene.
flank <- 150

# Colours of the two strains.
colour_wt  <- "#4C72B0"   # blue
colour_mut <- "#DD8452"   # orange

# The six genes of Figure 3, in the order of the paper.
#   name       the gene name used in the paper
#   locus_tag  the gene's number in the current genome annotation
#   paper_fc   the fold change (mutant / wild type) printed in the paper
genes <- data.frame(
    name      = c("glnA1",      "glnA2",      "glnK1",      "amtB1",      "nifH",       "nrpA"),
    locus_tag = c("MM_RS05025", "MM_RS16575", "MM_RS03825", "MM_RS03830", "MM_RS03765", "MM_RS08860"),
    paper_fc  = c(0.16,         0.50,         0.11,         0.35,         0.43,         0.23)
)


# ----------------------------------------------------------------------------
# 2. Find where each gene lies on the genome
# ----------------------------------------------------------------------------
# The annotation file (GFF) is a table with one row per gene. The columns we
# need are: 1 = name of the DNA molecule, 3 = kind of entry, 4 = start,
# 5 = end, 7 = strand (+ or -), 9 = description.

gff_file <- list.files(file.path(project, "input"), pattern = "\\.gff$",
                       recursive = TRUE, full.names = TRUE)[1]
gff <- read.delim(gff_file, header = FALSE, comment.char = "#", quote = "")
gff <- gff[gff$V3 == "gene", ]                  # keep only the "gene" rows

# The locus tag is hidden inside the description, e.g. "...;locus_tag=MM_RS05025;..."
# sub() cuts everything away except the tag itself. The ";" in front is
# needed because the description also contains "old_locus_tag=...", the
# gene's number in the older numbering, which we do not want here.
gff$locus_tag <- sub(".*;locus_tag=([^;]+).*", "\\1", gff$V9)

# match() finds, for each of our six genes, its row in the annotation.
rows <- match(genes$locus_tag, gff$locus_tag)
genes$molecule <- gff$V1[rows]
genes$start    <- gff$V4[rows]
genes$end      <- gff$V5[rows]
genes$strand   <- gff$V7[rows]


# ----------------------------------------------------------------------------
# 3. Read the fold changes of our own run
# ----------------------------------------------------------------------------
# DESeq2 reports the change as "log2 fold change". 2 ^ value turns it back
# into a plain fold change: 0.5 means half as active, 2 means twice as active.

deseq <- read.delim(file.path(results,
             "deseq_comp_mut_vs_wt_with_annotation_and_countings.csv"),
             comment.char = "#", quote = "", check.names = FALSE)
deseq <- deseq[deseq$Feature == "CDS", ]
deseq$locus_tag <- sub(".*;locus_tag=([^;]+).*", "\\1", deseq$Attributes)
genes$our_fc <- 2 ^ deseq$log2FoldChange[match(genes$locus_tag, deseq$locus_tag)]


# ----------------------------------------------------------------------------
# 4. Read the coverage files
# ----------------------------------------------------------------------------
# READemption writes two coverage files per sample: one for reads on the
# forward strand of the DNA and one for the reverse strand. We use the
# "tnoar_min_normalized" files. In these, every sample is scaled to the same
# total number of aligned reads, so a sample that was sequenced more deeply
# does not look more active just because it has more reads.
#
# The files are in "wiggle" format:
#   variableStep chrom=NC_003901.1 span=1      <- name of the DNA molecule
#   137 0.5                                    <- position and coverage
#   138 0.5
# Positions that are not listed have coverage 0. Values of the reverse
# strand are written as negative numbers.

coverage_dir <- list.files(file.path(project, "output"),
                           pattern = "coverage-tnoar_min_normalized$",
                           full.names = TRUE)[1]

# read_coverage() reads one wiggle file and returns a table with the columns
# molecule, position and coverage. "function(...) { ... }" defines a
# reusable piece of code; it runs only when it is called further down.
read_coverage <- function(sample, strand_word) {
    file  <- list.files(coverage_dir, full.names = TRUE,
                        pattern = paste0("^", sample, "_.*_", strand_word, "\\.wig$"))[1]
    lines <- readLines(file)

    # Lines starting with "variableStep" name the molecule the following
    # numbers belong to. cumsum() numbers the blocks 1, 2, 3, ...
    is_header <- grepl("^variableStep", lines)
    molecule  <- sub(".*chrom=([^ ]+).*", "\\1", lines[is_header])
    block     <- cumsum(is_header)

    # Keep only the lines with numbers ("track" is the title line).
    keep  <- !is_header & !grepl("^track", lines)
    parts <- strsplit(lines[keep], " ")
    data.frame(
        molecule = molecule[block[keep]],
        position = as.integer(sapply(parts, `[`, 1)),
        coverage = abs(as.numeric(sapply(parts, `[`, 2)))   # abs() removes the minus sign
    )
}

message("Reading coverage files (takes about a minute) ...")
coverage <- list(
    wt_forward  = read_coverage(sample_wt,  "forward"),
    wt_reverse  = read_coverage(sample_wt,  "reverse"),
    mut_forward = read_coverage(sample_mut, "forward"),
    mut_reverse = read_coverage(sample_mut, "reverse")
)

# gene_coverage() returns the coverage of one sample at every position of
# one gene region, taken from the strand the gene lies on.
gene_coverage <- function(strain, gene) {
    strand_word <- if (gene$strand == "+") "forward" else "reverse"
    table       <- coverage[[paste0(strain, "_", strand_word)]]
    positions   <- (gene$start - flank):(gene$end + flank)

    values <- rep(0, length(positions))          # start with 0 everywhere
    inside <- table$molecule == gene$molecule &
              table$position >= min(positions) & table$position <= max(positions)
    values[table$position[inside] - min(positions) + 1] <- table$coverage[inside]
    data.frame(position = positions, coverage = values)
}


# ----------------------------------------------------------------------------
# 5. Draw the figure
# ----------------------------------------------------------------------------
# draw_figure() draws all six genes. It is written as a function because we
# call it twice: once for the PDF file and once for the PNG picture.

draw_figure <- function() {
    # layout() cuts the page into boxes. The numbers say in which order the
    # boxes are filled: two columns of genes, and for every gene one box for
    # the wild type and one for the mutant below it.
    # The boxes are filled column by column, so the left column comes first.
    layout(matrix(1:12, nrow = 6, ncol = 2), heights = rep(c(1, 1.25), 3))

    # Genes 1, 3, 5 go into the left column and 2, 4, 6 into the right one.
    # Read row by row, the page then shows the genes in the paper's order.
    for (i in c(1, 3, 5, 2, 4, 6)) {
        gene <- genes[i, ]
        wt   <- gene_coverage("wt",  gene)
        mut  <- gene_coverage("mut", gene)

        # Both plots of a gene get the same vertical scale, otherwise the
        # heights could not be compared by eye.
        top <- max(wt$coverage, mut$coverage) * 1.05

        # ---- upper plot: wild type ----
        par(mar = c(0.4, 5, 3, 1))                       # margins: bottom, left, top, right
        plot(wt$position, wt$coverage, type = "n", ylim = c(0, top),
             xaxt = "n", xlab = "", ylab = "reads", las = 1, bty = "l")
        polygon(c(wt$position[1], wt$position, tail(wt$position, 1)),
                c(0, wt$coverage, 0), col = colour_wt, border = NA)
        title(main = bquote(italic(.(gene$name))), line = 1.4, cex.main = 1.4)
        legend("topright", legend = "wild type", bty = "n", text.col = colour_wt, cex = 1.1)

        # ---- lower plot: mutant ----
        par(mar = c(5.2, 5, 0.4, 1))
        plot(mut$position, mut$coverage, type = "n", ylim = c(0, top),
             xlab = "", ylab = "reads", las = 1, bty = "l")
        polygon(c(mut$position[1], mut$position, tail(mut$position, 1)),
                c(0, mut$coverage, 0), col = colour_mut, border = NA)
        legend("topright", legend = "mutant (no sRNA154)", bty = "n",
               text.col = colour_mut, cex = 1.1)

        # A thick black bar under the plot marks where the gene itself lies;
        # the arrow head shows its reading direction.
        bar_y <- -top * 0.33
        arrow_from <- if (gene$strand == "+") gene$start else gene$end
        arrow_to   <- if (gene$strand == "+") gene$end   else gene$start
        arrows(arrow_from, bar_y, arrow_to, bar_y, lwd = 4, length = 0.1, xpd = NA)

        # The fold changes, ours next to the paper's.
        mtext(sprintf("position on the genome      fold change mutant / wild type:  this run %.2f,  paper %.2f",
                      gene$our_fc, gene$paper_fc),
              side = 1, line = 3.8, cex = 0.72)
    }
}

# PDF version (vector graphics, can be enlarged without getting blurry).
pdf(file.path(results, "figure3_coverage.pdf"), width = 11, height = 10)
draw_figure()
invisible(dev.off())          # dev.off() closes the file

# PNG version (a picture, shown on the results page).
dir.create(file.path(results, "figures"), showWarnings = FALSE)
png(file.path(results, "figures", "09_figure3_coverage.png"),
    width = 11, height = 10, units = "in", res = 110)
draw_figure()
invisible(dev.off())


# ----------------------------------------------------------------------------
# 6. Print the numbers
# ----------------------------------------------------------------------------
message("Fold changes (mutant / wild type):")
print(data.frame(gene = genes$name, locus_tag = genes$locus_tag,
                 paper = genes$paper_fc, this_run = round(genes$our_fc, 2)),
      row.names = FALSE)
message("Figure written to ", file.path(results, "figure3_coverage.pdf"))

# Results: Example 02, sRNA154 in *Methanosarcina mazei*

This page explains what the analysis found and how to read every plot. You do
not need to run anything to follow it.

All numbers come from one complete run of [`rnaseq.sh`](../rnaseq.sh) with
READemption 2.0.4. If you run the script yourself you should get the same
numbers.

## The short version

- **What was compared:** the archaeon *Methanosarcina mazei* Gö1 with and
  without the small RNA sRNA154, two samples (replicates) of each.
  - `wt`: wild type, the normal strain
  - `mut`: mutant, the strain in which sRNA154 was deleted
- **Why:** the paper this example follows (Prasse et al. 2017) describes
  sRNA154 as a regulator of nitrogen fixation, the ability to use nitrogen
  gas from the air.
- **Data quality:** 88 to 90 % of the reads could be placed on the genome,
  and the replicates agree very well.
- **Main result:** deleting sRNA154 changes few genes. Of 2,771 genes that
  could be tested, 53 changed at least two-fold: 19 became more active and
  34 less active in the mutant.
- **Does it make sense?** Yes. The clearest losers in the mutant are genes
  of nitrogen metabolism: glutamine synthetase (`glnA`), a P-II nitrogen
  regulator and two ammonium transporters.

## Words used on this page

| Word | Meaning |
|---|---|
| Read | One short piece of RNA sequence produced by the sequencing machine. Here each read is 100 letters long. |
| Aligning | Finding the place on the genome a read came from. |
| Replicate | A repeat of the same experiment. Two replicates that agree show that a result is not an accident. |
| Expression | How active a gene is. More reads from a gene means higher expression. |
| Fold change | How many times more (or less) active a gene is in one condition than in the other. |
| log2 fold change | The fold change on a doubling scale: +1 means twice as much, +2 four times, +3 eight times; -1 means half as much. 0 means no change. |
| p-value | The chance of seeing a difference this large if there were really no difference. Small is convincing. |
| padj | The p-value corrected for the fact that thousands of genes are tested at once. This is the one to use. Below 0.05 is the usual cut-off. |

## 1. How good are the raw reads?

Open [`multiqc_report.html`](multiqc_report.html) in a web browser (download
it first; GitHub shows only its source code). It is a report made by the
programs FastQC and MultiQC, which examine the reads before any analysis.

| Sample | Reads | Read length | GC content | Reads that occur more than once |
|---|---|---|---|---|
| mut_R1 | 5,988,519 | 100 | 39 % | 84 % |
| mut_R2 | 6,824,347 | 100 | 39 % | 83 % |
| wt_R1 | 3,767,973 | 100 | 41 % | 86 % |
| wt_R2 | 4,776,112 | 100 | 40 % | 82 % |

**What it shows.**

- The quality of the letters ("per base sequence quality") passes in all
  four samples. This is the most important check.
- FastQC marks five other checks as failed: sequence content, GC content,
  duplication, over-represented sequences and adapter content. This looks
  alarming but is common for RNA-seq. FastQC was designed for genome
  sequencing, where every part of the genome should appear about equally
  often. In RNA-seq a few very active genes produce a large share of the
  reads, so the same sequences appear again and again.
- The adapter warning means that some reads still carry a piece of the
  artificial sequence added in the laboratory. This analysis does not remove
  adapters separately; it trims read ends by quality only. Since about 90 %
  of the reads still align, the effect is limited, but it is one reason why
  some reads are lost (section 2).

## 2. Were the reads placed on the genome?

![Aligned reads per sample](figures/01_aligned_reads.png)

**How to read it.** One bar per sample. The height is the number of reads
that were aligned (the scale `1e6` means millions). The colours split each
bar:

- **blue**: reads that fit exactly one place on the genome ("uniquely aligned")
- **green**: reads that fit several places equally well ("multiple aligned")

**What it shows.**

| Sample | Reads | Too short after cleaning | Aligned | Aligned to one place only |
|---|---|---|---|---|
| mut_R1 | 5,988,519 | 486,184 | 88.5 % | 89.7 % |
| mut_R2 | 6,824,347 | 542,669 | 89.5 % | 89.5 % |
| wt_R1 | 3,767,973 | 287,224 | 90.4 % | 90.6 % |
| wt_R2 | 4,776,112 | 376,565 | 89.1 % | 90.2 % |

About nine in ten reads were aligned, and about nine in ten of those fit a
single place, which is a good result. Most of the reads that were lost were
removed during cleaning because they became too short (about 8 % of each
sample).

The bars have different heights because the samples have different numbers
of reads; the mutant samples were sequenced more deeply. That is not a
problem: DESeq2 corrects for it before comparing.

## 3. How long are the reads?

Before cleaning:

![Read lengths before cleaning](figures/02_read_length_before.png)

After cleaning:

![Read lengths after cleaning](figures/03_read_length_after.png)

**How to read it.** The horizontal axis is the read length in letters
(nucleotides, "nt"). The height of a bar is the number of reads with that
length. The plots show sample mut_R1; the PDF files have one page per sample.

**What it shows.** Before cleaning, every read is exactly 100 letters long.
Cleaning cuts low-quality letters (quality below 25) and runs of A's off the
read ends. Most reads stay at or close to 100 letters. A smaller part is
spread over all shorter lengths, and reads shorter than 12 letters are
thrown away.

## 4. What kind of RNA do the reads come from?

![Reads per RNA class](figures/04_rna_classes.png)

**How to read it.** One bar per sample, split by the kind of gene the reads
landed on:

- **turquoise (CDS)**: protein-coding genes, the ones we are interested in
- **green (rRNA)**: ribosomal RNA
- **yellow (tRNA)**: transfer RNA

**What it shows.**

| Sample | Protein-coding genes | rRNA | tRNA |
|---|---|---|---|
| mut_R1 | 1,510,233 | 357,016 | 210,785 |
| mut_R2 | 1,960,734 | 431,797 | 253,716 |
| wt_R1 | 859,197 | 231,872 | 154,786 |
| wt_R2 | 1,258,281 | 274,922 | 230,004 |

About 70 % of the counted reads come from protein-coding genes. That is the
opposite of example 01 and much better for the analysis: every gene is
measured from many reads, so even small changes can be detected. It
suggests that ribosomal RNA was removed in the laboratory before sequencing.

## 5. Do the replicates agree?

Two replicates of the same condition (mut_R1 against mut_R2):

![Scatter plot of two replicates](figures/05_scatter_replicates.png)

Two different conditions (mut_R1 against wt_R1):

![Scatter plot of two conditions](figures/06_scatter_conditions.png)

**How to read it.** Every dot is one gene. Its position to the right is the
number of reads in the first sample, its height is the number of reads in
the second sample. Both axes are logarithmic: each step (10, 100, 1,000) is
ten times more. A dot on the green diagonal line has the same activity in
both samples. The number `r` in the title is the correlation: 1 means
identical, 0 means unrelated.

**What it shows.**

- The replicates are almost identical: r = 0.996 for the two mutant samples
  and r = 0.990 for the two wild-type samples.
- Mutant against wild type is only slightly wider (r between 0.963 and
  0.980). Nearly all genes stay on the diagonal, and a few dots stand
  clearly apart from it.

This already tells the main story: deleting sRNA154 leaves most of the cell
unchanged and affects a small number of genes.

The file `expression_scatter_plots.pdf` has all twelve sample pairs.

## 6. Which genes changed?

For every gene, the program DESeq2 compares the read counts of the two
conditions and reports how big the change is (log2 fold change) and how
sure we can be about it (padj).

In this comparison, called "mut vs. wt", a **positive** log2 fold change
means the gene is **more active in the mutant**, and a **negative** one
means it is **less active in the mutant**.

### MA plot

![MA plot](figures/07_ma_plot.png)

**How to read it.** Every dot is one gene.

- Left to right: how active the gene is on average over all samples
  (logarithmic: 2 means about 100 reads, 3 about 1,000, 4 about 10,000).
- Up and down: the log2 fold change. Dots above 0 are more active in the
  mutant, dots below 0 are less active. The further from 0, the bigger the
  change.
- **Red** dots are genes with a statistically significant change
  (padj below 0.05). **Black** dots are not significant.

**What it shows.** Almost all genes lie in a flat band between -1 and +1,
so they change less than two-fold. Many dots inside the band are red:
because the replicates agree so well, even small changes are statistically
significant. Significant is not the same as large, which is why we also ask
for a two-fold change. Only a handful of dots lie far outside the band,
reaching about -3.4 (ten times less active) and +2.7 (six times more
active).

### Volcano plot

![Volcano plot](figures/08_volcano_plot.png)

**How to read it.** Every dot is one gene.

- Left to right: the log2 fold change. Right of 0 means more active in the
  mutant, left of 0 means less active.
- Bottom to top: how convincing the change is. The axis is the negative
  logarithm of padj, so **higher means more certain** (2 corresponds to
  padj 0.01, 10 to padj 0.0000000001).
- The two vertical dotted lines mark a two-fold change (log2 fold change of
  -1 and +1). The horizontal dotted line marks padj 0.05.

A gene counts as clearly changed when it is **above the horizontal line and
outside the two vertical lines**: the upper left and upper right areas.

**What it shows.** Most genes sit in the narrow column in the middle. Only
53 genes are in the two outer areas, 34 on the left and 19 on the right.
The gene at the very top is glutamine synthetase (`glnA`), with a padj of
1.7e-72. Its dot is cut off at the upper edge of the plot.

The second volcano file, `volcano_plots_log2_fold_change_vs_p-value.pdf`,
is the same plot with the uncorrected p-value. Use the adjusted one.

### The numbers

| | Genes |
|---|---|
| Annotated genes (protein-coding, tRNA, rRNA) | 3,523 |
| Genes with enough reads to be tested | 2,771 |
| Significant (padj below 0.05) | 441 |
| Significant and at least two-fold more active in the mutant | 19 |
| Significant and at least two-fold less active in the mutant | 34 |

### Genes that became less active without sRNA154

| Gene | What it makes | log2 fold change | Times less active | padj |
|---|---|---|---|---|
| MM_RS03045 | PHP domain protein | -3.40 | about 10.6 | 2.1e-42 |
| MM_RS05025 (`glnA`) | glutamine synthetase (type I glutamate-ammonia ligase) | -2.91 | about 7.5 | 1.7e-72 |
| MM_RS03825 | P-II family nitrogen regulator | -2.90 | about 7.5 | 2.5e-17 |
| MM_RS10395 | phosphate transporter, binding protein PstS | -2.72 | about 6.6 | 2.7e-27 |
| MM_RS03030 | phosphate transporter, binding protein PstS | -2.13 | about 4.4 | 1.2e-13 |
| MM_RS01710 | HAD family hydrolase | -2.06 | about 4.2 | 3.9e-11 |
| MM_RS04990 | ammonium transporter | -1.95 | about 3.9 | 6.1e-11 |
| MM_RS03830 | ammonium transporter | -1.62 | about 3.1 | 5.1e-09 |

Four of these eight belong to nitrogen metabolism. Glutamine synthetase is
the enzyme that builds ammonium into the cell's own molecules, P-II proteins
are the sensors that report the cell's nitrogen status, and the ammonium
transporters bring ammonium into the cell. Their drop in the mutant fits the
paper's description of sRNA154 as a regulator of nitrogen metabolism.

### Genes that became more active without sRNA154

| Gene | What it makes | log2 fold change | Times more active | padj |
|---|---|---|---|---|
| MM_RS17330 | protein of unknown function (DUF2769) | 2.68 | about 6.4 | 8.2e-29 |
| MM_RS06595 | prephenate dehydrogenase | 1.99 | about 4.0 | 3.8e-32 |
| MM_RS06585 (`aroD`) | 3-dehydroquinate dehydratase | 1.66 | about 3.2 | 2.2e-17 |
| MM_RS06590 | shikimate dehydrogenase | 1.57 | about 3.0 | 3.4e-16 |
| MM_RS06580 | 3-dehydroquinate synthase II | 1.36 | about 2.6 | 2.3e-13 |
| MM_RS12580 | methylcobamide-CoM methyltransferase | 1.30 | about 2.5 | 2.2e-08 |

Four of these genes (MM_RS06580 to MM_RS06595) lie next to each other on
the genome and belong to the pathway that makes aromatic amino acids. They
rise together, as would be expected if these neighbouring genes are read
as one unit.

### What about the nitrogenase genes?

Nitrogenase is the enzyme that fixes nitrogen gas. In this run its genes
(MM_RS03765 to MM_RS03795) have few reads, and none of them shows a
significant change. So these data show the effect of sRNA154 on glutamine
synthetase, the P-II regulator and the ammonium transporters, but not on
nitrogenase itself.

The notation `1.7e-72` means a decimal point followed by 71 zeros and then
17: the number after `e-` says how many places the decimal point moves to
the left.

## Files in this folder

| File | Content |
|---|---|
| `multiqc_report.html` | Read-quality report of section 1. Download it and open it in a web browser. |
| `read_alignment_stats.csv` | All alignment numbers per sample. Opens in Excel or LibreOffice (tab-separated). |
| `deseq_comp_mut_vs_wt_with_annotation_and_countings.csv` | One row per gene: position, description, raw read counts of the four samples, `log2FoldChange`, `pvalue` and `padj`. This is the main result table. |
| `deseq_comp_wt_vs_mut_with_annotation_and_countings.csv` | The same comparison the other way round, so every fold change has the opposite sign. |
| `methanosarcina_aligned_reads.pdf` | Plot of section 2 |
| `input_reads_length_distributions.pdf`, `processed_reads_length_distributions.pdf` | Plots of section 3, one page per sample |
| `rna_class_sizes.pdf` | Plot of section 4 |
| `expression_scatter_plots.pdf` | Plots of section 5, all twelve sample pairs |
| `MA_plots.pdf` | MA plots of section 6, one page per direction of the comparison |
| `volcano_plots_log2_fold_change_vs_adjusted_p-value.pdf` | Volcano plots of section 6 |
| `volcano_plots_log2_fold_change_vs_p-value.pdf` | Volcano plots with the uncorrected p-value |
| `figures/` | The pictures shown on this page, made from the PDF files |

## What to keep in mind

- There are only **two replicates** per condition. That is the minimum for
  statistics. Three or more make the results more reliable.
- The gene lists were **not compared one by one** with the tables in the
  paper. The paper's own analysis used different software versions and
  settings, so individual numbers can differ.
- sRNA154 itself is not in the gene list, because only protein-coding
  genes, tRNAs and rRNAs were counted.
- The biological remarks on this page are based on the gene descriptions in
  the annotation file.

## Reference

Prasse D, Förstner KU, Jäger D, Backofen R, Schmitz RA (2017). sRNA154 a
newly identified regulator of nitrogen fixation in *Methanosarcina mazei*
strain Gö1. *RNA Biology* 14:1544-1558.
[doi:10.1080/15476286.2017.1306170](https://doi.org/10.1080/15476286.2017.1306170)

# RNA-seq analysis of bacteria and archaea with READemption

This repository shows, step by step, how to analyse RNA-seq data from
bacteria and archaea: from raw sequencing reads to a table of genes that are
switched on or off between conditions, with plots.

It uses [READemption](https://reademption.readthedocs.io), a pipeline made for
microbial RNA-seq, and follows the course material of
[AammarTufail/rnaseq_bioinformatics_ka_chilla](https://github.com/AammarTufail/rnaseq_bioinformatics_ka_chilla).

You do not need to be a programmer to rerun it. If you can open a terminal and
copy and paste a command, you can follow this page.

## Analyses

The analyses are added to this repository one at a time, each after it has
been run and checked.

| # | Analysis | Organism | Reads | Status |
|---|---|---|---|---|
| 01 | [READemption example data](01_example_analysis_bacteria) | *Salmonella* Typhimurium SL1344 | single-end | available |
| 02 | sRNA154 and nitrogen fixation (Prasse et al. 2017) | *Methanosarcina mazei* Gö1 | single-end | coming next |
| 03 | Response to apigenin and salt (Pérez-Montaño et al. 2016) | *Rhizobium tropici* CIAT 899 | paired-end | planned |

## What you need

- A computer running **Linux** (64-bit). On Windows, use
  [WSL](https://learn.microsoft.com/windows/wsl/install).
- An **internet connection**.
- About **5 GB** of free disk space for the software, plus space for the data
  of each analysis.
- **conda**. If you do not have it, `install.sh` tells you how to get it.

## Installation

Open a terminal and run these commands one line at a time.

**1. Download this repository**

```bash
git clone https://github.com/shabrozkhanbaloch/rnaseq_analysis.git
cd rnaseq_analysis
```

**2. Install the software**

```bash
bash install.sh
```

This takes 5 to 15 minutes. It creates two conda environments:

| Environment | What is inside |
|---|---|
| `reademption` | READemption 2.0.4, the segemehl aligner, R and DESeq2 |
| `rnaseq_qc` | FastQC, MultiQC, fastp, samtools and SRA tools |

At the end you should see a list of lines starting with `PASS`, followed by:

```
Installation complete. Every tool is working.
```

You can run `bash install.sh` again at any time. It skips what is already
installed and only repeats the tests.

## Running an analysis

Each analysis is one script. It downloads its own data, runs every step and
copies the most important tables and plots to a `results` folder.

### 01 - Salmonella example

Compares *Salmonella* grown in two conditions (InSPI2 and LSP), two
replicates each. Needs about 1 GB of disk space and about 10 minutes.

```bash
bash 01_example_analysis_bacteria/example_01_analysis.sh
```

When it ends with `Finished at: ...`, open the folder
`01_example_analysis_bacteria/results`:

| File | What it shows |
|---|---|
| `read_alignment_stats.csv` | How many reads were found on the genome, per sample. Open it in Excel or LibreOffice. |
| `deseq_comp_InSPI2_vs_LSP_with_annotation_and_countings.csv` | One row per gene: read counts, fold change (`log2FoldChange`) and significance (`padj`) |
| `volcano_plots_*.pdf`, `MA_plots.pdf` | Pictures of which genes go up or down |
| `expression_scatter_plots.pdf` | How well the replicates agree with each other |
| `rna_class_sizes.pdf` | Share of reads from protein-coding genes, tRNA and rRNA |
| `salmonella_aligned_reads.pdf`, `*_reads_length_distributions.pdf` | Alignment and read-length overviews |

In our run about 99 % of the one million reads per sample aligned to the
genome, and 1,055 of the 3,013 tested genes changed at least two-fold
(`padj` below 0.05): 600 higher in InSPI2 and 455 higher in LSP.

A gene is usually called differentially expressed when `padj` is below 0.05
and `log2FoldChange` is above 1 or below -1 (a two-fold change).

To use fewer CPU cores, put `THREADS=4` in front of the command:

```bash
THREADS=4 bash 01_example_analysis_bacteria/example_01_analysis.sh
```

## Troubleshooting

**"conda was not found"**
Install Miniforge with the two commands the message shows, close the
terminal, open a new one and run `bash install.sh` again.

**A line says `FAIL`**
Remove the environment named in the square brackets and install again:

```bash
conda env remove -n reademption -y
bash install.sh
```

**The installation stops with a download or network error**
Check your internet connection and run `bash install.sh` again. It continues
where it stopped.

**An analysis stops halfway**
Run the same command again. Files that were already downloaded are kept. To
start completely fresh, delete the `READemption_analysis` folder inside that
analysis folder first.

## Optional: Docker instead of conda

If you prefer Docker, the same tools are available as one image:

```bash
docker build -t rnaseq-reademption:2.0.4 docker/
docker/run_in_docker.sh reademption --version
```

## Repository layout

```
install.sh        installs all software
01_example_analysis_bacteria/   Salmonella example: script and results
envs/             the two conda environment definitions
docker/           optional Docker image with the same tools
```

## Credits

- Pipeline: READemption, Förstner et al. 2014, *Bioinformatics*,
  [doi:10.1093/bioinformatics/btu533](https://doi.org/10.1093/bioinformatics/btu533)
- Course material: Aammar Tufail, *Bioinformatics ka Chilla*

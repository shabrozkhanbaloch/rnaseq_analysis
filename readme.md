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
| 01 | READemption example data | *Salmonella* Typhimurium SL1344 | single-end | coming next |
| 02 | sRNA154 and nitrogen fixation (Prasse et al. 2017) | *Methanosarcina mazei* Gö1 | single-end | planned |
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

## Optional: Docker instead of conda

If you prefer Docker, the same tools are available as one image:

```bash
docker build -t rnaseq-reademption:2.0.4 docker/
docker/run_in_docker.sh reademption --version
```

## Repository layout

```
install.sh        installs all software
envs/             the two conda environment definitions
docker/           optional Docker image with the same tools
```

## Credits

- Pipeline: READemption, Förstner et al. 2014, *Bioinformatics*,
  [doi:10.1093/bioinformatics/btu533](https://doi.org/10.1093/bioinformatics/btu533)
- Course material: Aammar Tufail, *Bioinformatics ka Chilla*

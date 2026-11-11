#!/usr/bin/env bash
###############################################################################
# Example 02 - sRNA154 in the archaeon Methanosarcina mazei Goe1
#
# WHAT THIS SCRIPT ANSWERS
#   Which genes change when the small RNA "sRNA154" is deleted?
#   sRNA154 helps to control nitrogen fixation, so we compare
#     wt  = wild type (the normal strain)
#     mut = mutant (the strain where sRNA154 was deleted)
#   There are two samples (replicates) of each, so four samples in total.
#   The reads are single-end and stored in FASTQ format.
#
# THE PAPER
#   Prasse D, Foerstner KU, Jaeger D, Backofen R, Schmitz RA (2017)
#   "sRNA154 a newly identified regulator of nitrogen fixation in
#   Methanosarcina mazei strain Goe1". RNA Biology 14:1544-1558.
#   https://doi.org/10.1080/15476286.2017.1306170
#
# THE DATA
#   Reads:  NCBI BioProject PRJNA338498, runs SRR4018514 to SRR4018517.
#           We download them as ready-made FASTQ files from the European
#           Nucleotide Archive (ENA), which mirrors NCBI.
#   Genome: NCBI RefSeq assembly GCF_000007065.1 (ASM706v1)
#
# HOW TO RUN IT (from the repository folder, after "bash install.sh")
#   bash 02_publication_rna_seq_analysis_archaea/rnaseq.sh
#
# WHAT YOU NEED
#   About 6 GB of free disk space and about 35 minutes on 16 CPU cores.
#
# WHAT YOU GET (all inside this folder)
#   READemption_analysis/   everything READemption produces (not in git)
#   qc/                     read-quality reports (not in git)
#   results/                the most important tables and plots (in git)
#
# IF IT STOPS HALFWAY
#   Run the same command again. Files that are already downloaded are kept.
#
# HOW TO READ THIS FILE IF YOU ARE NEW TO SHELL SCRIPTS
#   - A line starting with "#" is a note for humans. The computer skips it.
#   - NAME=value stores a value under a name. $NAME (or ${NAME}) uses it
#     again later. Example: THREADS=12 ... --processes "$THREADS"
#   - A "\" at the end of a line means "this command continues on the next
#     line". It only makes long commands easier to read.
#   - The script runs from top to bottom, one step after the other.
###############################################################################

# Safety switch: stop immediately if any command fails, instead of carrying
# on with missing or broken files.
#   -e           stop on the first error
#   -u           stop if a name is used that was never given a value (a typo)
#   -o pipefail  also notice errors inside commands joined with "|"
set -euo pipefail

# ----------------------------------------------------------------------------
# SETTINGS - the only part you normally need to change
# ----------------------------------------------------------------------------

# How many CPU cores to use. "${THREADS:-12}" means: use the value of THREADS
# if you set one, otherwise use 12. To use 4 cores, start the script with:
#   THREADS=4 bash 02_publication_rna_seq_analysis_archaea/rnaseq.sh
THREADS="${THREADS:-12}"

# Name of the folder READemption works in.
PROJECT=READemption_analysis

# A short name for the organism. READemption puts it in front of its folder
# names, for example "methanosarcina_annotations".
SPECIES=methanosarcina

# Where the genome and the gene annotation are downloaded from (NCBI), and
# the name both files start with.
GENOME_URL=https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/007/065/GCF_000007065.1_ASM706v1
GENOME=GCF_000007065.1_ASM706v1_genomic

# Where the reads are downloaded from (ENA).
ENA_URL=https://ftp.sra.ebi.ac.uk/vol1/fastq

# The four samples, as a list. Each line has two parts joined by a colon:
#     <where the file is on the ENA server> : <the name we give the sample>
# The name tells you what the sample is: <condition>_<replicate>.
RUNS=(
    "SRR401/004/SRR4018514:wt_R1"     # wild type, replicate 1
    "SRR401/005/SRR4018515:wt_R2"     # wild type, replicate 2
    "SRR401/006/SRR4018516:mut_R1"    # sRNA154 deletion mutant, replicate 1
    "SRR401/007/SRR4018517:mut_R2"    # sRNA154 deletion mutant, replicate 2
)

# ----------------------------------------------------------------------------
# PREPARATION
# ----------------------------------------------------------------------------

# Move into the folder this script is stored in. This way the script works
# the same no matter which folder you start it from.
cd "$(dirname "${BASH_SOURCE[0]}")"

# A small helper called "use_env". Writing "use_env reademption" further
# down switches to the conda environment named "reademption", which is where
# install.sh put the software. It is written once here so the same four
# lines do not have to be repeated every time we switch.
#
# The "if" line checks whether conda exists on this computer. Inside the
# optional Docker image there is no conda (the tools are simply available),
# so in that case the helper does nothing.
use_env() {
    if command -v conda >/dev/null 2>&1; then
        eval "$(conda shell.bash hook)"   # teach this script the "conda activate" command
        set +u                            # conda needs the typo check off for a moment ...
        conda activate "$1"               # "$1" = the name written after use_env
        set -u                            # ... and here it is switched back on
    fi
}

# Print the start time, so you can see afterwards how long the run took.
echo "Started at: $(date)"

# ----------------------------------------------------------------------------
# STEP 1 - create the project folders
# ----------------------------------------------------------------------------
# "reademption create" makes an empty folder structure:
#   READemption_analysis/input/    where we put genome, annotation and reads
#   READemption_analysis/output/   where READemption writes its results
# --species is given as <short name>="<full name>".
use_env reademption
echo "Using $(reademption --version) with $THREADS CPU cores"

# "if [ ! -d ... ]" means: only do this if the folder does NOT exist yet.
# That is what makes it safe to run the script a second time.
if [ ! -d "$PROJECT" ]; then
    reademption create \
        --project_path "$PROJECT" \
        --species ${SPECIES}="Methanosarcina mazei"
fi

# Short names for the three input folders, so the lines below stay readable.
REFERENCE_DIR=$PROJECT/input/${SPECIES}_reference_sequences
ANNOTATION_DIR=$PROJECT/input/${SPECIES}_annotations
READS_DIR=$PROJECT/input/reads

# ----------------------------------------------------------------------------
# STEP 2 - download the genome and the annotation
# ----------------------------------------------------------------------------
# Genome     (FASTA file, .fa):  the DNA sequence the reads are compared to.
# Annotation (GFF file, .gff):   a table saying where each gene is located.
#
# "if [ ! -s file ]" means: only do this if the file is missing or empty.
#   wget    downloads a file (-q = quietly, -O = save it under this name)
#   gunzip  unpacks a .gz file
# NCBI calls the genome file ".fna", but READemption expects ".fa", so we
# save it under the new name straight away.
if [ ! -s "$REFERENCE_DIR/$GENOME.fa" ]; then
    wget -q -O "$REFERENCE_DIR/$GENOME.fa.gz" "$GENOME_URL/$GENOME.fna.gz"
    gunzip "$REFERENCE_DIR/$GENOME.fa.gz"
fi
if [ ! -s "$ANNOTATION_DIR/$GENOME.gff" ]; then
    wget -q -O "$ANNOTATION_DIR/$GENOME.gff.gz" "$GENOME_URL/$GENOME.gff.gz"
    gunzip "$ANNOTATION_DIR/$GENOME.gff.gz"
fi

# ----------------------------------------------------------------------------
# STEP 3 - download the reads (about 1.6 GB)
# ----------------------------------------------------------------------------
# "for entry in ..." repeats the lines between "do" and "done" once for each
# of the four samples in the RUNS list above.
#
# Worked example for the first sample, "SRR401/004/SRR4018514:wt_R1":
#   run_path = SRR401/004/SRR4018514    (the part before the colon)
#   library  = wt_R1                    (the part after the colon)
#   run      = SRR4018514               (the part after the last "/")
#   reads    = READemption_analysis/input/reads/wt_R1.fastq.gz
# So the file SRR4018514.fastq.gz is downloaded and saved as wt_R1.fastq.gz.
# With readable names, every later table and plot shows "wt_R1" instead of
# an accession number.
for entry in "${RUNS[@]}"; do
    run_path="${entry%%:*}"           # keep the text before the colon
    library="${entry#*:}"             # keep the text after the colon
    run="${run_path##*/}"             # keep the text after the last "/"
    reads=$READS_DIR/$library.fastq.gz

    if [ ! -s "$reads" ]; then
        echo "Downloading $run as $library"
        # The download is first saved as "<name>.part" and only renamed
        # (mv) when it is complete. If the internet connection drops, no
        # half-downloaded file is mistaken for a finished one.
        # -c lets wget continue a partial download instead of starting over.
        wget -q -c -O "$reads.part" "$ENA_URL/$run_path/$run.fastq.gz"
        mv "$reads.part" "$reads"
    fi
done

# ----------------------------------------------------------------------------
# STEP 4 - check the quality of the reads
# ----------------------------------------------------------------------------
# Always look at read quality before trusting any result.
#   FastQC   makes one quality report per read file
#   MultiQC  joins those reports into one page: qc/multiqc_report.html
# These two tools live in the second environment, "rnaseq_qc".
# "mkdir -p qc" creates the folder "qc" (and does not complain if it exists).
# "*.fastq.gz" means: every file whose name ends in .fastq.gz.
use_env rnaseq_qc
mkdir -p qc
fastqc --quiet --threads "$THREADS" --outdir qc "$READS_DIR"/*.fastq.gz
multiqc --quiet --force --outdir qc qc

# ----------------------------------------------------------------------------
# STEP 5 - clean the reads and align them to the genome
# ----------------------------------------------------------------------------
# "Aligning" means finding the place on the genome each read came from.
# This is the longest step.
#
#   --project_path       the project folder made in step 1
#   --processes          how many CPU cores to use
#   --segemehl_accuracy  a read must match the genome in at least 95 % of
#                        its letters to count as aligned
#   --poly_a_clipping    cut off runs of A's at the read end; they were
#                        added in the lab and are not part of the genome
#   --fastq              the reads are FASTQ files (READemption expects
#                        FASTA unless told otherwise)
#   --min_phred_score    cut low-quality letters (quality below 25) off the
#                        end of each read
#   --progress           show a progress bar
use_env reademption
reademption align \
    --project_path "$PROJECT" \
    --processes "$THREADS" \
    --segemehl_accuracy 95 \
    --poly_a_clipping \
    --fastq \
    --min_phred_score 25 \
    --progress

# ----------------------------------------------------------------------------
# STEP 6 - calculate coverage
# ----------------------------------------------------------------------------
# Coverage = how many reads lie on top of each position of the genome.
# The result is a set of ".wig" files. Open them in a genome browser such
# as IGV to look at any gene with your own eyes.
reademption coverage \
    --project_path "$PROJECT" \
    --processes "$THREADS"

# ----------------------------------------------------------------------------
# STEP 7 - count the reads per gene
# ----------------------------------------------------------------------------
# For every gene, count how many reads landed on it. More reads = the gene
# was more active.
#   --features  which kinds of annotation entries to count:
#               CDS  = protein-coding genes
#               tRNA = transfer RNAs
#               rRNA = ribosomal RNAs
reademption gene_quanti \
    --project_path "$PROJECT" \
    --processes "$THREADS" \
    --features CDS,tRNA,rRNA

# ----------------------------------------------------------------------------
# STEP 8 - find the genes that differ between mutant and wild type (DESeq2)
# ----------------------------------------------------------------------------
# DESeq2 is a statistics program. It compares the counts of the two
# conditions and tells us, for every gene, how big the change is and how
# sure we can be that it is real.
#
# The three lists below must be in the SAME ORDER. Read them as columns:
#
#   --libs        mut_R1.fastq.gz  mut_R2.fastq.gz  wt_R1.fastq.gz  wt_R2.fastq.gz
#   --conditions  mut              mut              wt              wt
#   --replicates  1                2                1               2
#
#   --libs             the read files, named exactly as in input/reads
#   --conditions       which condition each file belongs to
#   --replicates       the replicate number of each file
#   --libs_by_species  which samples belong to which organism (here all four
#                      to methanosarcina), written without the file ending
reademption deseq \
    --project_path "$PROJECT" \
    --libs mut_R1.fastq.gz,mut_R2.fastq.gz,wt_R1.fastq.gz,wt_R2.fastq.gz \
    --conditions mut,mut,wt,wt \
    --replicates 1,2,1,2 \
    --libs_by_species ${SPECIES}=mut_R1,mut_R2,wt_R1,wt_R2

# ----------------------------------------------------------------------------
# STEP 9 - draw the plots
# ----------------------------------------------------------------------------
reademption viz_align --project_path "$PROJECT"         # how many reads aligned
reademption viz_gene_quanti --project_path "$PROJECT"   # reads per kind of RNA
reademption viz_deseq --project_path "$PROJECT"         # MA plots and volcano plots

# ----------------------------------------------------------------------------
# STEP 10 - copy the most important results into one small folder
# ----------------------------------------------------------------------------
# READemption's full output is several GB. The files most people want are
# copied ("cp") into results/, which is small enough to keep in git.
# "*.csv" and "*.pdf" mean: every file with that ending in the folder.
OUT=$PROJECT/output
mkdir -p results
cp qc/multiqc_report.html results/                                    # read-quality report
cp "$OUT/align/reports_and_stats/read_alignment_stats.csv" results/   # alignment numbers
cp "$OUT/${SPECIES}_deseq/deseq_with_annotations/"*.csv results/      # DESeq2 gene tables
cp "$OUT/${SPECIES}_viz_deseq/"*.pdf results/                         # MA and volcano plots
cp "$OUT/${SPECIES}_viz_gene_quanti/"*.pdf results/                   # count overview plots
cp "$OUT/${SPECIES}_viz_align/"*.pdf results/                         # alignment plot
cp "$OUT/read_lengths_viz_align/"*.pdf results/                       # read-length plots

# ----------------------------------------------------------------------------
# STEP 11 - plot the read coverage of selected genes (the paper's Figure 3)
# ----------------------------------------------------------------------------
# Steps 1 to 10 are READemption's standard analysis. This last step is
# specific to this paper: Figure 3 shows the read coverage over six
# nitrogen-metabolism genes in wild type and mutant. The R script next to
# this file draws the same content from the coverage files of step 6 and
# writes it to results/. Which genes are drawn is set in the table
# genes_to_plot.csv. "Rscript" runs a script written in the language R;
# R is part of the reademption environment.
Rscript plot_gene_coverage.R

echo "Finished at: $(date)"
echo "Key results are in: $(pwd)/results"

#!/bin/bash
# ===========================================================================
# Example 02: sRNA154 in Methanosarcina mazei (single-end reads)
# ===========================================================================
#
# WHAT THIS SCRIPT DOES
#   It repeats the RNA-seq analysis of a published paper:
#   Prasse et al. 2017, RNA Biology 14:1544-1558.
#   The archaeon Methanosarcina mazei has a small RNA called sRNA154 that
#   helps to control nitrogen fixation. Two strains are compared:
#       wt    wild type, the normal strain
#       mut   mutant, the strain in which sRNA154 was deleted
#   Each strain was done twice (two "replicates": R1 and R2), so there are
#   four samples. The script finds the genes that are more or less active
#   in the mutant than in the wild type.
#
# HOW TO RUN IT
#   bash 02_publication_rna_seq_analysis_archaea/rnaseq.sh
#
# HOW LONG IT TAKES
#   About 35 minutes. It needs about 6 GB of free disk space.
#
# HOW TO READ THIS FILE
#   Lines that start with "#" are notes for people. The computer skips them.
#   All other lines are commands. They run one after another, from top to
#   bottom. A "\" at the end of a line means: the command continues on the
#   next line.
#   Above every command there is a note with three parts:
#       What:     what the command does
#       Why:      why this step is needed
#       Options:  what the settings after the command mean
# ===========================================================================


# ---------------------------------------------------------------------------
# Before we start: some settings
#
# What:  "set -e" tells the computer to stop at the first error.
# Why:   Without it the script would carry on after a failed step and
#        produce results that look fine but are wrong.
# ---------------------------------------------------------------------------
set -e

# What:  Go into the folder where this script is saved.
# Why:   All results are then written next to the script, no matter from
#        which folder you started it.
cd "$(dirname "$0")"

# What:  The number of processor cores to use. NAME=value stores a value;
#        later, $NAME puts that value into a command. "nproc" asks the
#        computer how many cores it has, and $( ... ) puts the answer here.
# Why:   More cores make the long steps faster, so we use all of them.
#        If you want to keep working on the computer during the run,
#        write a smaller number instead, for example: THREADS=4
THREADS=$(nproc)

# What:  Two web addresses, stored under short names.
# Why:   The download commands below stay short and readable.
#        GENOME = where the genome of Methanosarcina mazei is stored (NCBI)
#        ENA    = where the sequencing reads are stored (European
#                 Nucleotide Archive)
GENOME=https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/007/065/GCF_000007065.1_ASM706v1/GCF_000007065.1_ASM706v1_genomic
ENA=https://ftp.sra.ebi.ac.uk/vol1/fastq

# What:  Switch on the software that was installed by install.sh.
# Why:   The programs live in a "conda environment", a separate box of
#        installed software. "conda activate reademption" opens the box
#        named reademption. The first line makes the "conda activate"
#        command available inside a script.
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate reademption


# ---------------------------------------------------------------------------
# STEP 1: Create the project folders
#
# What:  READemption makes a folder "READemption_analysis" with two
#        subfolders: "input" (for the files we download) and "output"
#        (for everything it calculates).
# Why:   READemption expects every file in a fixed place. Creating the
#        folders with its own command guarantees the right layout.
# Options:
#   --project_path  the name of the folder to create
#   --species       a short name (methanosarcina) and the full name of the organism
#
# "if [ ! -d ... ]; then ... fi" means: only do this if the folder does not
# exist yet. So the script can be started a second time without an error.
# ---------------------------------------------------------------------------
if [ ! -d READemption_analysis ]; then
    reademption create --project_path READemption_analysis \
        --species methanosarcina="Methanosarcina mazei"
fi


# ---------------------------------------------------------------------------
# STEP 2: Download the genome and the list of genes
#
# What:  Two files are downloaded and unpacked:
#          .fa   the genome: the complete DNA sequence of the organism
#          .gff  the annotation: a list that says where each gene lies
# Why:   The genome is needed to find out where each read comes from
#        (step 5). The annotation is needed to know which gene that
#        place belongs to (step 7).
# How:   wget downloads a file (-q = quietly, "-O -" = pass it on instead
#        of saving it). The "|" hands the download to gunzip, which unpacks
#        it. The ">" writes the unpacked text into the file named after it.
# ---------------------------------------------------------------------------
wget -q -O - $GENOME.fna.gz | gunzip > READemption_analysis/input/methanosarcina_reference_sequences/GCF_000007065.1_ASM706v1_genomic.fa
wget -q -O - $GENOME.gff.gz | gunzip > READemption_analysis/input/methanosarcina_annotations/GCF_000007065.1_ASM706v1_genomic.gff


# ---------------------------------------------------------------------------
# STEP 3: Download the reads (about 1.6 GB)
#
# What:  Four files are downloaded, one per sample.
# Why:   These are the raw data of the paper. The authors stored them in
#        a public archive, where every sample has a number (SRR...).
#        We save each file under a name that says what it is, for example
#        wt_R1 = wild type, replicate 1.
# Options:
#   -q  quietly, do not print progress
#   -c  continue: if a file is already there, do not download it again
#   -O  the name under which the file is saved
# ---------------------------------------------------------------------------
READS=READemption_analysis/input/reads

# wild type, replicate 1 and 2
wget -q -c -O $READS/wt_R1.fastq.gz  $ENA/SRR401/004/SRR4018514/SRR4018514.fastq.gz
wget -q -c -O $READS/wt_R2.fastq.gz  $ENA/SRR401/005/SRR4018515/SRR4018515.fastq.gz

# mutant without sRNA154, replicate 1 and 2
wget -q -c -O $READS/mut_R1.fastq.gz $ENA/SRR401/006/SRR4018516/SRR4018516.fastq.gz
wget -q -c -O $READS/mut_R2.fastq.gz $ENA/SRR401/007/SRR4018517/SRR4018517.fastq.gz


# ---------------------------------------------------------------------------
# STEP 4: Check the quality of the reads
#
# What:  FastQC examines every read file and writes a report. MultiQC
#        joins the four reports into one page: qc/multiqc_report.html
# Why:   A sequencing machine makes mistakes. Before trusting any result
#        we look at how good the raw data are.
# Note:  These two programs are in another environment (rnaseq_qc), so we
#        switch to it here and switch back afterwards.
# Options:
#   --quiet    print only errors
#   --threads  how many cores to use
#   --outdir   the folder for the reports
#   --force    replace an older report if there is one
# ---------------------------------------------------------------------------
conda activate rnaseq_qc
mkdir -p qc
fastqc --quiet --threads $THREADS --outdir qc $READS/*.fastq.gz
multiqc --quiet --force --outdir qc qc
conda activate reademption


# ---------------------------------------------------------------------------
# STEP 5: Clean the reads and align them to the genome
#
# What:  First the bad ends of the reads are cut off. Then, for every
#        read, the program looks for the place on the genome where it
#        fits. This is called "aligning". It is the longest step.
# Why:   A read is only a short piece of sequence. Only when we know where
#        on the genome it comes from can we say which gene it belongs to.
# Options:
#   --processes          how many cores to use
#   --segemehl_accuracy  a read must match the genome in at least 95 % of
#                        its letters
#   --poly_a_clipping    cut off the row of A letters at the end of a
#                        read. It was added in the laboratory and is not
#                        part of the genome.
#   --fastq              the read files are in FASTQ format
#   --min_phred_score    cut letters with a quality below 25 off the end
#                        of each read
#   --progress           show how far the alignment is
# ---------------------------------------------------------------------------
reademption align --project_path READemption_analysis \
    --processes $THREADS \
    --segemehl_accuracy 95 \
    --poly_a_clipping \
    --fastq \
    --min_phred_score 25 \
    --progress


# ---------------------------------------------------------------------------
# STEP 6: Calculate the coverage
#
# What:  For every position of the genome, count how many reads lie on
#        top of it. The result is a set of "coverage files" per sample.
# Why:   Coverage files can be opened in a genome browser (for example
#        IGV), where you can look at any gene and see how active it is.
#        They are for looking; the statistics use the counts of step 7.
# ---------------------------------------------------------------------------
reademption coverage --project_path READemption_analysis \
    --processes $THREADS


# ---------------------------------------------------------------------------
# STEP 7: Count the reads per gene
#
# What:  For every gene, count how many reads lie on it.
# Why:   An active gene produces much RNA, so many reads land on it.
#        These counts are what step 8 compares between the conditions.
# Options:
#   --features  which kinds of gene to count: protein-coding genes (CDS),
#               transfer RNA (tRNA) and ribosomal RNA (rRNA)
# ---------------------------------------------------------------------------
reademption gene_quanti --project_path READemption_analysis \
    --processes $THREADS \
    --features CDS,tRNA,rRNA


# ---------------------------------------------------------------------------
# STEP 8: Find the genes that differ between mutant and wild type
#
# What:  The program DESeq2 compares the counts of step 7 between the
#        mutant and the wild type.
# Why:   Counts always differ a little by chance. DESeq2 uses the two
#        replicates to judge whether a difference is larger than chance.
#        For every gene it reports how big the change is and how sure
#        we can be about it.
# Options:
#   --libs             the four read files
#   --conditions       the condition of each file, in the same order
#   --replicates       the replicate number of each file, same order
#   --libs_by_species  which samples belong to which organism (here all
#                      four belong to methanosarcina)
# ---------------------------------------------------------------------------
reademption deseq --project_path READemption_analysis \
    --libs mut_R1.fastq.gz,mut_R2.fastq.gz,wt_R1.fastq.gz,wt_R2.fastq.gz \
    --conditions mut,mut,wt,wt \
    --replicates 1,2,1,2 \
    --libs_by_species methanosarcina=mut_R1,mut_R2,wt_R1,wt_R2


# ---------------------------------------------------------------------------
# STEP 9: Draw the plots
#
# What:  Three commands, each draws a group of plots as PDF files.
# Why:   A plot shows at a glance what a table with thousands of rows
#        cannot: how many reads were aligned, what kind of RNA they come
#        from, and which genes changed.
# ---------------------------------------------------------------------------
# How many reads were aligned, and how long the reads are
reademption viz_align --project_path READemption_analysis

# How the counts are spread over the kinds of RNA, and how similar the samples are
reademption viz_gene_quanti --project_path READemption_analysis

# Which genes changed (MA plots and volcano plots)
reademption viz_deseq --project_path READemption_analysis


# ---------------------------------------------------------------------------
# STEP 10: Copy the most important results into one small folder
#
# What:  "cp" copies files. "*.csv" means: every file that ends in .csv.
# Why:   The folder READemption_analysis is large (several GB). The tables
#        and plots that most people want are only a few MB. They are
#        copied into "results", which is small enough to share.
# ---------------------------------------------------------------------------
OUTPUT=READemption_analysis/output
mkdir -p results

# the read-quality report of step 4
cp qc/multiqc_report.html results/

# the alignment numbers of step 5
cp $OUTPUT/align/reports_and_stats/read_alignment_stats.csv results/

# the gene tables of step 8
cp $OUTPUT/methanosarcina_deseq/deseq_with_annotations/*.csv results/

# the plots of step 9
cp $OUTPUT/methanosarcina_viz_align/*.pdf results/
cp $OUTPUT/read_lengths_viz_align/*.pdf results/
cp $OUTPUT/methanosarcina_viz_gene_quanti/*.pdf results/
cp $OUTPUT/methanosarcina_viz_deseq/*.pdf results/


# ---------------------------------------------------------------------------
# STEP 11: Plot the read coverage of selected genes (the paper's Figure 3)
#
# What:  The R script next to this file draws, for six nitrogen genes,
#        how many reads cover each position: wild type against mutant.
#        "Rscript" runs a script written in the language R.
# Why:   Steps 1 to 10 are the standard analysis. This step is specific
#        to this paper: its Figure 3 shows exactly these six genes, so we
#        draw them from our own run to compare. Which genes are drawn is
#        set in the table genes_to_plot.csv.
# ---------------------------------------------------------------------------
Rscript plot_gene_coverage.R

echo "Finished. The key results are in the folder: results"

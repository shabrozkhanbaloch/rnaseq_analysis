#!/bin/bash
# ===========================================================================
# Example 01: Salmonella in two growth conditions (READemption example data)
# ===========================================================================
#
# WHAT THIS SCRIPT DOES
#   It finds the Salmonella genes that change their activity between two
#   growth conditions:
#       InSPI2   a medium that switches on the "SPI-2" virulence genes
#       LSP      rich medium, late stationary phase
#   Each condition was done twice (two "replicates": R1 and R2), so there
#   are four samples.
#
# WHERE THE DATA COME FROM
#   This is the official practice data set of READemption, as used in the
#   course AammarTufail/rnaseq_bioinformatics_ka_chilla. It is small, so
#   it is the best example to try first.
#
# HOW TO RUN IT
#   bash 01_example_analysis_bacteria/example_01_analysis.sh
#
# HOW LONG IT TAKES
#   About 10 minutes. It needs about 1 GB of free disk space.
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
#        GENOME = where the genome of Salmonella is stored (NCBI)
#        READS  = where the practice reads are stored (READemption project)
GENOME=https://ftp.ncbi.nih.gov/genomes/archive/old_refseq/Bacteria/Salmonella_enterica_serovar_Typhimurium_SL1344_uid86645
READS=http://reademptiondata.imib-zinf.net

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
#   --species       a short name (salmonella) and the full name of the organism
#
# "if [ ! -d ... ]; then ... fi" means: only do this if the folder does not
# exist yet. So the script can be started a second time without an error.
# ---------------------------------------------------------------------------
if [ ! -d READemption_analysis ]; then
    reademption create --project_path READemption_analysis \
        --species salmonella="Salmonella Typhimurium"
fi


# ---------------------------------------------------------------------------
# STEP 2: Download the genome and the list of genes
#
# What:  The genome of this Salmonella strain consists of four DNA
#        molecules: one chromosome (NC_016810) and three small plasmids.
#        Each is downloaded as its own file. Then the annotation is
#        downloaded: a list that says where each gene lies.
# Why:   The genome is needed to find out where each read comes from
#        (step 5). The annotation is needed to know which gene that
#        place belongs to (step 7).
# How:   wget downloads a file (-q = quietly, -O = the name to save it under).
#
#        The "sed" line after each download changes the first line of the
#        file. That line holds the name of the DNA molecule. In the genome
#        file it is written differently than in the annotation, and
#        READemption can only connect the two if the names are the same.
#        sed puts the name used by the annotation (for example NC_016810.1)
#        at the front of the line.
# ---------------------------------------------------------------------------
GENOME_FOLDER=READemption_analysis/input/salmonella_reference_sequences

# the chromosome
wget -q -O $GENOME_FOLDER/NC_016810.fa $GENOME/NC_016810.fna
sed -i "s/>/>NC_016810.1 /" $GENOME_FOLDER/NC_016810.fa

# the three plasmids
wget -q -O $GENOME_FOLDER/NC_017718.fa $GENOME/NC_017718.fna
sed -i "s/>/>NC_017718.1 /" $GENOME_FOLDER/NC_017718.fa

wget -q -O $GENOME_FOLDER/NC_017719.fa $GENOME/NC_017719.fna
sed -i "s/>/>NC_017719.1 /" $GENOME_FOLDER/NC_017719.fa

wget -q -O $GENOME_FOLDER/NC_017720.fa $GENOME/NC_017720.fna
sed -i "s/>/>NC_017720.1 /" $GENOME_FOLDER/NC_017720.fa

# The annotation. "-O -" passes the download on instead of saving it, the
# "|" hands it to gunzip, which unpacks it, and ">" writes the unpacked
# text into the file named after it.
wget -q -O - https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/210/855/GCF_000210855.2_ASM21085v2/GCF_000210855.2_ASM21085v2_genomic.gff.gz \
    | gunzip > READemption_analysis/input/salmonella_annotations/GCF_000210855.2_ASM21085v2_genomic.gff


# ---------------------------------------------------------------------------
# STEP 3: Download the reads
#
# What:  Four files are downloaded, one per sample.
# Why:   These are the raw data: millions of short pieces of RNA sequence
#        ("reads") from each sample. The file names say what they are, for
#        example InSPI2_R1 = condition InSPI2, replicate 1.
# Options:
#   -q  quietly, do not print progress
#   -c  continue: if a file is already there, do not download it again
#   -O  the name under which the file is saved
# ---------------------------------------------------------------------------
wget -q -c -O READemption_analysis/input/reads/InSPI2_R1.fa.bz2 $READS/InSPI2_R1.fa.bz2
wget -q -c -O READemption_analysis/input/reads/InSPI2_R2.fa.bz2 $READS/InSPI2_R2.fa.bz2
wget -q -c -O READemption_analysis/input/reads/LSP_R1.fa.bz2    $READS/LSP_R1.fa.bz2
wget -q -c -O READemption_analysis/input/reads/LSP_R2.fa.bz2    $READS/LSP_R2.fa.bz2


# ---------------------------------------------------------------------------
# STEP 4: (no quality check in this example)
#
# The practice reads are already cleaned and come without quality values,
# so there is nothing to check. Examples 02 and 03 have this step.
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# STEP 5: Align the reads to the genome
#
# What:  For every read, the program looks for the place on the genome
#        where it fits. This is called "aligning". It is the longest step.
# Why:   A read is only a short piece of sequence. Only when we know where
#        on the genome it comes from can we say which gene it belongs to.
# Options:
#   --processes        how many cores to use
#   --poly_a_clipping  cut off the row of A letters at the end of a read.
#                      It was added in the laboratory and is not part of
#                      the genome.
#   --progress         show how far the alignment is
# ---------------------------------------------------------------------------
reademption align --project_path READemption_analysis \
    --processes $THREADS \
    --poly_a_clipping \
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
# STEP 8: Find the genes that differ between the two conditions
#
# What:  The program DESeq2 compares the counts of step 7 between InSPI2
#        and LSP.
# Why:   Counts always differ a little by chance. DESeq2 uses the two
#        replicates to judge whether a difference is larger than chance.
#        For every gene it reports how big the change is and how sure
#        we can be about it.
# Options:
#   --libs             the four read files
#   --conditions       the condition of each file, in the same order
#   --replicates       the replicate number of each file, same order
#   --libs_by_species  which samples belong to which organism (here all
#                      four belong to salmonella)
# ---------------------------------------------------------------------------
reademption deseq --project_path READemption_analysis \
    --libs InSPI2_R1.fa.bz2,InSPI2_R2.fa.bz2,LSP_R1.fa.bz2,LSP_R2.fa.bz2 \
    --conditions InSPI2,InSPI2,LSP,LSP \
    --replicates 1,2,1,2 \
    --libs_by_species salmonella=InSPI2_R1,InSPI2_R2,LSP_R1,LSP_R2


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

# the alignment numbers of step 5
cp $OUTPUT/align/reports_and_stats/read_alignment_stats.csv results/

# the gene tables of step 8
cp $OUTPUT/salmonella_deseq/deseq_with_annotations/*.csv results/

# the plots of step 9
cp $OUTPUT/salmonella_viz_align/*.pdf results/
cp $OUTPUT/read_lengths_viz_align/*.pdf results/
cp $OUTPUT/salmonella_viz_gene_quanti/*.pdf results/
cp $OUTPUT/salmonella_viz_deseq/*.pdf results/

echo "Finished. The key results are in the folder: results"

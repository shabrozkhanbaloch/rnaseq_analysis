#!/usr/bin/env bash
###############################################################################
# Example 01 - READemption example data (Salmonella Typhimurium SL1344)
#
# WHAT THIS SCRIPT ANSWERS
#   Which Salmonella genes change their activity between two growth
#   conditions?
#     InSPI2 = a medium that switches on the "SPI-2" virulence genes
#     LSP    = rich medium, late stationary phase
#   There are two samples (replicates) of each, so four samples in total.
#   The reads are single-end and stored in FASTA format.
#
# WHERE IT COMES FROM
#   The official READemption tutorial data set, as used in
#   AammarTufail/rnaseq_bioinformatics_ka_chilla (01_example_analysis_bacteria).
#   It is small, so it is the best one to try first.
#
# HOW TO RUN IT (from the repository folder, after "bash install.sh")
#   bash 01_example_analysis_bacteria/example_01_analysis.sh
#
# WHAT YOU NEED
#   About 1 GB of free disk space and about 10 minutes on 16 CPU cores.
#
# WHAT YOU GET (all inside this folder)
#   READemption_analysis/   everything READemption produces (not in git)
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
#   THREADS=4 bash 01_example_analysis_bacteria/example_01_analysis.sh
THREADS="${THREADS:-12}"

# Name of the folder READemption works in.
PROJECT=READemption_analysis

# A short name for the organism. READemption puts it in front of its folder
# names, for example "salmonella_annotations".
SPECIES=salmonella

# Where the genome, the gene annotation and the reads are downloaded from.
GENOME_URL=https://ftp.ncbi.nih.gov/genomes/archive/old_refseq/Bacteria/Salmonella_enterica_serovar_Typhimurium_SL1344_uid86645
ANNOTATION_URL=https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/210/855/GCF_000210855.2_ASM21085v2/GCF_000210855.2_ASM21085v2_genomic.gff.gz
READS_URL=http://reademptiondata.imib-zinf.net

# A list of the four pieces the Salmonella genome consists of: one
# chromosome (the first name) and three plasmids. Each piece is its own file.
REPLICONS=(NC_016810 NC_017718 NC_017719 NC_017720)

# A list of the four samples. The name tells you what the sample is:
# <condition>_<replicate>.
LIBRARIES=(InSPI2_R1 InSPI2_R2 LSP_R1 LSP_R2)

# ----------------------------------------------------------------------------
# PREPARATION
# ----------------------------------------------------------------------------

# Move into the folder this script is stored in. This way the script works
# the same no matter which folder you start it from.
cd "$(dirname "${BASH_SOURCE[0]}")"

# Switch to the conda environment named "reademption", which is where
# install.sh put the software.
#
# The "if" line checks whether conda exists on this computer. Inside the
# optional Docker image there is no conda (the tools are simply available),
# so in that case these lines are skipped.
if command -v conda >/dev/null 2>&1; then
    eval "$(conda shell.bash hook)"   # teach this script the "conda activate" command
    set +u                            # conda needs the typo check off for a moment ...
    conda activate reademption
    set -u                            # ... and here it is switched back on
fi

# Print the start time, so you can see afterwards how long the run took.
echo "Started at: $(date)"
echo "Using $(reademption --version) with $THREADS CPU cores"

# ----------------------------------------------------------------------------
# STEP 1 - create the project folders
# ----------------------------------------------------------------------------
# "reademption create" makes an empty folder structure:
#   READemption_analysis/input/    where we put genome, annotation and reads
#   READemption_analysis/output/   where READemption writes its results
# --species is given as <short name>="<full name>".
#
# "if [ ! -d ... ]" means: only do this if the folder does NOT exist yet.
# That is what makes it safe to run the script a second time.
if [ ! -d "$PROJECT" ]; then
    reademption create \
        --project_path "$PROJECT" \
        --species ${SPECIES}="Salmonella Typhimurium"
fi

# Short names for the three input folders, so the lines below stay readable.
REFERENCE_DIR=$PROJECT/input/${SPECIES}_reference_sequences
ANNOTATION_DIR=$PROJECT/input/${SPECIES}_annotations
READS_DIR=$PROJECT/input/reads

# ----------------------------------------------------------------------------
# STEP 2 - download the genome
# ----------------------------------------------------------------------------
# The genome (FASTA files, .fa) is the DNA sequence the reads are compared to.
#
# "for replicon in ..." repeats the lines between "do" and "done" once for
# each of the four genome pieces in the REPLICONS list above.
#
# Worked example for the first piece, NC_016810:
#   1. wget downloads NC_016810.fna and saves it as NC_016810.fa.part
#      (-q = quietly, -O = save it under this name).
#   2. sed changes the first line of the file. That line is the name of the
#      sequence. It is downloaded as
#          >gi|378697983|ref|NC_016810.1| Salmonella enterica ...
#      and becomes
#          >NC_016810.1 gi|378697983|ref|NC_016810.1| Salmonella enterica ...
#      Why: the annotation file calls this sequence "NC_016810.1".
#      READemption can only connect reads to genes if the genome file and
#      the annotation file use exactly the same name.
#   3. mv renames the finished file to NC_016810.fa. Saving as ".part"
#      first means a half-downloaded file is never mistaken for a
#      finished one.
#
# "if [ ! -s file ]" means: only do this if the file is missing or empty.
for replicon in "${REPLICONS[@]}"; do
    fasta=$REFERENCE_DIR/$replicon.fa
    if [ ! -s "$fasta" ]; then
        wget -q -O "$fasta.part" "$GENOME_URL/$replicon.fna"
        sed -i "s/>/>$replicon.1 /" "$fasta.part"
        mv "$fasta.part" "$fasta"
    fi
done

# ----------------------------------------------------------------------------
# STEP 3 - download the annotation
# ----------------------------------------------------------------------------
# The annotation (GFF file, .gff) is a table saying where each gene is
# located on the genome.
#
# "basename ... .gz" takes the file name from the end of the web address
# and removes ".gz", giving GCF_000210855.2_ASM21085v2_genomic.gff.
# gunzip unpacks the downloaded .gz file.
annotation=$ANNOTATION_DIR/$(basename "$ANNOTATION_URL" .gz)
if [ ! -s "$annotation" ]; then
    wget -q -O "$annotation.gz" "$ANNOTATION_URL"
    gunzip "$annotation.gz"
fi

# ----------------------------------------------------------------------------
# STEP 4 - download the reads
# ----------------------------------------------------------------------------
# The loop runs once for each of the four samples in the LIBRARIES list.
# For the first sample it downloads InSPI2_R1.fa.bz2.
#
# ".fa.bz2" is a FASTA file packed with bzip2. READemption can read it
# without unpacking. FASTA files contain no quality scores, so this example
# has no read-quality check (examples 02 and 03 do).
for library in "${LIBRARIES[@]}"; do
    reads=$READS_DIR/$library.fa.bz2
    if [ ! -s "$reads" ]; then
        wget -q -O "$reads.part" "$READS_URL/$library.fa.bz2"
        mv "$reads.part" "$reads"
    fi
done

# ----------------------------------------------------------------------------
# STEP 5 - clean the reads and align them to the genome
# ----------------------------------------------------------------------------
# "Aligning" means finding the place on the genome each read came from.
#
#   --project_path     the project folder made in step 1
#   --processes        how many CPU cores to use
#   --poly_a_clipping  cut off runs of A's at the read end; they were added
#                      in the lab and are not part of the genome
#   --progress         show a progress bar
reademption align \
    --project_path "$PROJECT" \
    --processes "$THREADS" \
    --poly_a_clipping \
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
# STEP 8 - find the genes that differ between the conditions (DESeq2)
# ----------------------------------------------------------------------------
# DESeq2 is a statistics program. It compares the counts of the two
# conditions and tells us, for every gene, how big the change is and how
# sure we can be that it is real.
#
# The three lists below must be in the SAME ORDER. Read them as columns:
#
#   --libs        InSPI2_R1.fa.bz2  InSPI2_R2.fa.bz2  LSP_R1.fa.bz2  LSP_R2.fa.bz2
#   --conditions  InSPI2            InSPI2            LSP            LSP
#   --replicates  1                 2                 1              2
#
#   --libs             the read files, named exactly as in input/reads
#   --conditions       which condition each file belongs to
#   --replicates       the replicate number of each file
#   --libs_by_species  which samples belong to which organism (here all four
#                      to salmonella), written without the file ending
reademption deseq \
    --project_path "$PROJECT" \
    --libs InSPI2_R1.fa.bz2,InSPI2_R2.fa.bz2,LSP_R1.fa.bz2,LSP_R2.fa.bz2 \
    --conditions InSPI2,InSPI2,LSP,LSP \
    --replicates 1,2,1,2 \
    --libs_by_species ${SPECIES}=InSPI2_R1,InSPI2_R2,LSP_R1,LSP_R2

# ----------------------------------------------------------------------------
# STEP 9 - draw the plots
# ----------------------------------------------------------------------------
reademption viz_align --project_path "$PROJECT"         # how many reads aligned
reademption viz_gene_quanti --project_path "$PROJECT"   # reads per kind of RNA
reademption viz_deseq --project_path "$PROJECT"         # MA plots and volcano plots

# ----------------------------------------------------------------------------
# STEP 10 - copy the most important results into one small folder
# ----------------------------------------------------------------------------
# READemption's full output is close to 1 GB. The files most people want
# are copied ("cp") into results/, which is small enough to keep in git.
# "*.csv" and "*.pdf" mean: every file with that ending in the folder.
OUT=$PROJECT/output
mkdir -p results
cp "$OUT/align/reports_and_stats/read_alignment_stats.csv" results/   # alignment numbers
cp "$OUT/${SPECIES}_deseq/deseq_with_annotations/"*.csv results/      # DESeq2 gene tables
cp "$OUT/${SPECIES}_viz_deseq/"*.pdf results/                         # MA and volcano plots
cp "$OUT/${SPECIES}_viz_gene_quanti/"*.pdf results/                   # count overview plots
cp "$OUT/${SPECIES}_viz_align/"*.pdf results/                         # alignment plot
cp "$OUT/read_lengths_viz_align/"*.pdf results/                       # read-length plots

echo "Finished at: $(date)"
echo "Key results are in: $(pwd)/results"

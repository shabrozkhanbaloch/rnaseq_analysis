#!/usr/bin/env bash
###############################################################################
# Example 01 - READemption example data (Salmonella Typhimurium SL1344)
#
# Question
#   Which Salmonella genes change their activity between two growth
#   conditions?
#     InSPI2 - a medium that switches on the SPI-2 virulence genes
#     LSP    - rich medium, late stationary phase
#   Two replicates per condition, single-end reads in FASTA format.
#
# Source
#   The official READemption tutorial data set, as used in
#   AammarTufail/rnaseq_bioinformatics_ka_chilla (01_example_analysis_bacteria).
#
# How to run (from the repository folder, after "bash install.sh")
#   bash 01_example_analysis_bacteria/example_01_analysis.sh
#
# Needs
#   About 1 GB of free disk space and about 10 minutes on 16 CPU cores.
#
# Output
#   READemption_analysis/   everything READemption produces (not in git)
#   results/                the key tables and plots (kept in git)
#
# The script can be restarted: files that were already downloaded are not
# downloaded again.
###############################################################################

# Stop at the first error, on unset variables, and on errors inside pipes.
set -euo pipefail

# ----------------------------------------------------------------------------
# Settings - the only part you normally need to change
# ----------------------------------------------------------------------------
THREADS="${THREADS:-12}"          # CPU cores to use; override with THREADS=4 bash ...
PROJECT=READemption_analysis      # folder READemption works in
SPECIES=salmonella                # short name used in READemption folder names

# Where the reference genome, annotation and reads are downloaded from.
GENOME_URL=https://ftp.ncbi.nih.gov/genomes/archive/old_refseq/Bacteria/Salmonella_enterica_serovar_Typhimurium_SL1344_uid86645
ANNOTATION_URL=https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/210/855/GCF_000210855.2_ASM21085v2/GCF_000210855.2_ASM21085v2_genomic.gff.gz
READS_URL=http://reademptiondata.imib-zinf.net

# The genome has four pieces (replicons): one chromosome and three plasmids.
REPLICONS=(NC_016810 NC_017718 NC_017719 NC_017720)

# The four read libraries: <condition>_<replicate>.
LIBRARIES=(InSPI2_R1 InSPI2_R2 LSP_R1 LSP_R2)

# ----------------------------------------------------------------------------
# Preparation
# ----------------------------------------------------------------------------
# Work inside the folder this script lives in, wherever it is called from.
cd "$(dirname "${BASH_SOURCE[0]}")"

# Switch on the "reademption" conda environment created by install.sh.
# Inside the Docker image there is no conda and the tools are already on the
# PATH, so this block is skipped there.
if command -v conda >/dev/null 2>&1; then
    eval "$(conda shell.bash hook)"   # makes "conda activate" work in a script
    set +u                            # conda's own scripts use unset variables
    conda activate reademption
    set -u
fi

echo "Started at: $(date)"
echo "Using $(reademption --version) with $THREADS CPU cores"

# ----------------------------------------------------------------------------
# Step 1 - create the project folders
# ----------------------------------------------------------------------------
# "reademption create" builds the input/ and output/ folder structure. The
# species is given as <short name>="<display name>".
if [ ! -d "$PROJECT" ]; then
    reademption create \
        --project_path "$PROJECT" \
        --species ${SPECIES}="Salmonella Typhimurium"
fi

REFERENCE_DIR=$PROJECT/input/${SPECIES}_reference_sequences
ANNOTATION_DIR=$PROJECT/input/${SPECIES}_annotations
READS_DIR=$PROJECT/input/reads

# ----------------------------------------------------------------------------
# Step 2 - download the reference genome
# ----------------------------------------------------------------------------
# READemption matches reads to genes through the sequence name, so the name
# in each FASTA header must be identical to the name used in the annotation
# file (for example "NC_016810.1"). The downloaded headers start with
# ">gi|...", so the sed command puts the right name in front.
for replicon in "${REPLICONS[@]}"; do
    fasta=$REFERENCE_DIR/$replicon.fa
    if [ ! -s "$fasta" ]; then
        wget -q -O "$fasta.part" "$GENOME_URL/$replicon.fna"
        sed -i "s/>/>$replicon.1 /" "$fasta.part"
        mv "$fasta.part" "$fasta"     # only a complete file gets the final name
    fi
done

# ----------------------------------------------------------------------------
# Step 3 - download the annotation (where the genes are on the genome)
# ----------------------------------------------------------------------------
annotation=$ANNOTATION_DIR/$(basename "$ANNOTATION_URL" .gz)
if [ ! -s "$annotation" ]; then
    wget -q -O "$annotation.gz" "$ANNOTATION_URL"
    gunzip "$annotation.gz"
fi

# ----------------------------------------------------------------------------
# Step 4 - download the reads
# ----------------------------------------------------------------------------
# The reads are bzip2-compressed FASTA files; READemption reads them directly.
# (FASTA has no quality scores, so there is no FastQC step in this example.)
for library in "${LIBRARIES[@]}"; do
    reads=$READS_DIR/$library.fa.bz2
    if [ ! -s "$reads" ]; then
        wget -q -O "$reads.part" "$READS_URL/$library.fa.bz2"
        mv "$reads.part" "$reads"
    fi
done

# ----------------------------------------------------------------------------
# Step 5 - align the reads to the genome
# ----------------------------------------------------------------------------
# --processes        number of libraries/threads handled in parallel
# --poly_a_clipping  remove poly-A tails that were added during library
#                    preparation, so they do not prevent alignment
# --progress         show a progress bar
reademption align \
    --project_path "$PROJECT" \
    --processes "$THREADS" \
    --poly_a_clipping \
    --progress

# ----------------------------------------------------------------------------
# Step 6 - calculate coverage
# ----------------------------------------------------------------------------
# Produces wiggle (.wig) files: the number of reads covering every position
# of the genome. Open them in a genome browser such as IGV to look at genes.
reademption coverage \
    --project_path "$PROJECT" \
    --processes "$THREADS"

# ----------------------------------------------------------------------------
# Step 7 - count reads per gene
# ----------------------------------------------------------------------------
# --features  which annotation entries to count: protein-coding genes (CDS),
#             transfer RNAs and ribosomal RNAs
reademption gene_quanti \
    --project_path "$PROJECT" \
    --processes "$THREADS" \
    --features CDS,tRNA,rRNA

# ----------------------------------------------------------------------------
# Step 8 - differential gene expression with DESeq2
# ----------------------------------------------------------------------------
# The three lists must be in the same order: the first library belongs to the
# first condition and the first replicate number, and so on.
# --libs             read files, exactly as named in input/reads
# --conditions       the condition each library belongs to
# --replicates       the replicate number of each library
# --libs_by_species  which libraries belong to which species (no file ending)
reademption deseq \
    --project_path "$PROJECT" \
    --libs InSPI2_R1.fa.bz2,InSPI2_R2.fa.bz2,LSP_R1.fa.bz2,LSP_R2.fa.bz2 \
    --conditions InSPI2,InSPI2,LSP,LSP \
    --replicates 1,2,1,2 \
    --libs_by_species ${SPECIES}=InSPI2_R1,InSPI2_R2,LSP_R1,LSP_R2

# ----------------------------------------------------------------------------
# Step 9 - plots
# ----------------------------------------------------------------------------
reademption viz_align --project_path "$PROJECT"         # alignment statistics
reademption viz_gene_quanti --project_path "$PROJECT"   # counts per RNA class
reademption viz_deseq --project_path "$PROJECT"         # MA and volcano plots

# ----------------------------------------------------------------------------
# Step 10 - collect the key results
# ----------------------------------------------------------------------------
# The full output is large, so the tables and plots most people want are
# copied to results/, which is small enough to keep in git.
OUT=$PROJECT/output
mkdir -p results
cp "$OUT/align/reports_and_stats/read_alignment_stats.csv" results/
cp "$OUT/${SPECIES}_deseq/deseq_with_annotations/"*.csv results/
cp "$OUT/${SPECIES}_viz_deseq/"*.pdf results/
cp "$OUT/${SPECIES}_viz_gene_quanti/"*.pdf results/
cp "$OUT/${SPECIES}_viz_align/"*.pdf results/
cp "$OUT/read_lengths_viz_align/"*.pdf results/

echo "Finished at: $(date)"
echo "Key results are in: $(pwd)/results"

#!/bin/bash
# ===========================================================================
# Example 03: Rhizobium tropici with apigenin and with salt (paired-end reads)
# ===========================================================================
#
# WHAT THIS SCRIPT DOES
#   It repeats the RNA-seq analysis of a published paper:
#   Perez-Montano et al. 2016, BMC Genomics 17:198.
#   The bacterium Rhizobium tropici CIAT 899 was grown in three ways:
#       control    normal medium
#       apigenin   medium with apigenin, a plant signal molecule
#       salt       medium with extra salt
#   Each condition was done twice (two "replicates": R1 and R2), so there
#   are six samples. The script finds the genes that are more or less
#   active with apigenin or with salt than in the control.
#
# WHAT "PAIRED-END" MEANS
#   Every piece of RNA was read from both ends. So each sample has two
#   files: _p1 (reads from one end) and _p2 (reads from the other end).
#
# HOW TO RUN IT
#   bash 03_publication_rna_seq_paired_end_rhizobium/rnaseq.sh
#
# HOW LONG IT TAKES AND WHAT IT NEEDS
#   About 10 to 12 hours on a laptop with 16 processor cores.
#   About 60 GB of free disk space.
#   Much memory: step 5 handles several samples at the same time, and each
#   large sample needs about 16 GB of memory there. With 16 cores all six
#   samples run together and use about 70 GB. On a computer with less
#   memory, lower THREADS below (THREADS=2 needs about 32 GB).
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
#        or if the computer has less than about 80 GB of memory, write a
#        smaller number instead, for example: THREADS=2
THREADS=$(nproc)

# What:  Two web addresses, stored under short names.
# Why:   The download commands below stay short and readable.
#        GENOME = where the genome of Rhizobium tropici is stored (NCBI)
#        ENA    = where the sequencing reads are stored (European
#                 Nucleotide Archive)
GENOME=https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/330/885/GCF_000330885.1_ASM33088v1/GCF_000330885.1_ASM33088v1_genomic
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
#   --species       a short name (rhizobium) and the full name of the organism
#
# "if [ ! -d ... ]; then ... fi" means: only do this if the folder does not
# exist yet. So the script can be started a second time without an error.
# ---------------------------------------------------------------------------
if [ ! -d READemption_analysis ]; then
    reademption create --project_path READemption_analysis \
        --species rhizobium="Rhizobium tropici"
fi


# ---------------------------------------------------------------------------
# STEP 2: Download the genome and the list of genes
#
# What:  Two files are downloaded and unpacked:
#          .fa   the genome: the complete DNA sequence of the bacterium
#          .gff  the annotation: a list that says where each gene lies
# Why:   The genome is needed to find out where each read comes from
#        (step 5). The annotation is needed to know which gene that
#        place belongs to (step 7).
# How:   wget downloads a file (-q = quietly, "-O -" = pass it on instead
#        of saving it). The "|" hands the download to gunzip, which unpacks
#        it. The ">" writes the unpacked text into the file named after it.
# ---------------------------------------------------------------------------
wget -q -O - $GENOME.fna.gz | gunzip > READemption_analysis/input/rhizobium_reference_sequences/GCF_000330885.1_ASM33088v1_genomic.fa
wget -q -O - $GENOME.gff.gz | gunzip > READemption_analysis/input/rhizobium_annotations/GCF_000330885.1_ASM33088v1_genomic.gff


# ---------------------------------------------------------------------------
# STEP 3: Download the reads (about 10 GB)
#
# What:  Twelve files are downloaded: six samples, two files each.
# Why:   These are the raw data of the paper. The authors stored them in
#        a public archive, where every sample has a number (SRR...).
#        We save each file under a name that says what it is, for example
#        control_R1_p1 = control, replicate 1, reads from end 1.
#        READemption recognises a pair by the endings _p1 and _p2.
# Options:
#   -q  quietly, do not print progress
#   -c  continue: if a file is already there, do not download it again
#   -O  the name under which the file is saved
# ---------------------------------------------------------------------------
READS=READemption_analysis/input/reads

# control, replicate 1 and 2
wget -q -c -O $READS/control_R1_p1.fastq.gz  $ENA/SRR303/007/SRR3031957/SRR3031957_1.fastq.gz
wget -q -c -O $READS/control_R1_p2.fastq.gz  $ENA/SRR303/007/SRR3031957/SRR3031957_2.fastq.gz
wget -q -c -O $READS/control_R2_p1.fastq.gz  $ENA/SRR303/008/SRR3031958/SRR3031958_1.fastq.gz
wget -q -c -O $READS/control_R2_p2.fastq.gz  $ENA/SRR303/008/SRR3031958/SRR3031958_2.fastq.gz

# apigenin, replicate 1 and 2
wget -q -c -O $READS/apigenin_R1_p1.fastq.gz $ENA/SRR303/001/SRR3032151/SRR3032151_1.fastq.gz
wget -q -c -O $READS/apigenin_R1_p2.fastq.gz $ENA/SRR303/001/SRR3032151/SRR3032151_2.fastq.gz
wget -q -c -O $READS/apigenin_R2_p1.fastq.gz $ENA/SRR306/006/SRR3062176/SRR3062176_1.fastq.gz
wget -q -c -O $READS/apigenin_R2_p2.fastq.gz $ENA/SRR306/006/SRR3062176/SRR3062176_2.fastq.gz

# salt, replicate 1 and 2
wget -q -c -O $READS/salt_R1_p1.fastq.gz     $ENA/SRR303/002/SRR3036912/SRR3036912_1.fastq.gz
wget -q -c -O $READS/salt_R1_p2.fastq.gz     $ENA/SRR303/002/SRR3036912/SRR3036912_2.fastq.gz
wget -q -c -O $READS/salt_R2_p1.fastq.gz     $ENA/SRR303/005/SRR3036915/SRR3036915_1.fastq.gz
wget -q -c -O $READS/salt_R2_p2.fastq.gz     $ENA/SRR303/005/SRR3036915/SRR3036915_2.fastq.gz


# ---------------------------------------------------------------------------
# STEP 4: Check the quality of the reads
#
# What:  FastQC examines every read file and writes a report. MultiQC
#        joins the twelve reports into one page: qc/multiqc_report.html
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
# What:  First the bad ends of the reads are cut off. Then, for every pair
#        of reads, the program looks for the place on the genome where it
#        fits. This is called "aligning". It is the longest step.
# Why:   A read is only a short piece of sequence. Only when we know where
#        on the genome it comes from can we say which gene it belongs to.
# Options:
#   --paired_end           the reads come in pairs (_p1 and _p2). The two
#                          reads of a pair are joined into one "fragment".
#   --max_fragment_length  ignore fragments longer than 1000 letters. Real
#                          ones are a few hundred letters long. Longer ones
#                          are mistakes: the two reads were placed on two
#                          different copies of a gene that exists several
#                          times (mostly ribosomal RNA genes).
#   --processes            how many cores to use
#   --segemehl_accuracy    a read must match the genome in at least 95 %
#                          of its letters
#   --fastq                the read files are in FASTQ format
#   --min_phred_score      cut letters with a quality below 25 off the end
#                          of each read
#   --progress             show how far the alignment is
# ---------------------------------------------------------------------------
reademption align --project_path READemption_analysis \
    --paired_end \
    --max_fragment_length 1000 \
    --processes $THREADS \
    --segemehl_accuracy 95 \
    --fastq \
    --min_phred_score 25 \
    --progress


# ---------------------------------------------------------------------------
# STEP 6: Calculate the coverage
#
# What:  For every position of the genome, count how many fragments lie
#        on top of it. The result is one "coverage file" per sample.
# Why:   Coverage files can be opened in a genome browser (for example
#        IGV), where you can look at any gene and see how active it is.
#        They are for looking; the statistics use the counts of step 7.
# ---------------------------------------------------------------------------
reademption coverage --project_path READemption_analysis \
    --paired_end \
    --processes $THREADS


# ---------------------------------------------------------------------------
# STEP 7: Count the fragments per gene
#
# What:  For every gene, count how many fragments lie on it.
# Why:   An active gene produces much RNA, so many fragments land on it.
#        These counts are what step 8 compares between the conditions.
# Options:
#   --paired_end      count fragments (joined pairs), not single reads
#   --antisense_only  in this experiment the reads point in the opposite
#                     direction to the gene they come from. That is a
#                     property of the laboratory method. So we count the
#                     fragments that point the "wrong" way.
#   --features        which kinds of gene to count: protein-coding genes
#                     (CDS), transfer RNA (tRNA) and ribosomal RNA (rRNA)
# ---------------------------------------------------------------------------
reademption gene_quanti --project_path READemption_analysis \
    --paired_end \
    --antisense_only \
    --processes $THREADS \
    --features CDS,tRNA,rRNA


# ---------------------------------------------------------------------------
# STEP 8: Find the genes that differ between the conditions
#
# What:  The program DESeq2 compares the counts of step 7. It compares
#        every condition with every other one: apigenin with control,
#        salt with control, and apigenin with salt.
# Why:   Counts always differ a little by chance. DESeq2 uses the two
#        replicates to judge whether a difference is larger than chance.
#        For every gene it reports how big the change is and how sure
#        we can be about it.
# Options:
#   --libs             the six samples
#   --conditions       the condition of each sample, in the same order
#   --replicates       the replicate number of each sample, same order
#   --libs_by_species  which samples belong to which organism (here all
#                      six belong to rhizobium)
# ---------------------------------------------------------------------------
SAMPLES=control_R1,control_R2,apigenin_R1,apigenin_R2,salt_R1,salt_R2

reademption deseq --project_path READemption_analysis \
    --libs $SAMPLES \
    --conditions control,control,apigenin,apigenin,salt,salt \
    --replicates 1,2,1,2,1,2 \
    --libs_by_species rhizobium=$SAMPLES


# ---------------------------------------------------------------------------
# STEP 9: Draw the plots
#
# What:  Three commands, each draws a group of plots as PDF files.
# Why:   A plot shows at a glance what a table with thousands of rows
#        cannot: how many reads were aligned, what kind of RNA they come
#        from, and which genes changed.
# ---------------------------------------------------------------------------
# How many reads were aligned, and how long the reads are
reademption viz_align --project_path READemption_analysis --paired_end

# How the counts are spread over the kinds of RNA, and how similar the samples are
reademption viz_gene_quanti --project_path READemption_analysis --paired_end

# Which genes changed (MA plots and volcano plots)
reademption viz_deseq --project_path READemption_analysis


# ---------------------------------------------------------------------------
# STEP 10: Copy the most important results into one small folder
#
# What:  "cp" copies files. "*.csv" means: every file that ends in .csv.
# Why:   The folder READemption_analysis is very large (tens of GB). The
#        tables and plots that most people want are only a few MB. They
#        are copied into "results", which is small enough to share.
# ---------------------------------------------------------------------------
OUTPUT=READemption_analysis/output
mkdir -p results

# the read-quality report of step 4
cp qc/multiqc_report.html results/

# the alignment numbers of step 5: once counted in reads, once counted
# in fragments (a fragment is a pair of reads joined together)
cp $OUTPUT/align/reports_and_stats/read_alignment_stats.csv results/
cp $OUTPUT/align/reports_and_stats/fragment_alignment_stats.csv results/

# the gene tables of step 8
cp $OUTPUT/rhizobium_deseq/deseq_with_annotations/*.csv results/

# the plots of step 9
cp $OUTPUT/rhizobium_viz_align/*.pdf results/
cp $OUTPUT/read_lengths_viz_align/*.pdf results/
cp $OUTPUT/rhizobium_viz_gene_quanti/*.pdf results/
cp $OUTPUT/rhizobium_viz_deseq/*.pdf results/

echo "Finished. The key results are in the folder: results"

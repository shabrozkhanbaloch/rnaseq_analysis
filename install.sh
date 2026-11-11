#!/usr/bin/env bash
###############################################################################
# install.sh - set up everything needed to run the RNA-seq analyses
#
# What it does
#   1. Checks that conda is available on this computer.
#   2. Creates two conda environments from the files in envs/:
#        reademption  - the READemption pipeline (aligner, R, DESeq2)
#        rnaseq_qc    - quality control and download tools
#   3. Tests every tool and prints a PASS/FAIL summary.
#
# How to run it (from the repository folder)
#   bash install.sh
#
# It is safe to run more than once: environments that already exist are
# left alone. To rebuild one from scratch, remove it first, for example:
#   conda env remove -n reademption -y
#
# Needs: Linux (64-bit), an internet connection, about 5 GB of free disk
# space, and 5-15 minutes.
#
# What is a "conda environment"?
#   A separate folder holding a set of programs in fixed versions. Programs
#   in one environment cannot disturb programs in another, and nothing else
#   on your computer is changed.
#
# How to read this file if you are new to shell scripts
#   - A line starting with "#" is a note for humans. The computer skips it.
#   - NAME=value stores a value under a name. $NAME uses it again later.
#   - The script runs from top to bottom, one step after the other.
###############################################################################

# Safety switch: stop immediately if any command fails.
#   -e           stop on the first error
#   -u           stop if a name is used that was never given a value (a typo)
#   -o pipefail  also notice errors inside commands joined with "|"
set -euo pipefail

# Find the folder this script is stored in and remember it as REPO_DIR.
# This way the script works no matter which folder you start it from.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# A list of the environments to create. Each line has two parts joined by a
# colon:   <name of the environment> : <file that lists its programs>
ENVIRONMENTS=(
    "reademption:envs/reademption.yml"
    "rnaseq_qc:envs/rnaseq_qc.yml"
)

# A list of the tests to run at the end. Each line has three parts joined
# by "|":
#     <environment> | <name shown on screen> | <command that tests the tool>
# A test passes when its command runs without an error. Most of them simply
# ask the tool for its version number, which only works if the tool starts.
CHECKS=(
    "reademption|READemption 2.0.4|reademption --version 2>&1 | grep -q 2.0.4"
    "reademption|segemehl aligner|segemehl.x 2>&1 | grep -qi segemehl"
    "reademption|R|Rscript --version"
    "reademption|DESeq2 (R package)|Rscript -e 'library(DESeq2)'"
    "reademption|pysam (Python package)|python -c 'import pysam'"
    "rnaseq_qc|FastQC|fastqc --version"
    "rnaseq_qc|MultiQC|multiqc --version"
    "rnaseq_qc|fastp|fastp --version"
    "rnaseq_qc|samtools|samtools --version"
    "rnaseq_qc|SRA tools|fasterq-dump --version"
)

# ----------------------------------------------------------------------------
# Step 1 - find conda
# ----------------------------------------------------------------------------
echo "==> Step 1/3: looking for conda"

# "command -v conda" asks: is there a program called conda? The "!" turns
# the question around, so the lines up to "fi" only run if conda is MISSING.
# They print the text between the two "MSG" markers and then stop the
# script ("exit 1" = stop and report a problem).
if ! command -v conda >/dev/null 2>&1; then
    cat >&2 <<'MSG'

ERROR: conda was not found on this computer.

Install Miniforge (a free, small conda installer) with these two commands,
then close the terminal, open a new one, and run "bash install.sh" again:

  wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
  bash Miniforge3-Linux-x86_64.sh

MSG
    exit 1
fi

echo "    found $(conda --version)"

# A small helper called "env_exists". "env_exists reademption" answers the
# question: is there already an environment named reademption?
# How: "conda env list" prints all environments, "awk" keeps the first
# column (the names), and "grep -qx" looks for an exact match. "$1" stands
# for the name written after env_exists.
env_exists() {
    conda env list | awk '{print $1}' | grep -qx "$1"
}

# ----------------------------------------------------------------------------
# Step 2 - create the environments
# ----------------------------------------------------------------------------
echo "==> Step 2/3: creating the conda environments"

# "for entry in ..." repeats the lines between "do" and "done" once for each
# line of the ENVIRONMENTS list above.
#
# Worked example for the first line, "reademption:envs/reademption.yml":
#   name = reademption              (the part before the colon)
#   file = envs/reademption.yml     (the part after the colon)
# If that environment already exists it is skipped; otherwise
# "conda env create" downloads and installs every program listed in the file.
for entry in "${ENVIRONMENTS[@]}"; do
    name="${entry%%:*}"     # keep the text before the colon
    file="${entry#*:}"      # keep the text after the colon

    if env_exists "$name"; then
        echo "    '$name' already exists - skipping"
    else
        echo "    creating '$name' from $file (this takes a few minutes)"
        conda env create --yes --name "$name" --file "$REPO_DIR/$file"
    fi
done

# ----------------------------------------------------------------------------
# Step 3 - test that every tool starts
# ----------------------------------------------------------------------------
echo "==> Step 3/3: testing the installed tools"

# "failed" counts how many tests did not pass. It starts at zero.
failed=0

# The loop runs once for each line of the CHECKS list above.
for check in "${CHECKS[@]}"; do
    # Cut the line at every "|" into its three parts.
    # Example: "rnaseq_qc|FastQC|fastqc --version" becomes
    #   env     = rnaseq_qc
    #   label   = FastQC
    #   command = fastqc --version
    IFS='|' read -r env label command <<<"$check"

    # "conda run -n <environment> <command>" runs one command inside an
    # environment. If it works, print PASS; otherwise print FAIL and add 1
    # to the counter. (">/dev/null 2>&1" hides the tool's own output, and
    # "printf" prints text lined up in neat columns.)
    if conda run -n "$env" bash -c "$command" >/dev/null 2>&1; then
        printf '    PASS  %-12s %s\n' "[$env]" "$label"
    else
        printf '    FAIL  %-12s %s\n' "[$env]" "$label"
        failed=$((failed + 1))
    fi
done

# Final message. "-gt 0" means "greater than 0": if at least one test
# failed, say so and stop with a problem report; otherwise report success.
echo
if [ "$failed" -gt 0 ]; then
    echo "Installation finished with $failed failed check(s)." >&2
    echo "See the Troubleshooting section of readme.md." >&2
    exit 1
fi

echo "Installation complete. Every tool is working."
echo "Next step: run one of the analyses described in readme.md."

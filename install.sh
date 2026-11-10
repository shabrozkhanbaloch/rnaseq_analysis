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
###############################################################################

# Stop at the first error, on unset variables, and on errors inside pipes.
set -euo pipefail

# Folder this script lives in, so it works no matter where it is called from.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The environments to create: "<name>:<definition file>".
ENVIRONMENTS=(
    "reademption:envs/reademption.yml"
    "rnaseq_qc:envs/rnaseq_qc.yml"
)

# The checks to run afterwards: "<environment>|<label>|<command>".
# A check passes when its command exits without an error.
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

# Returns success when a conda environment with the given name exists.
env_exists() {
    conda env list | awk '{print $1}' | grep -qx "$1"
}

# ----------------------------------------------------------------------------
# Step 2 - create the environments
# ----------------------------------------------------------------------------
echo "==> Step 2/3: creating the conda environments"

for entry in "${ENVIRONMENTS[@]}"; do
    name="${entry%%:*}"     # text before the colon
    file="${entry#*:}"      # text after the colon

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

failed=0
for check in "${CHECKS[@]}"; do
    # Split "<environment>|<label>|<command>" into its three parts.
    IFS='|' read -r env label command <<<"$check"

    # "conda run" executes one command inside an environment without
    # having to activate it first.
    if conda run -n "$env" bash -c "$command" >/dev/null 2>&1; then
        printf '    PASS  %-12s %s\n' "[$env]" "$label"
    else
        printf '    FAIL  %-12s %s\n' "[$env]" "$label"
        failed=$((failed + 1))
    fi
done

echo
if [ "$failed" -gt 0 ]; then
    echo "Installation finished with $failed failed check(s)." >&2
    echo "See the Troubleshooting section of readme.md." >&2
    exit 1
fi

echo "Installation complete. Every tool is working."
echo "Next step: run one of the analyses described in readme.md."

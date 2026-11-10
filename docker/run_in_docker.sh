#!/bin/bash
# Run a command (or an interactive shell) inside the RNA-seq container,
# with this repository mounted at /work.
#
#   docker/run_in_docker.sh                                   # interactive shell
#   docker/run_in_docker.sh reademption --version
#   docker/run_in_docker.sh bash 02_publication_rna_seq_analysis_archaea/rnaseq.sh
set -euo pipefail

IMAGE=rnaseq-reademption:2.0.4
# Repository root = the folder above docker/.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TTY_FLAGS="-i"
[ -t 0 ] && TTY_FLAGS="-it"

docker run --rm $TTY_FLAGS \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -e THREADS="${THREADS:-12}" \
    -v "$REPO_DIR":/work \
    -w /work \
    "$IMAGE" "${@:-bash}"

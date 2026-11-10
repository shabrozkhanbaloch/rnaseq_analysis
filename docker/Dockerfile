# READemption 2.0.4 RNA-seq environment
# Optional alternative to install.sh: the same tools in one Docker image.
# Build (from the repository root):
#   docker build -t rnaseq-reademption:2.0.4 docker/
FROM mambaorg/micromamba:2.5.0

COPY --chown=$MAMBA_USER:$MAMBA_USER environment.yml /tmp/environment.yml
RUN micromamba install -y -n base -f /tmp/environment.yml && \
    micromamba clean --all --yes

ENV PATH=/opt/conda/bin:$PATH
ENV MPLCONFIGDIR=/tmp/matplotlib
WORKDIR /work
CMD ["bash"]

#!/usr/bin/env bash
# Simple script to run ctyper with apptainer
# Replicates genotype_hba.wdl

set -euo pipefail

# Arguments
bam=$1
reference=$2
kmerFile=$3
background=$4
inputVcfsGz=$5
outputBase=$6
nProc=${7:-8}

# Get directories for bind mounts
bamDir=$(dirname "$bam")
outDir=$(pwd)
resourceDir=$(dirname "$kmerFile")
referenceDir=$(dirname "$reference")

# Run ctyper in container
apptainer exec \
  --containall \
  --bind "$bamDir" \
  --bind "$outDir" \
  --bind "$resourceDir" \
  --bind "$referenceDir" \
  docker://mchaisso/ctyper:0.3 \
  ctyper -T "$reference" -m "$kmerFile" -i "$bam" -o "${outputBase}.out" -N "$nProc" -b "$background"

# Extract VCFs and convert to final VCF
tar zxvf "$inputVcfsGz"
ResultToVcf.sh "${outputBase}.out" vcfs > "${outputBase}.vcf"

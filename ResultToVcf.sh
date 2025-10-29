#!/usr/bin/env bash
# ResultToVcf.sh - Convert ctyper genotype output to VCF format
#
# This script parses ctyper genotype output and combines haplotype VCFs
# into a single diploid VCF using CombineVcfs.py

set -euo pipefail

# Script usage
usage() {
    cat <<EOF
Usage: $(basename "$0") GENOTYPE_FILE VCF_PATH [OPTIONS]

Convert ctyper genotype output to VCF format.

Positional arguments:
  GENOTYPE_FILE    Output file from ctyper (e.g., sample.out)
  VCF_PATH         Directory containing haplotype VCF files

Optional arguments:
  -s, --sample NAME    Sample name for output VCF (default: SAMPLE)
  -h, --help           Show this help message

Example:
  $(basename "$0") sample.out vcfs > sample.vcf
  $(basename "$0") sample.out vcfs --sample SAMPLE1 > sample.vcf

Output:
  The combined diploid VCF is written to stdout.

EOF
    exit 1
}

# Default sample name
SAMPLE_NAME="SAMPLE"

# Parse arguments - support both positional and optional arguments
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--sample)
            SAMPLE_NAME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            usage
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

# Restore positional parameters
set -- "${POSITIONAL[@]}"

# Check for required positional arguments
if [[ $# -lt 2 ]]; then
    echo "Error: Missing required arguments" >&2
    echo >&2
    usage
fi

gt=$1
vcfPath=$2

# Validate input files
if [[ ! -f "$gt" ]]; then
    echo "Error: Genotype file not found: $gt" >&2
    exit 1
fi

if [[ ! -d "$vcfPath" ]]; then
    echo "Error: VCF directory not found: $vcfPath" >&2
    exit 1
fi

# Parse the ctyper result file
aRes=$(grep result "$gt" | tr "," "\t" | awk '{ print $2;}')
bRes=$(grep result "$gt" | tr "," "\t" | awk '{ print $3;}')

if [[ -z "$aRes" || -z "$bRes" ]]; then
    echo "Error: Could not parse result from genotype file: $gt" >&2
    echo "Expected format: line containing 'result' with comma-separated values" >&2
    exit 1
fi

sa=$(echo "$aRes" | tr "_" "\t" | awk '{ print $2;}')
sb=$(echo "$bRes" | tr "_" "\t" | awk '{ print $2;}')
ha=$(echo "$aRes" | tr "_" "\t" | awk '{ print $3;}' | tr -d "h")
hb=$(echo "$bRes" | tr "_" "\t" | awk '{ print $3;}' | tr -d "h")

# Construct haplotype VCF filenames
hap1_vcf="$vcfPath/$sa.hap${ha}.var.vcf"
hap2_vcf="$vcfPath/$sb.hap${hb}.var.vcf"

# Validate that VCF files exist
if [[ ! -f "$hap1_vcf" ]]; then
    echo "Error: Haplotype 1 VCF not found: $hap1_vcf" >&2
    exit 1
fi

if [[ ! -f "$hap2_vcf" ]]; then
    echo "Error: Haplotype 2 VCF not found: $hap2_vcf" >&2
    exit 1
fi

# Get the directory where this script is located (for CombineVcfs.py)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run CombineVcfs.py
if [[ -x "$SCRIPT_DIR/CombineVcfs.py" ]]; then
    "$SCRIPT_DIR/CombineVcfs.py" --hap1 "$hap1_vcf" --hap2 "$hap2_vcf" --sample "$SAMPLE_NAME"
elif command -v CombineVcfs.py &> /dev/null; then
    CombineVcfs.py --hap1 "$hap1_vcf" --hap2 "$hap2_vcf" --sample "$SAMPLE_NAME"
else
    echo "Error: CombineVcfs.py not found in PATH or script directory" >&2
    exit 1
fi




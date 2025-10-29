#!/usr/bin/env bash
# runCtyper.sh - Run ctyper genotyping using apptainer
# This script replicates the functionality of genotype_hba.wdl

set -euo pipefail

# Script usage
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Run ctyper genotyping using apptainer container.

Required arguments:
  -b, --bam FILE              Input BAM/CRAM file
  -x, --bam-index FILE        Input BAM/CRAM index file
  -r, --reference FILE        Reference genome file
  -k, --kmer-file FILE        Kmer file for ctyper
  -i, --kmer-index FILE       Kmer index file
  -g, --background FILE       Background file
  -v, --vcfs-gz FILE          Input VCFs tarball (tar.gz)
  -o, --output-base NAME      Output base name (default: output)
  -d, --output-dir DIR        Output directory (default: current directory)
  -n, --nproc INT             Number of processors (default: 8)

Optional arguments:
  --container-image IMAGE     Container image (default: docker://mchaisso/ctyper:0.3)
  -h, --help                  Show this help message

Example:
  $(basename "$0") \\
    --bam sample.bam \\
    --bam-index sample.bam.bai \\
    --reference ref.fa \\
    --kmer-file kmers.txt \\
    --kmer-index kmers.idx \\
    --background background.txt \\
    --vcfs-gz vcfs.tar.gz \\
    --output-base sample_output \\
    --output-dir /path/to/output \\
    --nproc 8

EOF
    exit 1
}

# Default values
OUTPUT_BASE="output"
OUTPUT_DIR="$(pwd)"
NPROC=8
CONTAINER_IMAGE="docker://mchaisso/ctyper:0.3"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--bam)
            INPUT_BAM="$2"
            shift 2
            ;;
        -x|--bam-index)
            INPUT_BAM_INDEX="$2"
            shift 2
            ;;
        -r|--reference)
            REFERENCE="$2"
            shift 2
            ;;
        -k|--kmer-file)
            KMER_FILE="$2"
            shift 2
            ;;
        -i|--kmer-index)
            KMER_INDEX="$2"
            shift 2
            ;;
        -g|--background)
            BACKGROUND="$2"
            shift 2
            ;;
        -v|--vcfs-gz)
            INPUTVCFSGZ="$2"
            shift 2
            ;;
        -o|--output-base)
            OUTPUT_BASE="$2"
            shift 2
            ;;
        -d|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -n|--nproc)
            NPROC="$2"
            shift 2
            ;;
        --container-image)
            CONTAINER_IMAGE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option $1"
            usage
            ;;
    esac
done

# Validate required arguments
REQUIRED_ARGS=(
    "INPUT_BAM:Input BAM file"
    "INPUT_BAM_INDEX:Input BAM index file"
    "REFERENCE:Reference genome file"
    "KMER_FILE:Kmer file"
    "KMER_INDEX:Kmer index file"
    "BACKGROUND:Background file"
    "INPUTVCFSGZ:Input VCFs tarball"
)

MISSING_ARGS=()
for arg_spec in "${REQUIRED_ARGS[@]}"; do
    arg_name="${arg_spec%%:*}"
    arg_desc="${arg_spec#*:}"
    if [[ -z "${!arg_name:-}" ]]; then
        MISSING_ARGS+=("$arg_desc (--${arg_name,,})")
    fi
done

if [[ ${#MISSING_ARGS[@]} -gt 0 ]]; then
    echo "Error: Missing required arguments:"
    for missing in "${MISSING_ARGS[@]}"; do
        echo "  - $missing"
    done
    echo
    usage
fi

# Validate that files exist
for file_var in INPUT_BAM INPUT_BAM_INDEX REFERENCE KMER_FILE KMER_INDEX BACKGROUND INPUTVCFSGZ; do
    file_path="${!file_var}"
    if [[ ! -f "$file_path" ]]; then
        echo "Error: File not found: $file_path (${file_var})"
        exit 1
    fi
done

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Convert to absolute paths
INPUT_BAM=$(realpath "$INPUT_BAM")
INPUT_BAM_INDEX=$(realpath "$INPUT_BAM_INDEX")
REFERENCE=$(realpath "$REFERENCE")
KMER_FILE=$(realpath "$KMER_FILE")
KMER_INDEX=$(realpath "$KMER_INDEX")
BACKGROUND=$(realpath "$BACKGROUND")
INPUTVCFSGZ=$(realpath "$INPUTVCFSGZ")
OUTPUT_DIR=$(realpath "$OUTPUT_DIR")

# Determine all unique directories to bind
BAM_DIR=$(dirname "$INPUT_BAM")
BAM_INDEX_DIR=$(dirname "$INPUT_BAM_INDEX")
REF_DIR=$(dirname "$REFERENCE")
KMER_DIR=$(dirname "$KMER_FILE")
KMER_INDEX_DIR=$(dirname "$KMER_INDEX")
BG_DIR=$(dirname "$BACKGROUND")
VCFSGZ_DIR=$(dirname "$INPUTVCFSGZ")

# Collect unique directories for binding
BIND_DIRS=()
for dir in "$BAM_DIR" "$BAM_INDEX_DIR" "$REF_DIR" "$KMER_DIR" "$KMER_INDEX_DIR" "$BG_DIR" "$VCFSGZ_DIR" "$OUTPUT_DIR"; do
    # Check if directory is already in the list
    found=0
    for existing in "${BIND_DIRS[@]}"; do
        if [[ "$existing" == "$dir" ]]; then
            found=1
            break
        fi
    done
    if [[ $found -eq 0 ]]; then
        BIND_DIRS+=("$dir")
    fi
done

# Build bind mount arguments array
BIND_ARGS=()
for dir in "${BIND_DIRS[@]}"; do
    BIND_ARGS+=(--bind "$dir")
done

echo "Running ctyper with apptainer..."
echo "Input BAM: $INPUT_BAM"
echo "Output directory: $OUTPUT_DIR"
echo "Output base: $OUTPUT_BASE"
echo "Container image: $CONTAINER_IMAGE"
echo

# Change to output directory to run commands there
cd "$OUTPUT_DIR"

# Run ctyper via apptainer
echo "Step 1: Running ctyper genotyping..."
apptainer exec \
    --containall \
    "${BIND_ARGS[@]}" \
    "$CONTAINER_IMAGE" \
    ctyper \
        -T "$REFERENCE" \
        -m "$KMER_FILE" \
        -i "$INPUT_BAM" \
        -o "${OUTPUT_BASE}.out" \
        -N "$NPROC" \
        -b "$BACKGROUND"

echo "Step 2: Extracting VCF files..."
tar zxvf "$INPUTVCFSGZ"

echo "Step 3: Converting results to VCF..."
# Get the directory where this script is located (for ResultToVcf.sh)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run ResultToVcf.sh
if [[ -x "$SCRIPT_DIR/ResultToVcf.sh" ]]; then
    "$SCRIPT_DIR/ResultToVcf.sh" "${OUTPUT_BASE}.out" vcfs > "${OUTPUT_BASE}.vcf"
elif command -v ResultToVcf.sh &> /dev/null; then
    ResultToVcf.sh "${OUTPUT_BASE}.out" vcfs > "${OUTPUT_BASE}.vcf"
else
    echo "Warning: ResultToVcf.sh not found. You'll need to run it manually:"
    echo "  ResultToVcf.sh ${OUTPUT_BASE}.out vcfs > ${OUTPUT_BASE}.vcf"
fi

echo
echo "Done! Output files:"
echo "  - ${OUTPUT_DIR}/${OUTPUT_BASE}.out (ctyper genotyping result)"
echo "  - ${OUTPUT_DIR}/${OUTPUT_BASE}.vcf (VCF output)"

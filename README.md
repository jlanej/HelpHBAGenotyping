# HelpHBAGenotyping

HBA genotyping pipeline using ctyper.

## Overview

This repository provides tools for genotyping the HBA region using [ctyper](https://github.com/mctp/ctyper). It includes both WDL workflows for cloud/HPC execution and standalone bash scripts for running with Apptainer/Singularity containers.

## Components

### WDL Workflow (`genotype_hba.wdl`)

Cromwell-compatible workflow for running ctyper genotyping in cloud or HPC environments.

### Bash Scripts

#### `runCtyper.sh`

A standalone bash script that replicates the WDL workflow functionality using Apptainer/Singularity.

**Usage:**
```bash
./runCtyper.sh \
  --bam sample.bam \
  --bam-index sample.bam.bai \
  --reference reference.fa \
  --kmer-file kmers.txt \
  --kmer-index kmers.idx \
  --background background.txt \
  --vcfs-gz vcfs.tar.gz \
  --output-base sample_output \
  --output-dir /path/to/output \
  --nproc 8
```

**Requirements:**
- Apptainer/Singularity installed
- Access to the ctyper container image: `docker://mchaisso/ctyper:0.3`

**Inputs:**
- `--bam`: Input BAM/CRAM file
- `--bam-index`: Input BAM/CRAM index file (.bai or .crai)
- `--reference`: Reference genome FASTA file
- `--kmer-file`: Kmer file for ctyper
- `--kmer-index`: Kmer index file
- `--background`: Background file
- `--vcfs-gz`: Compressed tarball of VCF files (tar.gz)
- `--output-base`: Base name for output files (default: "output")
- `--output-dir`: Output directory (default: current directory)
- `--nproc`: Number of processors (default: 8)

**Outputs:**
- `{output-base}.out`: ctyper genotyping results
- `{output-base}.vcf`: Combined diploid VCF file

#### `ResultToVcf.sh`

Converts ctyper genotype output to a phased diploid VCF format by combining haplotype-specific VCFs.

**Usage:**
```bash
./ResultToVcf.sh genotype.out vcfs/ > output.vcf
./ResultToVcf.sh genotype.out vcfs/ --sample SAMPLE_NAME > output.vcf
```

**Arguments:**
- First positional argument: ctyper genotype output file (e.g., `sample.out`)
- Second positional argument: Directory containing haplotype VCF files
- `--sample`: Optional sample name for output VCF (default: "SAMPLE")

**Output:**
The script writes a phased diploid VCF to stdout.

#### `CombineVcfs.py`

Python utility for merging two haploid VCF files into a single phased diploid VCF.

**Usage:**
```bash
./CombineVcfs.py --hap1 haplotype1.vcf --hap2 haplotype2.vcf --sample SAMPLE_NAME > output.vcf
```

## Example Workflow

### Using the bash script with Apptainer:

```bash
# 1. Run ctyper genotyping
./runCtyper.sh \
  --bam sample.bam \
  --bam-index sample.bam.bai \
  --reference /path/to/ref.fa \
  --kmer-file /path/to/kmers.txt \
  --kmer-index /path/to/kmers.idx \
  --background /path/to/background.txt \
  --vcfs-gz /path/to/vcfs.tar.gz \
  --output-base sample1 \
  --output-dir ./results \
  --nproc 8

# Output files will be in ./results/:
#   - sample1.out (genotyping result)
#   - sample1.vcf (combined VCF)
```

### Manual workflow (individual steps):

```bash
# 1. Run ctyper with apptainer directly
apptainer exec \
  --containall \
  --bind /path/to/data \
  --bind /path/to/output \
  docker://mchaisso/ctyper:0.3 \
  ctyper \
    -T reference.fa \
    -m kmers.txt \
    -i sample.bam \
    -o sample.out \
    -N 8 \
    -b background.txt

# 2. Extract VCF files
tar zxvf vcfs.tar.gz

# 3. Convert results to VCF
./ResultToVcf.sh sample.out vcfs > sample.vcf
```

## Requirements

- **For bash scripts:**
  - Bash 4.0+
  - Apptainer or Singularity
  - Python 3.6+ (for CombineVcfs.py)

- **For WDL workflow:**
  - Cromwell or compatible WDL execution engine
  - Docker (if using Docker backend)

## Container Image

The pipeline uses the ctyper container image: `mchaisso/ctyper:0.3`

This image includes:
- ctyper genotyping tool
- All required dependencies

## Notes

- All input files must be accessible to the container (via bind mounts in Apptainer)
- The scripts automatically handle bind mounting of necessary directories
- File paths are converted to absolute paths automatically
- The VCF extraction step requires the input VCFs to be in a tar.gz archive

## Authors

- Chaisson Lab
- ORCID: 0000-0001-8575-997X

## License

See repository license file.

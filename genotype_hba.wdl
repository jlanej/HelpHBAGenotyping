version 1.0

task GenotypeSample {
    input {
        File input_bam
        File input_bam_index
        File reference
        File KmerFile
        File KmerIndex
        File background
        File inputVcfsGz
        String output_base
        Int nProc
	Int taskDiskSizeGb
    }

    command <<<
        set -euo pipefail
        ctyper -T ~{reference} -m ~{KmerFile} -i ~{input_bam} -o ~{output_base}.out -N ~{nProc} -b ~{background}
        tar zxvf ~{inputVcfsGz}
        ResultToVcf.sh ~{output_base}.out vcfs > ~{output_base}.vcf
    >>>

    output {
        File output_genotype = "~{output_base}.out"
        File output_vcf = "~{output_base}.vcf"
    }

    runtime {
        docker: "mchaisso/ctyper:0.4"
        cpu: 8
        memory: "24G"
	disks: "local-disk " + taskDiskSizeGb + " LOCAL"	
    }
}


workflow RunCtyper {
    input {
        File INPUT_BAM
        File INPUT_BAM_INDEX
        File REFERENCE
        File KMER_FILE
        File KMER_INDEX
        File BACKGROUND
        File INPUTVCFSGZ
        String OUTPUT_BASE
	Int TaskDiskSizeGb	
    }

    call GenotypeSample {
        input:
            input_bam = INPUT_BAM,
            input_bam_index = INPUT_BAM_INDEX,
            KmerFile = KMER_FILE,
            KmerIndex = KMER_INDEX,
            background = BACKGROUND,
            output_base = OUTPUT_BASE,
            inputVcfsGz = INPUTVCFSGZ,
            taskDiskSizeGb = TaskDiskSizeGb
    }

    output {
        File output_genotypes = GenotypeSample.output_genotype
        File output_vcf  = GenotypeSample.output_vcf
    }

    meta {
        description: "Run ctyper on a bam/cram file"
        author: "Chaisson lab"
    }
}


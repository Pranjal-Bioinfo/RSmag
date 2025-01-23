process TRIMMOMATIC_PE {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/5b/5b0d3a2506b11d83b1b35f49d877985a19b50ea12033248ac2f75cc193a4598f/data':
        'community.wave.seqera.io/library/seqkit_trimmomatic_pigz:086abd749050cbe6' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.paired.trim*.fastq.gz")   , emit: trimmed_reads
    tuple val(meta), path("*.unpaired.trim_*.fastq.gz"), emit: unpaired_reads, optional:true
    tuple val(meta), path("*_out.log")                 , emit: out_log
    path "versions.yml"                                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def seqkit_input = "-1 ${reads[0]} -2 ${reads[1]}"
    def chunk_prefixes = reads.collect { file( "$it" - '.gz' ).baseName }
    def chunk_extension = file( "${reads[0]}" - '.gz' ).extension
    """
    mkdir chunks

    mkdir trimmed_R1
    mkdir unpaired_R1

    mkdir trimmed_R2
    mkdir unpaired_R2

    seqkit \\
        split2 \\
        -j $task.cpus \\
        $seqkit_input \\
        -p 6 \\
        -O chunks \\
        -f

    for i in {001..006}; do
        trimmomatic \\
            PE -threads 2 \\
            chunks/${chunk_prefixes[0]}.part_\${i}.${chunk_extension}.gz chunks/${chunk_prefixes[1]}.part_\${i}.${chunk_extension}.gz \\
            trimmed_R1/trimmed_R1_\${i}.fastq.gz unpaired_R1/unpaired_R1_\${i}.fastq.gz \\
            trimmed_R2/trimmed_R2_\${i}.fastq.gz unpaired_R2/unpaired_R2_\${i}.fastq.gz \\
            $args \\
            2> >(tee ${prefix}_\${i}.log >&2) &
    done
    wait

    if [[ ! \$(ls trimmed_R1) ]]; then
        echo "trimmomatic PE failed to produce trimmed output. See logs for details."
        exit 1
    fi

    cat \\
        trimmed_R1/trimmed_R1_*.fastq.gz \\
        > ${prefix}.paired.trim_1.fastq.gz

    cat \\
        trimmed_R2/trimmed_R2_*.fastq.gz \\
        > ${prefix}.paired.trim_2.fastq.gz

    cat ${prefix}_*.log \\
        > ${prefix}_out.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        trimmomatic: \$(trimmomatic -version)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"

    output_command  = "echo '' | gzip > ${prefix}.paired.trim_1.fastq.gz\n"
    output_command += "echo '' | gzip > ${prefix}.paired.trim_2.fastq.gz\n"
    output_command += "echo '' | gzip > ${prefix}.unpaired.trim_1.fastq.gz\n"
    output_command += "echo '' | gzip > ${prefix}.unpaired.trim_2.fastq.gz"

    """
    $output_command
    touch ${prefix}_out.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        trimmomatic: \$(trimmomatic -version)
    END_VERSIONS
    """

}

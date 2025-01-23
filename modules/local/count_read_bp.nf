process COUNT_READ_BP {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:22.04' :
        'nf-core/ubuntu:22.04' }"


    input:
    tuple val(meta), path(reads, stageAs: '?/*')

    output:
    tuple val(meta), path("*.log")  , emit: log
    path "versions.yml"             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "$meta.id"
    """
    touch ${prefix}.log

    for i in $reads; do
        gzip -dc \$i \\
            | awk \\
            'NR%4==2 { c++; l+=length(\$0) } END \\
            { print "File name: '\$i'"; print "Number of reads: "c; print "Number of bases in reads: "l }' \\
            &>> ${prefix}.log
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: "\$(awk -W version |& head -n1)"
    END_VERSIONS
    """
}

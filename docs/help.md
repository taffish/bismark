taf-bismark 3.3.0-r1 — align bisulfite reads, extract calls and view reports

Usage:
  Start in a writable project directory with your reference FASTA and reads.
  taf-bismark --help                      Show this wrapper help
  taf-bismark --version                   Show the package version
  taf-bismark -- --version                Show the upstream version
  taf-bismark bismark align --help         Show alignment options
  taf-bismark bismark2report --help        Show one command's options

Examples:
  Put the selected assembly's FASTA in reference/ before preparing it:
  taf-bismark bismark_genome_preparation --bowtie2 reference/
  taf-bismark bismark --bowtie2 --genome reference/ --basename sample reads.fq.gz
  For paired-end reads, start a fresh output directory for each run:
  taf-bismark bismark --genome reference/ -o paired -1 R1.fq.gz -2 R2.fq.gz

BAM and the text alignment report are written in the working directory or -o DIR.
Use a separate writable scratch/output directory per job. Converted reads stream
by default when supported. For temporary files instead, add --no_stream_converted;
allow enough scratch space. Select the same aligner when preparing and using an
index. To use HISAT2, for example, specify --hisat2 in both commands.

For paired-end directional TAPS input (not ordinary bisulfite reads):
  taf-bismark bismark_genome_preparation --bwamem3 reference/
  taf-bismark bismark --taps --genome reference/ -o taps -1 R1.fq.gz -2 R2.fq.gz
Keep the original FASTA and the complete Bwamem3_Index/ together. On x86-64,
bwa-mem3 needs AVX2. Preparation needs assembly-sized disk and memory.

Reuse a shared reference read-only:
  The administrator prepares the complete reference as above and grants users
  read/traverse access. Set an absolute host reference path without spaces:
  BISMARK_REF=/srv/references/bismark/assembly-bowtie2
  TAFFISH_CONTAINER_BACKEND=docker TAFFISH_DOCKER_RUN_ARGS="-v ${BISMARK_REF}:/mnt:ro" taf-bismark bismark --genome /mnt reads.fq.gz
  TAFFISH_CONTAINER_BACKEND=podman TAFFISH_PODMAN_RUN_ARGS="-v ${BISMARK_REF}:/mnt:ro" taf-bismark bismark --genome /mnt reads.fq.gz
  TAFFISH_CONTAINER_BACKEND=apptainer TAFFISH_APPTAINER_RUN_ARGS="--bind ${BISMARK_REF}:/mnt:ro" taf-bismark bismark --genome /mnt reads.fq.gz

Extract and view results (single-end example above):
  taf-bismark bismark_methylation_extractor --single-end --bedGraph --comprehensive sample.bam
  taf-bismark bismark2report --alignment_report sample_SE_report.txt --output sample-report.html
  taf-bismark bismark2summary -o project-summary sample.bam
Run these in the directory with the BAM and matching report(s). Open
sample-report.html or project-summary.html in your browser; project-summary.txt
contains the tabular summary. The HTML files work offline without a server,
display forwarding or a port on Docker, Podman and Apptainer.

If no index is found, check that the original FASTA and its Bisulfite_Genome/
are together under --genome and match the chosen backend. Nothing is downloaded.
For a trusted filename containing spaces in TAFFISH 0.12, pass the inner quotes,
e.g. taf-bismark bismark --genome reference/ '"reads with spaces.fq"'.
More commands, version changes and reference provenance: see the app README.

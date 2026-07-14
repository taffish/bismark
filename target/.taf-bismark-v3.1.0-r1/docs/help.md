BISMARK 3.1.0 FOR TAFFISH

Bisulfite read alignment, methylation extraction, conversion, QC, and reports.

USAGE
  taf-bismark --help
  taf-bismark --version
  taf-bismark -- --help
  taf-bismark -- --version
  taf-bismark bismark [ALIGN OPTIONS]
  taf-bismark COMMAND [ARGS...]

COMMON WORKFLOWS
  Prepare a Bowtie 2 reference:
    taf-bismark bismark_genome_preparation --bowtie2 reference/

  Prepare a HISAT2 or minimap2 reference:
    taf-bismark bismark_genome_preparation --hisat2 reference/
    taf-bismark bismark_genome_preparation --minimap2 reference/

  Align single-end or paired-end reads:
    taf-bismark bismark --genome reference/ reads.fastq.gz
    taf-bismark bismark --genome reference/ -1 R1.fq.gz -2 R2.fq.gz

  Extract methylation calls and bedGraph output:
    taf-bismark bismark_methylation_extractor \
      --paired-end --bedGraph sample_bismark_bt2_pe.bam

  Generate per-sample and project reports:
    taf-bismark bismark2report --alignment_report sample_report.txt
    taf-bismark bismark2summary sample_bismark_bt2.bam

PACKAGED BISMARK COMMANDS
  bismark                         Alignment and multicall suite entry
  bismark_genome_preparation      Reference conversion and indexing
  deduplicate_bismark             PCR duplicate removal
  bismark_methylation_extractor   Methylation-call extraction
  bismark2bedGraph                bedGraph and coverage generation
  coverage2cytosine               Genome-wide cytosine reports
  bam2nuc                         Nucleotide-composition QC
  NOMe_filtering                  Per-read NOMe-seq filtering
  filter_non_conversion           Incomplete-conversion filtering
  methylation_consistency         Read-level consistency splitting
  bismark2report                  Per-sample HTML report
  bismark2summary                 Multi-sample text and HTML summary

ALIGNMENT BACKENDS
  Bowtie 2 2.5.5, HISAT2 2.2.2, minimap2 2.31-r1302, and rammap 1.1.1 are
  included. The default --rammap path runs in process; --rammap_subprocess uses
  the bundled rammap CLI. Both rammap paths are experimental upstream.

COMMAND MODE
  Use taf-bismark bismark SUBCOMMAND ... for the Rust multicall interface, or
  invoke a canonical command directly. Do not write taf-bismark prepare ...;
  TAFFISH would interpret prepare as a container executable.

INPUTS AND OUTPUTS
  Users supply reference FASTA files and read/alignment inputs. Reference
  indices, BAM files, methylation tables, bedGraph/coverage files, text reports,
  and HTML reports are written by upstream commands. Use --output_dir or --dir
  where supported to keep outputs organized.

REFERENCE DATA AND RESOURCES
  No database, genome, or prebuilt index is embedded. Prepare references once
  with the selected backend and preserve the complete Bisulfite_Genome folder.
  Mammalian indexing and non-directional alignment can require substantial RAM
  and disk. Both linux/amd64 and linux/arm64 images are native and runtime is
  offline-safe.

BOUNDARIES
  This packages the GA Rust Suite, not legacy Perl Bismark 0.25.1. BAM is the
  supported aligner output default; upstream currently marks --sam and --cram
  aligner output as deferred. Rust post-processing uses pure-Rust I/O, so
  samtools and compatibility --samtools_path values are not runtime needs.
  For byte identity, upstream deliberately keeps v0.25.1 in some BAM @PG and
  report headers; the executable suite version remains 3.1.0.
  Trim Galore, references, and scientific defaults are external.

WRAPPER OPTIONS
  taf-bismark --help       Show this TAFFISH help.
  taf-bismark --version    Show TAFFISH wrapper version.
  taf-bismark --compile    Compile the TAFFISH wrapper.
  taf-bismark -- --help    Pass an option to the default bismark command.

LICENSE AND DOCUMENTATION
  TAFFISH packaging: Apache-2.0
  Bismark: GPL-3.0-only
  rammap: MIT
  Manual: https://felixkrueger.github.io/Bismark/
  Release: https://github.com/FelixKrueger/Bismark/releases/tag/bismark-rust-v3.1.0
  Citation DOI: 10.1093/bioinformatics/btr167

# bismark

`bismark` packages the Bismark Rust Suite for TAFFISH.

Package identity:

- name: `bismark`
- command: `taf-bismark`
- kind: `tool`
- version: `3.1.0-r1`
- container image: `ghcr.io/taffish/bismark:3.1.0-r1`
- upstream tag: `bismark-rust-v3.1.0`
- runtime version: `Bismark Version: v3.1.0`
- native platforms: `linux/amd64`, `linux/arm64`
- license: Apache-2.0 for the TAFFISH app packaging
- upstream license: `GPL-3.0-only`
- upstream: [FelixKrueger/Bismark](https://github.com/FelixKrueger/Bismark)

## What This App Packages

Bismark 3.1.0 is the first generally available Rust-suite line. It supersedes
the maintenance-frozen Perl 0.25.1 line while retaining the 12 canonical tool
names and the faithful default output contract validated by upstream against
Perl 0.25.1.

The image uses the upstream release binaries built with `rammap-inprocess` and
`binseq-input`. It also supplies the exact external aligner versions against
which upstream validates the suite:

- Bowtie 2 2.5.5
- HISAT2 2.2.2
- minimap2 2.31-r1302
- rammap 1.1.1

The aligners are built from checksum-pinned source. The Bioconda SIMDe
portability patch is applied to HISAT2 so both published architectures are
native builds. Exact source archives, licenses, patch provenance, and checksums
are retained under `/opt/bismark/share` and `/opt/aligners/share`.

## Scope

This app supports:

- Bowtie 2, HISAT2, minimap2, and both rammap Bismark alignment paths
- bisulfite genome preparation, including combined indices and composition
- deduplication, methylation extraction, bedGraph and cytosine reports
- BAM/CRAM-aware QC, filtering, consistency analysis, HTML reports, and summary
- WGBS, RRBS, PBAT, EM-seq, NOMe-seq, BINSEQ, and upstream 5-Base interfaces
- native `linux/amd64` and `linux/arm64` containers

This app does not include:

- reference genomes or prebuilt genome indices
- read trimming tools such as Trim Galore
- the frozen Perl Bismark 0.25.1 scripts
- samtools, which is not required by the Rust suite's pure-Rust alignment I/O

## Container Contents

The 12 canonical Bismark commands are:

- `bismark`
- `deduplicate_bismark`
- `bismark_methylation_extractor`
- `bismark2bedGraph`
- `coverage2cytosine`
- `bismark_genome_preparation`
- `bam2nuc`
- `NOMe_filtering`
- `filter_non_conversion`
- `methylation_consistency`
- `bismark2report`
- `bismark2summary`

The image also includes `bowtie2`, `bowtie2-build`, `bowtie2-inspect`,
`hisat2`, `hisat2-build`, `hisat2-inspect`, minimap2, rammap 1.1.1, Perl, Python 3, and
`procps`. `procps` preserves compatibility with task wrappers that collect
process metrics, including nf-core/Nextflow-style wrappers.

## Usage

Access the upstream suite help and version:

```sh
taf-bismark -- --help
taf-bismark -- --version
```

Prepare a reference with the default Bowtie 2 backend:

```sh
taf-bismark bismark_genome_preparation --bowtie2 reference/
```

Align single-end reads:

```sh
taf-bismark bismark --genome reference/ reads.fastq.gz
```

Align paired-end reads with HISAT2:

```sh
taf-bismark bismark --hisat2 --genome reference/ \
  -1 sample_R1.fastq.gz -2 sample_R2.fastq.gz
```

Extract methylation calls and produce bedGraph output:

```sh
taf-bismark bismark_methylation_extractor \
  --paired-end --bedGraph sample_bismark_bt2_pe.bam
```

Generate an HTML report:

```sh
taf-bismark bismark2report \
  --alignment_report sample_bismark_bt2_PE_report.txt
```

## Command Mode

`bismark` is the default upstream command. Use `--` for option-leading
arguments intended for it, such as `taf-bismark -- --help`.

TAFFISH automatic command mode treats the first non-option token as an
executable. Therefore use `taf-bismark bismark prepare ...` for the Rust
multicall subcommand interface, or invoke the corresponding canonical command
directly, such as `taf-bismark bismark_genome_preparation ...`. Do not use
`taf-bismark prepare ...`, because `prepare` is a Bismark subcommand rather
than a container executable.

## Inputs

| Input | Meaning | Notes |
| --- | --- | --- |
| reference directory | FASTA reference and generated bisulfite indices | User supplied; prepare once per backend/options set |
| FASTQ/FASTA/uBAM/BINSEQ | Alignment reads | Exact support varies by upstream mode; see command help |
| BAM/SAM/CRAM | Post-alignment inputs | Accepted by the relevant Rust post-processing commands |
| coverage/call tables | bedGraph, cytosine, and NOMe inputs | Formats follow Bismark conventions |

## Output Notes

Bismark writes alignment files, text reports, methylation-call tables,
bedGraph/coverage files, cytosine reports, QC statistics, and HTML reports into
the current directory unless an upstream `--output_dir` or `--dir` option is
used. Run in a writable mounted working directory and set output directories
explicitly in automated analyses.

## Resources, Databases, and Platform

No external database is required. Reference FASTA files and their derived
indices remain user data and are not embedded in the image. Indexing and
alignment resource use scale with genome size; mammalian references require
substantial disk and memory, especially non-directional or parallel combined
index modes. The upstream `--combined_index_sequential` path is the lower-memory
combined-index option.

Both `linux/amd64` and `linux/arm64` are native. The image does not require
network access at runtime.

## Boundaries

- The canonical `bismark -v`/`--version` wrapper reproduces the
  nf-core/methylseq-readable banner and reports the real suite version. All
  non-version invocations execute the unchanged upstream multicall binary.
- To preserve byte-identical output against the frozen Perl oracle, upstream
  intentionally keeps `v0.25.1` in some alignment-report headers, extractor
  headers, and BAM `@PG` records. Those compatibility markers do not identify
  the installed executable; `bismark --version` reports Rust Suite 3.1.0.
- The release binary contains in-process rammap. The pinned rammap 1.1.1 CLI is
  also bundled because upstream probes it during configuration and uses it when
  `--rammap_subprocess` is requested. Both paths remain experimental upstream
  and are concordance-validated rather than byte-identical to minimap2.
- Upstream currently labels aligner `--sam` and `--cram` output paths as
  deferred; BAM is the supported default. Post-processing commands retain their
  documented BAM/SAM/CRAM input capabilities.
- Compatibility options named `--samtools_path` are accepted and ignored by
  Rust commands that now use pure-Rust I/O. This image does not pretend to
  provide samtools.
- Scientific settings, library directionality, trimming, references, and
  interpretation remain the user's responsibility.

## Troubleshooting

- If Bismark cannot find an index, prepare the same reference with the selected
  backend and keep the complete `Bisulfite_Genome` directory together.
- If a path is interpreted as a TAFFISH command, use the explicit upstream
  executable form, for example `taf-bismark bismark --genome ...`.
- If a run exhausts memory, reduce backend threads or select the documented
  sequential combined-index mode rather than the parallel combined model.

## Testing

The independent offline smoke tests cover:

- all 12 canonical command identities and exact dependency versions
- real reference conversion, indexing, and alignment through Bowtie 2, HISAT2,
  minimap2, in-process rammap, and subprocess rammap paths
- deduplication, extraction, bedGraph, cytosine conversion, nucleotide QC,
  non-conversion filtering, consistency splitting, NOMe filtering, and reports
- retained source/checksum provenance and dynamic-library closure

The smoke suite is a packaging and minimum-function gate, not a replacement for
full scientific validation on production data.

## License and Citation

TAFFISH app packaging: Apache-2.0.

Bismark: GPL-3.0-only. Bowtie 2 and HISAT2 are GPL-3.0-or-later; minimap2 and
rammap are MIT. Bundled components retain their own notices in the image.

Cite Bismark as described by upstream:

> Krueger F, Andrews SR. Bismark: a flexible aligner and methylation caller for
> Bisulfite-Seq applications. Bioinformatics. 2011;27(11):1571-1572.
> <https://doi.org/10.1093/bioinformatics/btr167>

Upstream documentation: <https://felixkrueger.github.io/Bismark/>

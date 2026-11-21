# Bismark for TAFFISH

`taf-bismark` runs the [Bismark Rust Suite](https://github.com/FelixKrueger/Bismark/releases/tag/bismark-rust-v3.3.0) for bisulfite read alignment, methylation extraction, QC and offline reporting. The TAFFISH tool version is **3.3.0-r1**; the image is `ghcr.io/taffish/bismark:3.3.0-r1` (native Linux amd64 and arm64). For runnable examples, see [command help](docs/help.md) or `taf-bismark --help`.

## First run

Once the version is in the Hub, install it with `taf install bismark 3.3.0-r1`. From a source checkout, use `taf install --from .` instead. `taf-bismark --version` identifies the package; `taf-bismark -- --version` identifies the Bismark executable.

Start in a fresh, writable project directory with `reads.fq.gz` and the chosen assembly's FASTA in `reference/`:

```sh
taf-bismark bismark_genome_preparation --bowtie2 reference/
taf-bismark bismark --genome reference/ --basename sample reads.fq.gz
taf-bismark bismark_methylation_extractor --single-end --bedGraph --comprehensive sample.bam
taf-bismark bismark2report --alignment_report sample_SE_report.txt --output sample-report.html
taf-bismark bismark2summary -o project-summary sample.bam
```

Open `sample-report.html` for this alignment or `project-summary.html` for the project; `project-summary.txt` is the matching table. Each page embeds its plotting code. No server, port, network or graphical environment is required on the analysis machine. Keep the BAM and conventionally named text reports together for summary discovery. If optional reports are elsewhere, pass their paths to `bismark2report`. Missing optional measurements are not zero-valued observations.

The reports retain upstream rendering behavior. With missing optional reports (or single-end input), the sample page can leave unused script placeholders for absent panels; the available panels still render. The project chart uses cumulative stack heights, so a hover value is not necessarily the individual category count, and its absolute-count plot can omit raw aligned reads when there is no deduplication report. Use the accompanying `project-summary.txt` and per-sample text reports for exact counts; do not infer zero from a missing panel or deduplicate an assay just to populate a chart. Narrow screens may require zooming or horizontal scrolling. TAFFISH does not rewrite these upstream reports.

## Reference data and shared use

There is no Bismark model, standard database or automatic downloader. Supply the FASTA for the required assembly. Record its source, assembly/version, checksum, Bismark version and the index backend/options. The original FASTA **and** the entire derived `Bisulfite_Genome/` tree (or `Bwamem3_Index/` for bwa-mem3) constitute the reference. Do not reuse an index built for another backend, assembly or index layout. rammap uses the minimap2 index. Genome preparation writes next to the FASTA; budget memory and disk for the selected genome. For memory-constrained combined index preparation, see `--combined_index_sequential` in preparation help.

On a shared system, an administrator or designated owner can build and verify a new reference in its own writable directory and give users read access to files and traversal access to directories. Ordinary users can then mount that complete versioned directory **read-only**. The [help](docs/help.md) gives a copyable command for Docker, Podman and Apptainer. Select `--genome /mnt` inside the container, keep each job's inputs and writable outputs in its own working directory and do not run preparation against the read-only tree. Changing the reference means preparing a different directory, not overwriting the one in use. Reading and analysis require no network.

## Commands and aligners

| Reference or report | Docker | Podman | Apptainer |
| --- | --- | --- | --- |
| Share an existing reference | `TAFFISH_DOCKER_RUN_ARGS="-v ${BISMARK_REF}:/mnt:ro"` | `TAFFISH_PODMAN_RUN_ARGS="-v ${BISMARK_REF}:/mnt:ro"` | `TAFFISH_APPTAINER_RUN_ARGS="--bind ${BISMARK_REF}:/mnt:ro"` |
| Read sample/project HTML | Open the output file locally | Same | Same |

Set `TAFFISH_CONTAINER_BACKEND` to the matching backend; the [help](docs/help.md) shows full invocations. Use references whose terms allow the intended local or shared use; the software license does not grant rights to an assembly.

`bismark` is the default upstream executable. Use `taf-bismark -- --help` for its help, `taf-bismark bismark align --help` for alignment options, or invoke any canonical executable explicitly. Bare `taf-bismark prepare` would ask TAFFISH for an executable named `prepare`.

| Task | Canonical command(s) |
| --- | --- |
| Prepare and align | `bismark_genome_preparation`, `bismark` |
| Deduplicate and extract | `deduplicate_bismark`, `bismark_methylation_extractor` |
| Convert methylation tables | `bismark2bedGraph`, `coverage2cytosine` |
| QC and filtering | `bam2nuc`, `NOMe_filtering`, `filter_non_conversion`, `methylation_consistency` |
| Report | `bismark2report`, `bismark2summary` |

The image contains Bowtie 2 2.5.5 (default), HISAT2 2.2.2, minimap2 2.31-r1302, rammap 1.1.1 and bwa-mem3 0.18.0. bwa-mem3 requires AVX2 on x86-64; ARM64 uses the upstream NEON build. The official binary includes BINSEQ support and in-process rammap; `--rammap_subprocess` selects the separate bundled executable. Both rammap routes are experimental upstream. The default aligner output is BAM. This is not the frozen Perl suite and does not bundle Trim Galore, samtools, references or prebuilt indices.

## What changed in 3.3.0

- Adds bwa-mem3 for paired-end directional TAPS and Illumina 5-Base input. Prepare with `taf-bismark bismark_genome_preparation --bwamem3 reference/`, then use `taf-bismark bismark --taps --genome reference/ -1 R1.fq.gz -2 R2.fq.gz`. Use the matching chemistry, not the default bisulfite path. TAPS does not separate 5mC from 5hmC or call variants.
- Supports unaligned CRAM input and `--cram_ref` for mapped CRAM in the relevant downstream tools. Keep the exact reference FASTA and its index available; consult each command's help.
- Repairs failure-output handling, paired-read validation, nucleotide coverage invocation and report discovery. Removed legacy options fail explicitly.
- Existing named-pipe streaming and the `--no_stream_converted` file fallback remain. Use separate writable scratch/output directories for concurrent jobs.
- Scientific calling behavior changed upstream. Read the [version-matched 5-Base notes](https://github.com/FelixKrueger/Bismark/blob/4eb52d27989bfb52698f1e697fd20c2baaa7f64f/docs/src/content/docs/rust/illumina-5-base.md) before comparing releases. Packaging checks are not scientific validation.

bwa-mem3 indices are assembly-specific and can be large: upstream estimates roughly 104 GB RAM to build a human index and 23 GB for the index; temporary build files require additional disk space. Very small paired-end inputs may not supply enough unique pairs for bwa-mem3's insert-size estimation, yielding no accepted paired alignments; inspect the alignment report and stderr, not just the presence of a BAM. Only tiny artificial references are used in packaging tests. Neither a genome nor a prepared index is downloaded or bundled.

## Build, licenses and citation

Native Docker reported local image sizes of 427,804,194 bytes on amd64 and 438,724,912 bytes on arm64 (not registry download sizes). The added bwa-mem3 runtime includes Debian's OpenMP library and its LLVM dependency; compilers and build caches are not included. Reference FASTA, indices and analysis results are additional disk use. Offline checks cover all five aligners (both rammap routes), actual paired alignments for TAPS and 5-Base, streaming versus files, post-processing and native HTML. Native amd64 Docker/Podman/Apptainer and ARM64 Docker/Podman real-wrapper checks passed, including interrupted index preparation, restoration, repeated use and shared read-only references. These packaging tests do not benchmark large assemblies or validate scientific accuracy.

The official Linux suite assets and source at commit `4eb52d27989bfb52698f1e697fd20c2baaa7f64f` are SHA-256 checked. The canonical version shim exposes the pipeline-compatible banner; other calls go to the upstream executable. Aligner sources are pinned; the retained HISAT2 SIMDe portability patch allows native ARM64 compilation. Base images have fixed digests. Distribution package repositories can change availability, so a clean rebuild also depends on those external inputs.

TAFFISH packaging is Apache-2.0; Bismark is GPL-3.0-only. Bowtie 2 and HISAT2 retain their GPL licenses; minimap2, rammap and bwa-mem3 are MIT. Bundled sources, checksums and third-party notices are under `/opt/bismark/share`, `/opt/aligners/share`, `/opt/rammap/share` and `/opt/bwamem3/share`. See the [upstream manual](https://felixkrueger.github.io/Bismark/) and cite [Krueger and Andrews, Bioinformatics (2011)](https://doi.org/10.1093/bioinformatics/btr167).

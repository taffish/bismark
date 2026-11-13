# Bismark for TAFFISH

`taf-bismark` runs the [Bismark Rust Suite](https://github.com/FelixKrueger/Bismark/releases/tag/bismark-rust-v3.2.0) for bisulfite read alignment, methylation extraction, QC and offline reporting. The TAFFISH tool version is **3.2.0-r1**; the image is `ghcr.io/taffish/bismark:3.2.0-r1` (native Linux amd64 and arm64). For runnable examples, see [command help](docs/help.md) or `taf-bismark --help`.

## First run

Once the version is in the Hub, install it with `taf install bismark 3.2.0-r1`. From a source checkout, use `taf install --from .` instead. `taf-bismark --version` identifies the package; `taf-bismark -- --version` identifies the Bismark executable.

Start in a fresh, writable project directory with `reads.fq.gz` and the chosen assembly's FASTA in `reference/`:

```sh
taf-bismark bismark_genome_preparation --bowtie2 reference/
taf-bismark bismark --genome reference/ --basename sample reads.fq.gz
taf-bismark bismark_methylation_extractor --single-end --bedGraph --comprehensive sample.bam
taf-bismark bismark2report --alignment_report sample_SE_report.txt --output sample-report.html
taf-bismark bismark2summary -o project-summary sample.bam
```

Open `sample-report.html` for this alignment or `project-summary.html` for the project; `project-summary.txt` is the matching table. Each page embeds its plotting code. No server, port, network or graphical environment is required on the analysis machine. Keep the BAM and conventionally named text reports together for summary discovery. If optional reports are elsewhere, pass their paths to `bismark2report`. Missing optional measurements are not zero-valued observations.

## Reference data and shared use

There is no Bismark model, standard database or automatic downloader. Supply the FASTA for the required assembly. Record its source, assembly/version, checksum, Bismark version and the index backend/options. The original FASTA **and** the entire derived `Bisulfite_Genome/` tree constitute the reference. Do not reuse an index built for another backend, assembly or index layout. rammap uses the minimap2 index. Genome preparation writes next to the FASTA; budget memory and disk for the selected genome. For memory-constrained combined index preparation, see `--combined_index_sequential` in preparation help.

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

The image contains Bowtie 2 2.5.5 (default), HISAT2 2.2.2, minimap2 2.31-r1302 and rammap 1.1.1. The official binary includes BINSEQ support and in-process rammap; `--rammap_subprocess` selects the separate bundled executable. Both rammap routes are experimental upstream. The default aligner output is BAM. This is not the frozen Perl suite and does not bundle Trim Galore, samtools, references or prebuilt indices.

## What changed in 3.2.0

- Where supported, converted reads stream through named pipes. HISAT2, subprocess rammap, combined-index modes or a filesystem without FIFO support fall back to temporary files. Use `--no_stream_converted` to request temporary files explicitly. Use separate scratch directories for concurrent jobs; allow disk for the file path.
- Alignment reports, extractor headers and BAM program records now identify the Rust suite version rather than the old Perl compatibility version. MAPQ for some aligner modes has changed; avoid assuming byte identity or interchangeable MAPQ filters across releases.
- For optional Illumina 5-Base analysis, upstream documents reduced coverage and undercalling in CpG-dense, heavily methylated regions. See the [version-matched 5-Base notes](https://github.com/FelixKrueger/Bismark/blob/c94fa14e45709e6b5b3f68e02775f140dd6c15bb/docs/src/content/docs/rust/illumina-5-base.md). A packaging smoke test is not scientific validation.

## Build, licenses and citation

Native Docker reported local image sizes of 245,600,863 bytes on amd64 and 264,432,091 bytes on arm64 (not registry download sizes). Reference FASTA, indices and analysis results are additional disk use. The offline packaging checks exercise the five alignment routes, streaming versus files, post-processing and both HTML reports on a small artificial reference. They do not benchmark large assemblies or validate scientific accuracy.

The official Linux suite assets and source at commit `c94fa14e45709e6b5b3f68e02775f140dd6c15bb` are SHA-256 checked. The canonical version shim exposes the pipeline-compatible banner; other calls go to the upstream executable. Aligner sources are pinned; the retained HISAT2 SIMDe portability patch allows native ARM64 compilation. Base images have fixed digests. Distribution package repositories can change availability, so a clean rebuild also depends on those external inputs.

TAFFISH packaging is Apache-2.0; Bismark is GPL-3.0-only. Bowtie 2 and HISAT2 retain their GPL licenses; minimap2 and rammap are MIT. Bundled sources, checksums and third-party notices are under `/opt/bismark/share`, `/opt/aligners/share` and `/opt/rammap/share`. See the [upstream manual](https://felixkrueger.github.io/Bismark/) and cite [Krueger and Andrews, Bioinformatics (2011)](https://doi.org/10.1093/bioinformatics/btr167).

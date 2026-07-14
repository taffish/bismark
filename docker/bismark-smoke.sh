#!/bin/sh
set -eu

mode="${1:-all}"
tmp="${TMPDIR:-/tmp}/taf-bismark-smoke-$$-${mode}"

cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT HUP INT TERM

make_inputs() {
  mkdir -p "$tmp/genome" "$tmp/reads" "$tmp/out"
  python3 - "$tmp/genome/genome.fa" "$tmp/reads/reads.fq" <<'PY'
import random
import sys

rng = random.Random(310)
sequence = "".join(rng.choice("ACGT") for _ in range(6000))
with open(sys.argv[1], "w", encoding="ascii") as handle:
    handle.write(">chrSmoke\n")
    for offset in range(0, len(sequence), 80):
        handle.write(sequence[offset:offset + 80] + "\n")

starts = (137, 911, 1777, 2903, 4111)
with open(sys.argv[2], "w", encoding="ascii") as handle:
    for index, start in enumerate(starts, 1):
        read = sequence[start:start + 180].replace("C", "T")
        handle.write(f"@smoke{index}\n{read}\n+\n{'I' * len(read)}\n")
PY
}

assert_index() {
  backend="$1"
  case "$backend" in
    bowtie2)
      find "$tmp/genome/Bisulfite_Genome" -type f \( -name '*.bt2' -o -name '*.bt2l' \) -print -quit | grep -q .
      ;;
    hisat2)
      find "$tmp/genome/Bisulfite_Genome" -type f \( -name '*.ht2' -o -name '*.ht2l' \) -print -quit | grep -q .
      ;;
    minimap2)
      find "$tmp/genome/Bisulfite_Genome" -type f -name '*.mmi' -print -quit | grep -q .
      ;;
  esac
}

prepare_backend() {
  backend="$1"
  make_inputs
  bismark_genome_preparation "--$backend" "$tmp/genome" >"$tmp/prepare.stdout" 2>"$tmp/prepare.stderr"
  test -s "$tmp/genome/Bisulfite_Genome/CT_conversion/genome_mfa.CT_conversion.fa"
  test -s "$tmp/genome/Bisulfite_Genome/GA_conversion/genome_mfa.GA_conversion.fa"
  assert_index "$backend"
}

run_backend() {
  backend="$1"
  index_backend="$backend"
  case "$backend" in
    rammap|rammap-subprocess)
      index_backend=minimap2
      ;;
  esac
  prepare_backend "$index_backend"

  set -- "--$backend"
  if [ "$backend" = rammap-subprocess ]; then
    set -- --rammap --rammap_subprocess
  fi
  bismark "$@" \
    --genome "$tmp/genome" \
    --output_dir "$tmp/out" \
    --basename "smoke-$backend" \
    "$tmp/reads/reads.fq" >"$tmp/align.stdout" 2>"$tmp/align.stderr"

  bam="$(find "$tmp/out" -maxdepth 1 -type f -name '*.bam' -print -quit)"
  report="$(find "$tmp/out" -maxdepth 1 -type f -name '*report.txt' -print -quit)"
  test -n "$bam"
  test -s "$bam"
  test -n "$report"
  test -s "$report"
  grep -F "Sequences analysed" "$report" >/dev/null

  case "$backend" in
    rammap)
      grep -F "in-process rammap-core backend" "$tmp/align.stderr" >/dev/null
      ;;
    rammap-subprocess)
      grep -F "subprocess rammap binary" "$tmp/align.stderr" >/dev/null
      ;;
  esac

  if [ "$backend" = bowtie2 ]; then
    bismark2report \
      --alignment_report "$report" \
      --dedup_report none \
      --splitting_report none \
      --mbias_report none \
      --nucleotide_report none \
      --dir "$tmp/out" \
      --output smoke-report.html >/dev/null
    test -s "$tmp/out/smoke-report.html"
    (
      cd "$tmp/out"
      bismark2summary -o smoke-summary "$bam" >/dev/null
    )
    test -s "$tmp/out/smoke-summary.html"
    test -s "$tmp/out/smoke-summary.txt"
  fi
}

identity() {
  bismark --version | grep -Fx "Bismark Version: v3.1.0" >/dev/null
  bismark.bin --version | grep -F "bismark (Bismark Rust suite) v3.1.0" >/dev/null
  bismark --help | grep -F "The Bismark bisulfite-sequencing suite" >/dev/null

  for command in \
    deduplicate_bismark \
    bismark_methylation_extractor \
    bismark2bedGraph \
    coverage2cytosine \
    bismark_genome_preparation \
    bam2nuc \
    NOMe_filtering \
    filter_non_conversion \
    methylation_consistency \
    bismark2report \
    bismark2summary; do
    command -v "$command" >/dev/null
    "$command" --version | grep -F "(Bismark Rust suite) v3.1.0" >/dev/null
  done

  bowtie2 --version 2>&1 | grep -F "version 2.5.5" >/dev/null
  bowtie2-build --version 2>&1 | grep -F "version 2.5.5" >/dev/null
  hisat2 --version 2>&1 | grep -F "version 2.2.2" >/dev/null
  hisat2-build --version 2>&1 | grep -F "version 2.2.2" >/dev/null
  minimap2 --version 2>&1 | grep -Fx "2.31-r1302" >/dev/null
  rammap --version 2>&1 | grep -Fx "rammap 1.1.1" >/dev/null
  ps --version 2>&1 | grep -F "procps-ng" >/dev/null

  test -s /opt/bismark/share/licenses/bismark/LICENSE
  test -s /opt/bismark/share/licenses/bismark/THIRD-PARTY-NOTICES.md
  test -s /opt/bismark/share/provenance/source.txt
  test -s /opt/bismark/share/source/bismark-rust-v3.1.0.tar.gz
  grep -Fx "upstream_commit=e552b8f307a7041bcebed8f8e5a764ebcf7b046c" \
    /opt/bismark/share/provenance/source.txt >/dev/null
  test -s /opt/rammap/share/licenses/rammap/LICENSE
  test -s /opt/rammap/share/provenance/source.txt
  test -s /opt/rammap/share/source/rammap-v1.1.1.tar.gz
  grep -Fx "upstream_commit=5ea62cd5e2f7875fef5234d57ada12ac5a30dbba" \
    /opt/rammap/share/provenance/source.txt >/dev/null
}

postprocess() {
  prepare_backend bowtie2
  mkdir -p "$tmp/input" "$tmp/dedup" "$tmp/extract" "$tmp/filter" \
    "$tmp/consistency" "$tmp/nuc" "$tmp/cytosine" "$tmp/nome"
  bismark --bowtie2 \
    --genome "$tmp/genome" \
    --output_dir "$tmp/input" \
    --basename input \
    "$tmp/reads/reads.fq" >"$tmp/postprocess-align.stdout" 2>"$tmp/postprocess-align.stderr"
  test -s "$tmp/input/input.bam"

  deduplicate_bismark --single --output_dir "$tmp/dedup" "$tmp/input/input.bam" >/dev/null
  find "$tmp/dedup" -type f -name '*.deduplicated.bam' -size +0c -print -quit | grep -q .
  find "$tmp/dedup" -type f -name '*deduplication_report.txt' -size +0c -print -quit | grep -q .

  bismark_methylation_extractor \
    --single-end \
    --comprehensive \
    --bedGraph \
    --output_dir "$tmp/extract" \
    "$tmp/input/input.bam" >/dev/null
  find "$tmp/extract" -type f -name '*splitting_report.txt' -size +0c -print -quit | grep -q .
  find "$tmp/extract" -type f -name '*.bedGraph.gz' -size +0c -print -quit | grep -q .
  cov="$(find "$tmp/extract" -type f -name '*.bismark.cov.gz' -print -quit)"
  test -n "$cov"
  test -s "$cov"

  coverage2cytosine \
    --genome_folder "$tmp/genome" \
    --output smoke-cytosine \
    --dir "$tmp/cytosine" \
    "$cov" >/dev/null
  find "$tmp/cytosine" -type f -name '*CpG_report.txt' -size +0c -print -quit | grep -q .

  bam2nuc \
    --genome_folder "$tmp/genome" \
    --dir "$tmp/nuc" \
    "$tmp/input/input.bam" >/dev/null
  find "$tmp/nuc" -type f -name '*nucleotide_stats.txt' -size +0c -print -quit | grep -q .

  cp "$tmp/input/input.bam" "$tmp/filter/filter-input.bam"
  (
    cd "$tmp/filter"
    filter_non_conversion --single filter-input.bam >/dev/null
  )
  find "$tmp/filter" -type f -name '*.bam' ! -name 'filter-input.bam' -size +0c -print -quit | grep -q .

  cp "$tmp/input/input.bam" "$tmp/consistency/consistency-input.bam"
  (
    cd "$tmp/consistency"
    methylation_consistency --single_end --min-count 1 consistency-input.bam >/dev/null
  )
  find "$tmp/consistency" -type f -name '*.bam' ! -name 'consistency-input.bam' -size +0c -print -quit | grep -q .

  printf '>chr1\nACGTACGTACGT\n' > "$tmp/nome/chr1.fa"
  printf 'Bismark methylation extractor; version v0.25.1\nr1\t+\tchr1\t6\tz\t4\t8\t+\n' \
    > "$tmp/nome/input.txt"
  NOMe_filtering \
    --genome_folder "$tmp/nome" \
    --dir "$tmp/nome" \
    input.txt >/dev/null
  test -s "$tmp/nome/input.manOwar.txt.gz"
}

case "$mode" in
  identity)
    identity
    ;;
  backend-bowtie2)
    run_backend bowtie2
    ;;
  backend-hisat2)
    run_backend hisat2
    ;;
  backend-minimap2)
    run_backend minimap2
    ;;
  backend-rammap)
    run_backend rammap
    ;;
  backend-rammap-subprocess)
    run_backend rammap-subprocess
    ;;
  postprocess)
    postprocess
    ;;
  buildtime)
    identity
    prepare_backend bowtie2
    cleanup
    tmp="${TMPDIR:-/tmp}/taf-bismark-smoke-$$-hisat2"
    prepare_backend hisat2
    cleanup
    tmp="${TMPDIR:-/tmp}/taf-bismark-smoke-$$-minimap2"
    prepare_backend minimap2
    ;;
  all)
    identity
    cleanup
    tmp="${TMPDIR:-/tmp}/taf-bismark-smoke-$$-bowtie2"
    run_backend bowtie2
    cleanup
    tmp="${TMPDIR:-/tmp}/taf-bismark-smoke-$$-hisat2"
    run_backend hisat2
    cleanup
    tmp="${TMPDIR:-/tmp}/taf-bismark-smoke-$$-minimap2"
    run_backend minimap2
    cleanup
    tmp="${TMPDIR:-/tmp}/taf-bismark-smoke-$$-rammap"
    run_backend rammap
    cleanup
    tmp="${TMPDIR:-/tmp}/taf-bismark-smoke-$$-rammap-subprocess"
    run_backend rammap-subprocess
    cleanup
    tmp="${TMPDIR:-/tmp}/taf-bismark-smoke-$$-postprocess"
    postprocess
    ;;
  *)
    printf 'unknown smoke mode: %s\n' "$mode" >&2
    exit 2
    ;;
esac

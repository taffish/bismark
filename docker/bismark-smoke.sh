#!/bin/sh
set -eu

mode="${1:-all}"
case "$mode" in
  all)
    for stage in identity backend-bowtie2 backend-hisat2 backend-minimap2 backend-rammap backend-rammap-subprocess postprocess streaming bwamem3; do
      "$0" "$stage"
    done
    exit 0 ;;
  identity|backend-bowtie2|backend-hisat2|backend-minimap2|backend-rammap|backend-rammap-subprocess|postprocess|streaming|bwamem3) ;;
  *) printf 'unknown smoke mode: %s\n' "$mode" >&2; exit 2 ;;
esac
umask 077
tmp=$(mktemp -d "${TMPDIR:-/tmp}/taf-bismark.XXXXXXXX")
cleanup() {
  rc=$?
  trap - EXIT HUP INT TERM
  if [ "$rc" -ne 0 ]; then
    printf 'smoke-stage=%s exit=%s\n' "$mode" "$rc" >&2
    for diagnostic in "$tmp"/*.stderr; do
      [ -f "$diagnostic" ] || continue
      printf '%s: %s\n' "$mode" "${diagnostic##*/}" >&2
      tail -n 20 "$diagnostic" >&2 || :
    done
  fi
  cd / && rm -rf -- "$tmp" || exit 1
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
cd "$tmp"

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
  grep -F '(version: v3.4.0)' "$report" >/dev/null
  awk -F '\t' '$1=="Sequences analysed in total:" && $2==5 {seen=1} END {exit !seen}' "$report"

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
  bismark --version >"$tmp/probe.stdout" 2>"$tmp/probe.stderr"
  grep -Fx "Bismark Version: v3.4.0" "$tmp/probe.stdout" >/dev/null
  bismark.bin --version >"$tmp/probe.stdout" 2>"$tmp/probe.stderr"
  grep -F "bismark (Bismark Rust suite) v3.4.0" "$tmp/probe.stdout" >/dev/null
  bismark --help >"$tmp/probe.stdout" 2>"$tmp/probe.stderr"
  grep -F "The Bismark bisulfite-sequencing suite" "$tmp/probe.stdout" >/dev/null
  bismark align --help >"$tmp/probe.stdout" 2>"$tmp/probe.stderr"
  grep -F -- '--no_stream_converted' "$tmp/probe.stdout" >/dev/null
  bismark_methylation_extractor --help >"$tmp/probe.stdout" 2>"$tmp/probe.stderr"
  grep -F -- '--allow_discordant' "$tmp/probe.stdout" >/dev/null
  command -v mkfifo >/dev/null

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
    "$command" --version >"$tmp/probe.stdout" 2>"$tmp/probe.stderr"
    grep -F "(Bismark Rust suite) v3.4.0" "$tmp/probe.stdout" >/dev/null
  done

  bowtie2 --version >"$tmp/probe.stdout" 2>&1
  grep -F "version 2.5.5" "$tmp/probe.stdout" >/dev/null
  bowtie2-build --version >"$tmp/probe.stdout" 2>&1
  grep -F "version 2.5.5" "$tmp/probe.stdout" >/dev/null
  hisat2 --version >"$tmp/probe.stdout" 2>&1
  grep -F "version 2.2.2" "$tmp/probe.stdout" >/dev/null
  hisat2-build --version >"$tmp/probe.stdout" 2>&1
  grep -F "version 2.2.2" "$tmp/probe.stdout" >/dev/null
  minimap2 --version >"$tmp/probe.stdout" 2>&1
  grep -Fx "2.31-r1302" "$tmp/probe.stdout" >/dev/null
  rammap --version >"$tmp/probe.stdout" 2>&1
  grep -Fx "rammap 1.1.1" "$tmp/probe.stdout" >/dev/null
  bwa-mem3 version >"$tmp/bwamem3.stdout" 2>"$tmp/bwamem3.stderr"
  grep -F "0.18.0" "$tmp/bwamem3.stdout" >/dev/null
  test -s /opt/bwamem3/share/source/bwa-mem3-0.18.0.tar.gz
  ps --version >"$tmp/probe.stdout" 2>&1
  grep -F "procps-ng" "$tmp/probe.stdout" >/dev/null

  test -s /opt/bismark/share/licenses/bismark/LICENSE
  test -s /opt/bismark/share/licenses/bismark/THIRD-PARTY-NOTICES.md
  test -s /opt/bismark/share/provenance/source.txt
  test -s /opt/bismark/share/source/bismark-rust-v3.4.0.tar.gz
  grep -Fx "upstream_commit=3225cc7e04543d87e8efc05b5d0ab39823a438c6" \
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
  printf 'Bismark methylation extractor; version v3.4.0\nr1\t+\tchr1\t6\tz\t4\t8\t+\n' \
    > "$tmp/nome/input.txt"
  NOMe_filtering \
    --genome_folder "$tmp/nome" \
    --dir "$tmp/nome" \
    input.txt >/dev/null
  test -s "$tmp/nome/input.manOwar.txt.gz"
}

streaming() {
  prepare_backend bowtie2
  mkdir "$tmp/transient"
  for shape in default files; do
    set --
    if [ "$shape" = files ]; then set -- --no_stream_converted; fi
    if ! bismark --bowtie2 "$@" --temp_dir "$tmp/transient" --genome "$tmp/genome" \
        --output_dir "$tmp/$shape" --basename compare "$tmp/reads/reads.fq" >"$tmp/$shape.stdout" 2>"$tmp/$shape.stderr"; then
      cat "$tmp/$shape.stderr" >&2; return 1
    fi
    test -z "$(find "$tmp/transient" -mindepth 1 -print -quit)"
  done
  python3 - "$tmp" <<'PY'
import gzip, struct, sys
from pathlib import Path
root = Path(sys.argv[1])
def records(path):
    with gzip.open(path, 'rb') as f:
        def size(): return struct.unpack('<i', f.read(4))[0]
        assert f.read(4) == b'BAM\x01'
        header = f.read(size()); assert b'3.4.0' in header
        for _ in range(size()): f.read(size()); f.read(4)
        rows = []
        while raw := f.read(4):
            length = struct.unpack('<i', raw)[0]
            row = f.read(length)
            assert len(row) == length and length >= 32
            rows.append(row)
    return rows
a = records(root/'default/compare.bam')
assert len(a) == 5 and a == records(root/'files/compare.bam'), 'stream/files BAM record mismatch'
PY
  sed 's/$/\r/' "$tmp/reads/reads.fq" > "$tmp/crlf.fq"
  if bismark --bowtie2 --temp_dir "$tmp/transient" --genome "$tmp/genome" \
      --output_dir "$tmp/rejected" "$tmp/crlf.fq" >"$tmp/bad.stdout" 2>"$tmp/bad.stderr"; then return 1; fi
  grep -i -e 'CRLF' -e 'Windows.*line' "$tmp/bad.stderr" >/dev/null
  test -z "$(find "$tmp" -type p -print -quit)"
}

bwamem3() {
  make_inputs
  python3 - "$tmp" <<'PY'
import random, sys
from pathlib import Path
root = Path(sys.argv[1])
seq = ''.join((root/'genome/genome.fa').read_text().splitlines()[1:])
comp = str.maketrans('ACGT', 'TGCA')
for mate in (1, 2):
    with (root/f'R{mate}.fq').open('w') as out:
        # Enough unique pairs for bwa-mem3's insert-size estimator.
        for i, pos in enumerate(range(137, 4738, 200), 1):
            fragment = seq[pos:pos+400]
            read = fragment[:150] if mate == 1 else fragment[-150:].translate(comp)[::-1]
            out.write(f'@pair{i}/{mate}\n{read}\n+\n{"I"*len(read)}\n')
PY
  bismark_genome_preparation --bwamem3 --parallel 2 "$tmp/genome" >prepare.stdout 2>prepare.stderr
  test -d "$tmp/genome/Bwamem3_Index"
  for chemistry in taps five; do
    set -- --taps
    if [ "$chemistry" = five ]; then set -- --illumina_5base --bwamem3; fi
    bismark "$@" --genome "$tmp/genome" -p 2 --basename sample --output_dir "$tmp/$chemistry" \
      -1 "$tmp/R1.fq" -2 "$tmp/R2.fq" >"$chemistry.stdout" 2>"$chemistry.stderr"
    test -s "$tmp/$chemistry/sample_pe.bam"
    grep -F 'bwa-mem3' "$tmp/$chemistry/sample_PE_report.txt" >/dev/null
    awk -F '\t' '$1=="Sequence pairs analysed in total:" && $2==24 {total=1} $1=="Number of paired-end alignments with a unique best hit:" && $2==24 {mapped=1} END {exit !(total && mapped)}' "$tmp/$chemistry/sample_PE_report.txt"
  done
  grep -F 'Library chemistry: TAPS' "$tmp/taps/sample_PE_report.txt" >/dev/null
}

case "$mode" in
  bwamem3) bwamem3 ;;
  identity) identity ;;
  backend-*) run_backend "${mode#backend-}" ;;
  postprocess) postprocess ;;
  streaming) streaming ;;
esac

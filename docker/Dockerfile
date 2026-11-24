# Debian image manifests are pinned. Debian APT is a live mirror: packages may move.
# Keep successfully verified .debs within each RUN across temporary HTTP failures. The
# base image clears its default archive cache on each update. No cache is shipped.
# If the repository changes, review repository metadata, pin a successor and retest both architectures.
FROM debian:12-slim@sha256:734a72b3d6142a71993b4bc580ca01d8ca687f77a2c422d96a961d3376b179bc AS aligner-builder

ARG TARGETARCH
ARG BUILD_JOBS=4
ARG BOWTIE2_VERSION=2.5.5
ARG BOWTIE2_COMMIT=0c6a1c75e047ad8bf70c178fa3cb1528fba6adc2
ARG BOWTIE2_SOURCE_SHA256=61b9b46ccd3e1123a2e1c59f7f418e86948bff089eafb6f65038dbb4b2a2d2e5
ARG HISAT2_VERSION=2.2.2
ARG HISAT2_COMMIT=99583d7536b9ee017ac07de8834017a3bf99a2fe
ARG HISAT2_SOURCE_SHA256=8b2d4f6683eeea2b856756c2287a9b4c56ce74d4620fc756e0dbb26b0c1b1039
ARG MINIMAP2_VERSION=2.31
ARG MINIMAP2_COMMIT=3c28777e7e2dcc90f825de1b9f17a89cca7d4452
ARG MINIMAP2_SOURCE_SHA256=4ccc555359db80f0e1e285efae0be74c79230a2facc9cb480b74277627dd0c20
ARG SIMDE_COMMIT=1c68d9ad60bf63f3fb527c4ee3b2319d828ffcc6
ARG SIMDE_SOURCE_SHA256=f6032af6f67496ea0087e54577a2fdac7d1e806fe8ccd19898e21fd5fce3f2e6

ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; \
    mkdir -p /var/cache/bismark-debs/partial; \
    for attempt in 1 2 3 4 5; do \
      if apt-get -o Acquire::Retries=3 update \
       && apt-get -o Acquire::Retries=3 -o Dir::Cache::archives=/var/cache/bismark-debs install -y --no-install-recommends \
            binutils \
            build-essential \
            ca-certificates \
            curl \
            file \
            patch \
            zlib1g-dev; then \
        break; \
      fi; \
      if [ "$attempt" = 5 ]; then exit 1; fi; \
      rm -rf /var/lib/apt/lists/*; \
      sleep 5; \
    done; \
    apt-get clean; \
    rm -rf /var/cache/bismark-debs /var/lib/apt/lists/*

# Source and release URLs below are external. Verify an upstream replacement against its
# published identity before changing any digest; keep the existing source archives and notices.
WORKDIR /tmp/bismark-aligners

COPY docker/hisat2-simde-portability.patch ./

RUN set -eux; \
    curl --retry 5 --retry-delay 2 --retry-all-errors \
      --connect-timeout 20 --max-time 1800 -fsSL \
      "https://codeload.github.com/BenLangmead/bowtie2/tar.gz/${BOWTIE2_COMMIT}" \
      -o bowtie2.tar.gz; \
    curl --retry 5 --retry-delay 2 --retry-all-errors \
      --connect-timeout 20 --max-time 1800 -fsSL \
      "https://codeload.github.com/DaehwanKimLab/hisat2/tar.gz/${HISAT2_COMMIT}" \
      -o hisat2.tar.gz; \
    curl --retry 5 --retry-delay 2 --retry-all-errors \
      --connect-timeout 20 --max-time 1800 -fsSL \
      "https://codeload.github.com/lh3/minimap2/tar.gz/${MINIMAP2_COMMIT}" \
      -o minimap2.tar.gz; \
    curl --retry 5 --retry-delay 2 --retry-all-errors \
      --connect-timeout 20 --max-time 1800 -fsSL \
      "https://codeload.github.com/simd-everywhere/simde-no-tests/tar.gz/${SIMDE_COMMIT}" \
      -o simde.tar.gz; \
    echo "${BOWTIE2_SOURCE_SHA256}  bowtie2.tar.gz" | sha256sum -c -; \
    echo "${HISAT2_SOURCE_SHA256}  hisat2.tar.gz" | sha256sum -c -; \
    echo "${MINIMAP2_SOURCE_SHA256}  minimap2.tar.gz" | sha256sum -c -; \
    echo "${SIMDE_SOURCE_SHA256}  simde.tar.gz" | sha256sum -c -; \
    mkdir -p \
      source/bowtie2/third_party/simde \
      source/hisat2/simde \
      source/minimap2; \
    tar --no-same-owner -xzf bowtie2.tar.gz -C source/bowtie2 --strip-components=1; \
    tar --no-same-owner -xzf hisat2.tar.gz -C source/hisat2 --strip-components=1; \
    tar --no-same-owner -xzf minimap2.tar.gz -C source/minimap2 --strip-components=1; \
    tar --no-same-owner -xzf simde.tar.gz \
      -C source/bowtie2/third_party/simde --strip-components=1; \
    tar --no-same-owner -xzf simde.tar.gz -C source/hisat2/simde --strip-components=1; \
    patch -d source/hisat2 -p1 < hisat2-simde-portability.patch; \
    make -C source/bowtie2 -j "${BUILD_JOBS}"; \
    make -C source/bowtie2 install PREFIX=/opt/aligners; \
    make -C source/hisat2 -j "${BUILD_JOBS}"; \
    install -d /opt/aligners/bin; \
    install -m 0755 \
      source/hisat2/hisat2 \
      source/hisat2/hisat2-align-l \
      source/hisat2/hisat2-align-s \
      source/hisat2/hisat2-build \
      source/hisat2/hisat2-build-l \
      source/hisat2/hisat2-build-s \
      source/hisat2/hisat2-inspect \
      source/hisat2/hisat2-inspect-l \
      source/hisat2/hisat2-inspect-s \
      /opt/aligners/bin/; \
    install -m 0755 source/hisat2/*.py /opt/aligners/bin/; \
    if [ "${TARGETARCH}" = arm64 ]; then \
      make -C source/minimap2 -j "${BUILD_JOBS}" aarch64=1; \
    else \
      make -C source/minimap2 -j "${BUILD_JOBS}"; \
    fi; \
    install -m 0755 source/minimap2/minimap2 /opt/aligners/bin/minimap2; \
    install -d \
      /opt/aligners/share/licenses/bowtie2 \
      /opt/aligners/share/licenses/hisat2 \
      /opt/aligners/share/licenses/minimap2 \
      /opt/aligners/share/provenance \
      /opt/aligners/share/source; \
    cp source/bowtie2/LICENSE /opt/aligners/share/licenses/bowtie2/LICENSE; \
    cp source/hisat2/LICENSE /opt/aligners/share/licenses/hisat2/LICENSE; \
    cp source/minimap2/LICENSE.txt /opt/aligners/share/licenses/minimap2/LICENSE.txt; \
    cp bowtie2.tar.gz \
      "/opt/aligners/share/source/bowtie2-${BOWTIE2_VERSION}.tar.gz"; \
    cp hisat2.tar.gz \
      "/opt/aligners/share/source/hisat2-${HISAT2_VERSION}.tar.gz"; \
    cp minimap2.tar.gz \
      "/opt/aligners/share/source/minimap2-${MINIMAP2_VERSION}.tar.gz"; \
    cp simde.tar.gz \
      "/opt/aligners/share/source/simde-no-tests-${SIMDE_COMMIT}.tar.gz"; \
    cp hisat2-simde-portability.patch \
      /opt/aligners/share/provenance/hisat2-simde-portability.patch; \
    { \
      printf 'bowtie2_version=%s\n' "${BOWTIE2_VERSION}"; \
      printf 'bowtie2_commit=%s\n' "${BOWTIE2_COMMIT}"; \
      printf 'bowtie2_source_sha256=%s\n' "${BOWTIE2_SOURCE_SHA256}"; \
      printf 'hisat2_version=%s\n' "${HISAT2_VERSION}"; \
      printf 'hisat2_commit=%s\n' "${HISAT2_COMMIT}"; \
      printf 'hisat2_source_sha256=%s\n' "${HISAT2_SOURCE_SHA256}"; \
      printf 'hisat2_arm_port=Bioconda SIMDe portability patch\n'; \
      printf 'simde_commit=%s\n' "${SIMDE_COMMIT}"; \
      printf 'simde_source_sha256=%s\n' "${SIMDE_SOURCE_SHA256}"; \
      printf 'minimap2_version=%s\n' "${MINIMAP2_VERSION}"; \
      printf 'minimap2_commit=%s\n' "${MINIMAP2_COMMIT}"; \
      printf 'minimap2_source_sha256=%s\n' "${MINIMAP2_SOURCE_SHA256}"; \
      printf 'target_arch=%s\n' "${TARGETARCH}"; \
    } > /opt/aligners/share/provenance/source.txt; \
    while IFS= read -r executable; do \
      if file "$executable" | grep -F "ELF" >/dev/null; then \
        strip --strip-unneeded "$executable"; \
      fi; \
    done < <(find /opt/aligners/bin -type f -perm /111 -print)

FROM debian:12-slim@sha256:734a72b3d6142a71993b4bc580ca01d8ca687f77a2c422d96a961d3376b179bc AS bismark-fetch

ARG TARGETARCH
ARG BISMARK_VERSION=3.4.0
ARG BISMARK_TAG=bismark-rust-v3.4.0
ARG BISMARK_COMMIT=3225cc7e04543d87e8efc05b5d0ab39823a438c6
ARG BISMARK_AMD64_SHA256=4293be5788538d99bbb6095a5e33f9d3181ba153b6e0550f45ad22d89a728002
ARG BISMARK_ARM64_SHA256=0dae5d226ea1efcf86a42e38aaa04f3e42373ec6da759d4405a79e38e1135e0f
ARG BISMARK_SOURCE_SHA256=034b9984f691eb0cb2bf85aeac9936fbb8440c136f143945f91543864f533f9e

ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; \
    mkdir -p /var/cache/bismark-debs/partial; \
    for attempt in 1 2 3 4 5; do \
      if apt-get -o Acquire::Retries=3 update \
       && apt-get -o Acquire::Retries=3 -o Dir::Cache::archives=/var/cache/bismark-debs install -y --no-install-recommends \
            binutils \
            ca-certificates \
            curl; then \
        break; \
      fi; \
      if [ "$attempt" = 5 ]; then exit 1; fi; \
      rm -rf /var/lib/apt/lists/*; \
      sleep 5; \
    done; \
    apt-get clean; \
    rm -rf /var/cache/bismark-debs /var/lib/apt/lists/*

WORKDIR /tmp/bismark

COPY docker/bismark-canonical-wrapper.sh ./

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) asset_arch=x86_64; asset_sha="${BISMARK_AMD64_SHA256}" ;; \
      arm64) asset_arch=aarch64; asset_sha="${BISMARK_ARM64_SHA256}" ;; \
      *) printf 'unsupported TARGETARCH: %s\n' "${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    asset="bismark-rust-${BISMARK_VERSION}-linux-${asset_arch}.tar.gz"; \
    curl --retry 5 --retry-delay 2 --retry-all-errors \
      --connect-timeout 20 --max-time 1800 -fsSL \
      "https://github.com/FelixKrueger/Bismark/releases/download/${BISMARK_TAG}/${asset}" \
      -o bismark-binary.tar.gz; \
    curl --retry 5 --retry-delay 2 --retry-all-errors \
      --connect-timeout 20 --max-time 1800 -fsSL \
      "https://codeload.github.com/FelixKrueger/Bismark/tar.gz/${BISMARK_COMMIT}" \
      -o bismark-source.tar.gz; \
    echo "${asset_sha}  bismark-binary.tar.gz" | sha256sum -c -; \
    echo "${BISMARK_SOURCE_SHA256}  bismark-source.tar.gz" | sha256sum -c -; \
    mkdir -p binary source \
      /opt/bismark/bin \
      /opt/bismark/share/doc/bismark \
      /opt/bismark/share/licenses/bismark \
      /opt/bismark/share/provenance \
      /opt/bismark/share/source \
      /opt/bismark/share/testdata; \
    tar --no-same-owner -xzf bismark-binary.tar.gz -C binary --strip-components=1; \
    tar --no-same-owner -xzf bismark-source.tar.gz -C source --strip-components=1; \
    install -m 0755 binary/bismark /opt/bismark/bin/bismark.bin; \
    strip --strip-unneeded /opt/bismark/bin/bismark.bin; \
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
      bismark2summary; do \
      ln -s bismark.bin "/opt/bismark/bin/${command}"; \
    done; \
    test "$(tr -d '[:space:]' < source/rust/VERSION)" = "$BISMARK_VERSION"; \
    sed "s/__SUITE_VERSION__/${BISMARK_VERSION}/g" \
      bismark-canonical-wrapper.sh > /opt/bismark/bin/bismark; \
    chmod 0755 /opt/bismark/bin/bismark; \
    cp source/README.md \
      /opt/bismark/share/doc/bismark/README-upstream.md; \
    cp source/rust/README.md \
      /opt/bismark/share/doc/bismark/README-rust-suite.md; \
    cp source/license.txt /opt/bismark/share/licenses/bismark/LICENSE; \
    cp source/rust/THIRD-PARTY-NOTICES.md \
      /opt/bismark/share/licenses/bismark/THIRD-PARTY-NOTICES.md; \
    cp bismark-source.tar.gz \
      "/opt/bismark/share/source/bismark-rust-v${BISMARK_VERSION}.tar.gz"; \
    cp bismark-canonical-wrapper.sh \
      /opt/bismark/share/provenance/bismark-canonical-wrapper.sh; \
    { \
      printf 'upstream_name=Bismark Rust Suite\n'; \
      printf 'upstream_version=%s\n' "${BISMARK_VERSION}"; \
      printf 'upstream_tag=%s\n' "${BISMARK_TAG}"; \
      printf 'upstream_commit=%s\n' "${BISMARK_COMMIT}"; \
      printf 'binary_asset=%s\n' "${asset}"; \
      printf 'binary_sha256=%s\n' "${asset_sha}"; \
      printf 'source_sha256=%s\n' "${BISMARK_SOURCE_SHA256}"; \
      printf 'release_features=rammap-inprocess,binseq-input\n'; \
      printf 'target_arch=%s\n' "${TARGETARCH}"; \
    } > /opt/bismark/share/provenance/source.txt

FROM debian:12-slim@sha256:734a72b3d6142a71993b4bc580ca01d8ca687f77a2c422d96a961d3376b179bc AS rammap-fetch

ARG TARGETARCH
ARG RAMMAP_VERSION=1.1.1
ARG RAMMAP_TAG=v1.1.1
ARG RAMMAP_COMMIT=5ea62cd5e2f7875fef5234d57ada12ac5a30dbba
ARG RAMMAP_AMD64_SHA256=d172402fa4d04ce3460d4bdfaa3fcd0b5d9673dfeb0207f34e4a22d7ef1f3511
ARG RAMMAP_ARM64_SHA256=b44f64ef8abe0181eede1e5b342ded2d24e88a5c71fcd5aa32e34eef3d47b302
ARG RAMMAP_SOURCE_SHA256=162191940a88a921a1ea0b7787e6afd94347dce1628026fd013e8b2846f04481

ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; \
    mkdir -p /var/cache/bismark-debs/partial; \
    for attempt in 1 2 3 4 5; do \
      if apt-get -o Acquire::Retries=3 update \
       && apt-get -o Acquire::Retries=3 -o Dir::Cache::archives=/var/cache/bismark-debs install -y --no-install-recommends \
            binutils \
            ca-certificates \
            curl; then \
        break; \
      fi; \
      if [ "$attempt" = 5 ]; then exit 1; fi; \
      rm -rf /var/lib/apt/lists/*; \
      sleep 5; \
    done; \
    apt-get clean; \
    rm -rf /var/cache/bismark-debs /var/lib/apt/lists/*

WORKDIR /tmp/rammap

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) asset_arch=x86_64; asset_sha="${RAMMAP_AMD64_SHA256}" ;; \
      arm64) asset_arch=aarch64; asset_sha="${RAMMAP_ARM64_SHA256}" ;; \
      *) printf 'unsupported TARGETARCH: %s\n' "${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    asset="rammap_${asset_arch}-unknown-linux-gnu_v${RAMMAP_VERSION}"; \
    curl --retry 5 --retry-delay 2 --retry-all-errors \
      --connect-timeout 20 --max-time 1800 -fsSL \
      "https://github.com/jwanglab/rammap/releases/download/${RAMMAP_TAG}/${asset}" \
      -o rammap; \
    curl --retry 5 --retry-delay 2 --retry-all-errors \
      --connect-timeout 20 --max-time 1800 -fsSL \
      "https://codeload.github.com/jwanglab/rammap/tar.gz/${RAMMAP_COMMIT}" \
      -o rammap-source.tar.gz; \
    echo "${asset_sha}  rammap" | sha256sum -c -; \
    echo "${RAMMAP_SOURCE_SHA256}  rammap-source.tar.gz" | sha256sum -c -; \
    mkdir -p source \
      /opt/rammap/bin \
      /opt/rammap/share/doc/rammap \
      /opt/rammap/share/licenses/rammap \
      /opt/rammap/share/provenance \
      /opt/rammap/share/source; \
    tar --no-same-owner -xzf rammap-source.tar.gz -C source --strip-components=1; \
    install -m 0755 rammap /opt/rammap/bin/rammap; \
    strip --strip-unneeded /opt/rammap/bin/rammap; \
    cp source/README.md /opt/rammap/share/doc/rammap/README-upstream.md; \
    cp source/LICENSE /opt/rammap/share/licenses/rammap/LICENSE; \
    cp rammap-source.tar.gz \
      "/opt/rammap/share/source/rammap-v${RAMMAP_VERSION}.tar.gz"; \
    { \
      printf 'upstream_name=rammap\n'; \
      printf 'upstream_version=%s\n' "${RAMMAP_VERSION}"; \
      printf 'upstream_tag=%s\n' "${RAMMAP_TAG}"; \
      printf 'upstream_commit=%s\n' "${RAMMAP_COMMIT}"; \
      printf 'binary_asset=%s\n' "${asset}"; \
      printf 'binary_sha256=%s\n' "${asset_sha}"; \
      printf 'source_sha256=%s\n' "${RAMMAP_SOURCE_SHA256}"; \
      printf 'target_arch=%s\n' "${TARGETARCH}"; \
    } > /opt/rammap/share/provenance/source.txt

FROM debian:13-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2 AS bwamem3-builder

ARG TARGETARCH
ARG BUILD_JOBS=4
ARG BWAMEM3_VERSION=0.18.0
ARG BWAMEM3_COMMIT=e0903cb9395bc755059358f916b2efdb58a30073
ARG BWAMEM3_SOURCE_SHA256=6145d3c26f0fde77ff4938c60a4fb7ec7688e4f5236ab7d385c792088aca79d7
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# APT remains a live repository. The official release archive includes its pinned
# submodules; a missing or changed archive must fail its digest check, not float.
RUN set -eux; \
    apt-get -o Acquire::Retries=5 update; \
    apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
      autoconf automake binutils build-essential ca-certificates clang-19 cmake \
      curl libdeflate-dev libomp-19-dev lld-19 zlib1g-dev; \
    apt-get clean; rm -rf /var/lib/apt/lists/*
WORKDIR /tmp/bwamem3-build
RUN set -eux; \
    curl --retry 5 --retry-all-errors --connect-timeout 20 --max-time 1800 -fsSL \
      "https://github.com/fg-labs/bwa-mem3/releases/download/v${BWAMEM3_VERSION}/Source_code_including_submodules.tar.gz" -o source.tar.gz; \
    echo "${BWAMEM3_SOURCE_SHA256}  source.tar.gz" | sha256sum -c -; \
    mkdir source; tar --no-same-owner -xzf source.tar.gz -C source --strip-components=1; \
    make -C source -j "${BUILD_JOBS}" CXX=clang++-19 CC=clang-19; \
    install -d /opt/bwamem3/bin /opt/bwamem3/share/source /opt/bwamem3/share/licenses /opt/bwamem3/share/provenance; \
    install -m 0755 source/bwa-mem3 /opt/bwamem3/bin/bwa-mem3; \
    strip --strip-unneeded /opt/bwamem3/bin/bwa-mem3; \
    cp source.tar.gz "/opt/bwamem3/share/source/bwa-mem3-${BWAMEM3_VERSION}.tar.gz"; \
    cp source/LICENSE /opt/bwamem3/share/licenses/LICENSE; \
    find source/ext -type f \( -iname '*license*' -o -iname '*copying*' \) -exec cp --parents '{}' /opt/bwamem3/share/licenses/ \;; \
    printf 'version=%s\ncommit=%s\nsource_sha256=%s\narchitecture=%s\nbuild=upstream default; clang-19; no algorithm patches\n' \
      "$BWAMEM3_VERSION" "$BWAMEM3_COMMIT" "$BWAMEM3_SOURCE_SHA256" "$TARGETARCH" \
      > /opt/bwamem3/share/provenance/source.txt

FROM debian:13-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2

ARG BISMARK_VERSION=3.4.0

ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; \
    mkdir -p /var/cache/bismark-debs/partial; \
    for attempt in 1 2 3 4 5; do \
      if apt-get -o Acquire::Retries=3 update \
       && apt-get -o Acquire::Retries=3 -o Dir::Cache::archives=/var/cache/bismark-debs install -y --no-install-recommends \
            bzip2 \
            ca-certificates \
            coreutils \
            file \
            findutils \
            grep \
            gzip \
            libgcc-s1 \
            libdeflate0 \
            libomp5-19 \
            libstdc++6 \
            perl \
            procps \
            python-is-python3 \
            python3-minimal \
            zlib1g; then \
        break; \
      fi; \
      if [ "$attempt" = 5 ]; then exit 1; fi; \
      rm -rf /var/lib/apt/lists/*; \
      sleep 5; \
    done; \
    apt-get clean; \
    rm -rf /var/cache/bismark-debs /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=aligner-builder /opt/aligners /opt/aligners
COPY --from=bismark-fetch /opt/bismark /opt/bismark
COPY --from=rammap-fetch /opt/rammap /opt/rammap
COPY --from=bwamem3-builder /opt/bwamem3 /opt/bwamem3
COPY docker/bismark-smoke.sh /opt/bismark/share/testdata/bismark-smoke.sh

ENV PATH=/opt/bismark/bin:/opt/aligners/bin:/opt/rammap/bin:/opt/bwamem3/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN set -eux; \
    chmod 0755 /opt/bismark/share/testdata/bismark-smoke.sh; \
    banner=$(bismark.bin --version); \
    detected=$(printf '%s\n' "$banner" | awk '{for(i=1;i<=NF;i++) if ($i ~ /^v[0-9]+\.[0-9]+\.[0-9]+$/) print substr($i,2)}'); \
    test "$detected" = "$BISMARK_VERSION"; \
    bwa-mem3 version > /tmp/bwamem3-version.txt; \
    grep -F '0.18.0' /tmp/bwamem3-version.txt; \
    command -v mkfifo >/dev/null; \
    : > /tmp/bismark-ldd.txt; \
    while IFS= read -r -d '' executable; do \
      if file "$executable" | grep -F "ELF" >/dev/null; then \
        case "$(file -b "$executable")" in \
          *statically\ linked*|*static-pie\ linked*) continue ;; \
        esac; \
        ldd "$executable" >> /tmp/bismark-ldd.txt 2>&1; \
      fi; \
    done < <(find /opt/bismark/bin /opt/aligners/bin /opt/rammap/bin /opt/bwamem3/bin -type f -perm /111 -print0); \
    if grep -F "not found" /tmp/bismark-ldd.txt; then exit 1; fi; \
    grep -Fx "upstream_version=${BISMARK_VERSION}" \
      /opt/bismark/share/provenance/source.txt >/dev/null; \
    grep -Fx "upstream_version=1.1.1" \
      /opt/rammap/share/provenance/source.txt >/dev/null; \
    rm -f /tmp/bismark-ldd.txt /tmp/bwamem3-version.txt

WORKDIR /work

ENV TAFFISH_ENV=TAFFISH
ENV TAFFISH_NAME=bismark

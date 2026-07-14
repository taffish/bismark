#!/bin/sh
set -eu

case "${1-}" in
  --version|-v)
    printf 'Bismark Version: v__SUITE_VERSION__\n'
    printf 'Copyright 2010-25 Felix Krueger, Altos Bioinformatics\n'
    printf 'https://github.com/FelixKrueger/Bismark\n'
    exit 0
    ;;
esac

exec /opt/bismark/bin/bismark.bin "$@"

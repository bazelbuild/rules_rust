#!/usr/bin/env bash

set -euo pipefail

if [[ -n "${VERBOSE_COVERAGE:-}" ]]; then
  set -x
fi

if [[ "${RUNFILES_DIR:0:1}" != "/" ]]; then
  if [[ -n "${ROOT}" ]]; then
    RUNFILES_DIR="${ROOT}/${RUNFILES_DIR}"
  fi
fi

readonly profdata_file=$COVERAGE_DIR/coverage.profdata

"$RUNFILES_DIR/$RUST_LLVM_PROFDATA" \
  merge \
  --sparse "$COVERAGE_DIR"/*.profraw \
  -output "$profdata_file"

"$RUNFILES_DIR/$RUST_LLVM_COV" \
  export \
  -format=lcov \
  -instr-profile "$profdata_file" \
  -ignore-filename-regex='.*external/.+' \
  -ignore-filename-regex='/tmp/.+' \
  -path-equivalence=.,"$ROOT" \
  "$RUNFILES_DIR/$TEST_WORKSPACE/$TEST_BINARY" \
  @"$COVERAGE_MANIFEST" \
  | sed 's#/proc/self/cwd/##' > "$COVERAGE_DIR/rust_coverage.dat"

# Bazel doesn't support LLVM profdata coverage amongst other coverage formats.
rm "$profdata_file"

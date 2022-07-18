#!/usr/bin/env bash

set -euo pipefail

if [[ -n "${VERBOSE_COVERAGE:-}" ]]; then
  set -x
fi

readonly profdata_file=$COVERAGE_DIR/coverage.profdata

"$RUNFILES_DIR/$TEST_WORKSPACE/$RUST_LLVM_PROFDATA" \
  merge \
  --sparse "$COVERAGE_DIR"/*.profraw \
  -output "$profdata_file"

"$RUNFILES_DIR/$TEST_WORKSPACE/$RUST_LLVM_COV" \
  export \
  -format=lcov \
  -instr-profile "$profdata_file" \
  -ignore-filename-regex='.*external/.+' \
  -ignore-filename-regex='/tmp/.+' \
  -path-equivalence=.,"$ROOT" \
  "$RUNFILES_DIR/$TEST_WORKSPACE/$TEST_BINARY" \
  @"$COVERAGE_MANIFEST" \
  | sed 's#/proc/self/cwd/##' > "$COVERAGE_OUTPUT_FILE"

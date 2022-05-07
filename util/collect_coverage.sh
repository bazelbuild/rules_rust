#!/bin/bash

set -euo pipefail
set -x

echo here!

# export LLVM_PROFILE_FILE="${COVERAGE_DIR}/%h-%p-%m.profraw"
output_file=$COVERAGE_DIR/_cc_coverage.dat

/Users/ksmiley/dev/rules_rust/examples/bazel-examples/external/rust_darwin_aarch64/lib/rustlib/aarch64-apple-darwin/bin/llvm-profdata \
  merge --sparse \
  "${COVERAGE_DIR}"/*.profraw \
  -output "${output_file}.data"

# object_param=""
# while read -r line; do
#   if [[ ${line: -24} == "runtime_objects_list.txt" ]]; then
#     while read -r line_runtime_object; do
#       if [[ -e "${RUNFILES_DIR}/${TEST_WORKSPACE}/${line_runtime_object}" ]]; then
#         object_param+=" -object ${RUNFILES_DIR}/${TEST_WORKSPACE}/${line_runtime_object}"
#       fi
#     done < "${line}"
#   fi
# done < "${COVERAGE_MANIFEST}"


# /Users/ksmiley/dev/rules_rust/examples/bazel-examples/external/rust_darwin_aarch64/lib/rustlib/aarch64-apple-darwin/bin/llvm-cov export -instr-profile "${output_file}.data" -format=lcov \
#   -ignore-filename-regex='.*external/.+' \
#   -ignore-filename-regex='/tmp/.+' \
#   ${object_param} | sed 's#/proc/self/cwd/##' > "${output_file}"

# exit 1

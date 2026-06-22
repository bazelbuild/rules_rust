#!/bin/bash

set -euo pipefail

cd "${BUILD_WORKSPACE_DIRECTORY}"

bazel_command=("${BAZEL:-bazel}")
if [[ -n "${BAZEL_OUTPUT_BASE:-}" ]]; then
    bazel_command+=("--output_base=${BAZEL_OUTPUT_BASE}")
fi

if ! "${bazel_command[@]}" query //cargo/tests/unit/build_script_deps:transition_and_then_supported >/dev/null 2>&1; then
    exit 0
fi

"${bazel_command[@]}" aquery \
    --compilation_mode=fastbuild \
    --experimental_output_paths=strip \
    --include_commandline \
    --include_param_files \
    --output=jsonproto \
    'mnemonic("Rustc", deps(set(//cargo/tests/unit/build_script_deps:dep_of_a_build_script //cargo/tests/unit/build_script_deps:build_script_deps_in_exec_mode)))' \
    | python3 test/build_script_path_mapping_test.py

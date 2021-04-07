#!/bin/bash

set -euo pipefail

# Find the location of the script
if [[ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
    SCRIPT_DIR="${BUILD_WORKSPACE_DIRECTORY}"
else
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
fi

if [[ "${IS_WINDOWS:-}" == "true" ]]; then
    bin_name=crate_universe_resolver.exe
    install_name=resolver.exe
else
    bin_name=crate_universe_resolver
    install_name=resolver
fi

mkdir -p "${SCRIPT_DIR}/file"
touch "${SCRIPT_DIR}/file/BUILD.bazel"
cp "${SCRIPT_DIR}/bin/${TARGET}/release/${bin_name}" "${SCRIPT_DIR}/file/${install_name}"

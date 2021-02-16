#!/bin/bash

# Bazel will set BUILD_WORKSPACE_DIRECTORY for run targets
if [[ -z "${BUILD_WORKSPACE_DIRECTORY}" ]]; then
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    BUILD_WORKSPACE_DIRECTORY="${SCRIPT_DIR}/.."
fi

pushd ${BUILD_WORKSPACE_DIRECTORY}/impl
cargo build --quiet --release
popd

RAZE=${BUILD_WORKSPACE_DIRECTORY}/impl/target/release/cargo-raze

echo "Bootstrapping Cargo Raze"
exec ${RAZE} --manifest-path ${BUILD_WORKSPACE_DIRECTORY}/impl/Cargo.toml

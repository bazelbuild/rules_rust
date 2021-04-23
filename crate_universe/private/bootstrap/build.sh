#!/bin/bash

set -xeuo pipefail

# Find the location of the script
if [[ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
    SCRIPT_DIR="${BUILD_WORKSPACE_DIRECTORY}"
else
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
fi

# All supported targets
if [[ $# -gt 0 ]]; then
    TARGETS=("$@")
elif [[ -n "${TARGET:-}" ]]; then
    TARGETS=("${TARGET}")
else
    TARGETS=(
        "aarch64-apple-darwin"
        "aarch64-unknown-linux-gnu"
        "x86_64-apple-darwin"
        "x86_64-pc-windows-gnu"
        "x86_64-unknown-linux-gnu"
    )
fi

echo "TARGETS=${TARGETS[@]}"

# Specify the path to the cargo manifest
MANIFEST="${SCRIPT_DIR}/../../Cargo.toml"

# Resolve absolute paths that could potentially be in the cargo and rustc vars
CARGO="$(echo ${CARGO-cargo} | sed "s^\${PWD}^${PWD}^")"
RUSTC="$(echo ${RUSTC-rustc} | sed "s^\${PWD}^${PWD}^")"

# If there are multiple targets or we're in github CI, ensure `cross` is installed
if [[ "${#TARGETS[@]}" != 1 || -n "${GITHUB_WORKFLOW:-}" ]]; then

    # Ensure we have an aboslute path to the cargo binary
    ${CARGO} version

    # Ensure cross is installed which is used for bootstrapping on all platforms
    if [[ -z "$(cross --version || echo '')" ]]; then
        ${CARGO} install cross
    fi

    BUILD_TOOL=cross
else
    # Ensure rustc is set when using cargo
    BUILD_TOOL="env RUSTC=${RUSTC} ${CARGO}"
fi

# Fetch cargo dependencies in advance to streamline the build process
echo "Fetch cargo dependencies"
${CARGO} fetch --manifest-path="${MANIFEST}"

if [[ -z "${OUT_DIR:-}" ]]; then
    OUT_DIR="${SCRIPT_DIR}/bin"
fi

# Because --target-dir does not work, we change directories and move built binaries after the fact
# https://github.com/rust-embedded/cross/issues/272
pushd "$(dirname "${MANIFEST}")"

# Build all binaries
for target in ${TARGETS[@]}; do
    echo "Building for ${target}"

    if [[ "${target}" == *"windows"* ]]; then
        bin_name=crate_universe_resolver.exe
    else
        bin_name=crate_universe_resolver
    fi

    # This clean avoids linker issues
    # https://github.com/rust-embedded/cross/issues/455
    ${CARGO} clean

    # Build the binary for the current target
    ${BUILD_TOOL} build --release --locked --target="${target}"
    
    # Install it into the rules_rust repository
    install_path="${OUT_DIR}/${target}/release/${bin_name}"
    mkdir -p "$(dirname "${install_path}")"
    cp -p "./target/${target}/release/${bin_name}" "${install_path}"
done
popd

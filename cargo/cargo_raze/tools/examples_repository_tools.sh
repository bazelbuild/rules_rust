#!/bin/bash

if [[ -z "${BUILD_WORKSPACE_DIRECTORY}" ]]; then
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    BUILD_WORKSPACE_DIRECTORY="$( dirname "${SCRIPT_DIR}")"
fi

if [[ -z "${EXAMPLES_DIR}" ]]; then
    EXAMPLES_DIR=${BUILD_WORKSPACE_DIRECTORY}/examples
fi

# Ensure there's a cargo binary
if [[ -z "${CARGO}" ]]; then
    CARGO="$(which cargo)"
fi

_RENDERED_FILES=()

# Helper function
function _cache_bazel_files() {
    RENDERED_FILES=()
    for filename in $(find $1 -name "*.bazel"); do
        mkdir -p "$(dirname ${_TEMP_DIR}/${filename})"
        cp "${filename}" "${_TEMP_DIR}/${filename}"
        _RENDERED_FILES+=("${filename}")
    done
}

# Vendors crate sources for the vendored examples
function vendor() {
    # Committed `Cargo.toml` files need to be preserved so a temp directory is
    # created where they will be copied into and restored after `cargo vendor`
    # is ran.
    _TEMP_DIR=$(mktemp -d -t cargo_raze_examples_vendored-XXXXXXXXXX)

    for ex in $(find $EXAMPLES_DIR/vendored -maxdepth 1 -type d | tail -n+2); do
        pushd "$ex"
        echo "Running Cargo Vendor for $(basename "$ex")"

        # First log all bazel files in the vendor path
        _cache_bazel_files "$ex/cargo/vendor"
        
        # Vendor all crates
        ${CARGO} vendor -q --versioned-dirs "$ex/cargo/vendor"

        # Write the bazel files back in place
        for filename in "${_RENDERED_FILES[@]}"; do
            cat "${_TEMP_DIR}/${filename}" > "${filename}"
        done
        popd
    done

    rm -rf "${TEMP_DIR}"
}

# Update the examples by running cargo-raze on them
function raze() {
    if [[ -z "${RAZE}" ]]; then
        RAZE="$1"
    fi

    # Vendor sources
    vendor
    
    # Regenerate all outputs
    MANIFESTS=$(find $EXAMPLES_DIR -mindepth 2 -maxdepth 2 -type d)
    for manifest in ${MANIFESTS[@]}; do
        echo "Running raze on ${manifest}"
        ${RAZE} --manifest-path=${manifest}/Cargo.toml
    done
}

# Ensures cargo-raze examples are up to date.
function check() {
    RAZE="$1" 
    raze

    # Ensure there's no diff
    pushd ${BUILD_WORKSPACE_DIRECTORY}
    if [ -n "$(git status --porcelain examples)" ]; then 
        echo '/examples is out of date. Please rerun all tests and commit the changes generated from this command' >&2
        exit 1
    fi
    popd
}

set -e
$@

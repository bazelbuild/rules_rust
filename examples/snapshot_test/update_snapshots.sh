#!/usr/bin/env bash

set -o nounset -o pipefail

# Path to the rust test binary containing snapshot tests
RUST_TEST_BINARY="$1"
shift
# Relative path to the snapshots directory
SNAPSHOTS_RELATIVE_DIR="$1"
shift

# Create a sandbox directory to run the test binary. If run in the runfiles
# tree, insta will attempt to update symlinked files or write new files to
# the runfiles tree, which is not bazel idiomatic.
SANDBOX=$(mktemp --directory)
SANDBOX_SNAPSHOTS="${SANDBOX}/${SNAPSHOTS_RELATIVE_DIR}"

# Get the absolute path to the test binary since we will cd into the sandbox.
RUST_TEST_BINARY=$(realpath "${RUST_TEST_BINARY}")

# Run the test with an empty snapshot directory to regenerate all snapshots
# rather than doing partial updates or storing diffs in .snap.new files. This
# allows us to compare the full set of snapshots to those in the source tree
# and detect which snapshots are no longer referenced, mimicking
# `cargo insta test --unreferenced=delete`
# https://insta.rs/docs/advanced/#handling-unused-snapshots
mkdir -p "${SANDBOX_SNAPSHOTS}"
cd "${SANDBOX}"
INSTA_UPDATE="always" "${RUST_TEST_BINARY}"

SOURCE_SNAPSHOTS_DIR="${BUILD_WORKING_DIRECTORY}/${SNAPSHOTS_RELATIVE_DIR}"
mkdir -p "${SOURCE_SNAPSHOTS_DIR}"

# Write snapshots to the source tree
for s in "${SANDBOX_SNAPSHOTS}"/*.snap; do
    DEST="${SOURCE_SNAPSHOTS_DIR}/$(basename "${s/%".new"}")"
    echo "Writing snapshot ${DEST}"
    cp "$s" "${DEST}"
done

# Delete unreferenced snapshots from the source tree
for s in "${SOURCE_SNAPSHOTS_DIR}"/*.snap; do
    if [[ ! -f "${SANDBOX_SNAPSHOTS}/$(basename "$s")" ]]; then
        echo "Removing unused snapshot $s"
        rm "$s"
    fi
done

# Clean up
rm -rf "${SANDBOX}"

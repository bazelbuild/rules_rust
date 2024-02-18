#!/usr/bin/env bash

set -euo pipefail

# A script to re-vendor all vendors crates in this repository.
# This should be ran whenever any crate rendering changes.

vendor_workspace() {
    workspace="$1"
    echo "Vendoring all targets in workspace $workspace"
    pushd $workspace >/dev/null
    targets="$(bazel query 'kind("crates_vendor", //...)' 2>/dev/null)"
    for target in $targets
    do
        bazel run $target
    done
    popd >/dev/null
}

if [[ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
    cd "${BUILD_WORKSPACE_DIRECTORY:-}"
fi

workspaces="$(find . -type f -name WORKSPACE.bazel -o -name MODULE.bazel)"

for workspace in $workspaces
do
    vendor_workspace "$(dirname "$workspace")"
done

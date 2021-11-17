#!/bin/bash

# This script creates temporary workspaces and generates `rust-project.json`
# files unique to the set of targets defined in the generated workspace.

set -euo pipefail

if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
    echo "This script should be run under Bazel"
    exit 1
fi

PACKAGE_NAME="$1"
if [[ -z "${PACKAGE_NAME:-}" ]]; then
    echo "The first argument should be the package name of the test target"
    exit 1
fi

function generate_workspace() {
    local temp_dir="$(mktemp -d -t rules_rust_test_rust_analyzer-XXXXXXXXXX)"
    local new_workspace="${temp_dir}/rules_rust_test_rust_analyzer"

    mkdir -p "${new_workspace}"
    cat << EOF > "${new_workspace}/WORKSPACE.bazel"
workspace(name = "rules_rust_test_rust_analyzer")
local_repository(
    name = "rules_rust",
    path = "${BUILD_WORKSPACE_DIRECTORY}",
)
load("@rules_rust//rust:repositories.bzl", "rust_repositories")
rust_repositories(include_rustc_srcs = True)
load("@rules_rust//tools/rust_analyzer:deps.bzl", "rust_analyzer_deps")
rust_analyzer_deps()
EOF

cat << EOF > "${new_workspace}/.bazelrc"
build --keep_going
test --test_output=errors
build:strict --aspects=@rules_rust//rust:defs.bzl%rustfmt_aspect
build:strict --output_groups=+rustfmt_checks
build:strict --aspects=@rules_rust//rust:defs.bzl%rust_clippy_aspect
build:strict --output_groups=+clippy_checks
EOF

  echo "${new_workspace}"
}

function rust_analyzer_test() {
    local source_dir="$1"
    local workspace="$2"
    
    echo "Testing '$(basename "${source_dir}")'"
    rm -f "${workspace}"/*.rs "${workspace}"/*.json "${workspace}/BUILD.bazel"
    cp -r "${source_dir}"/* "${workspace}"
    
    # Drop the 'manual' tags
    if [ "$(uname)" == "Darwin" ]; then
        SEDOPTS=(-i '' -e)
    else
        SEDOPTS=(-i)
    fi
    sed ${SEDOPTS[@]} 's/"manual"//' "${workspace}/BUILD.bazel"
    
    pushd "${workspace}" &> /dev/null
    echo "Generating rust-project.json..."
    bazel run "@rules_rust//tools/rust_analyzer:gen_rust_project"
    echo "Building..."
    bazel build //...
    echo "Testing..."
    bazel test //...
    echo "Building with Aspects..."
    bazel build //... --config=strict
    popd &> /dev/null
}

function run_test_suite() {
    local temp_workspace="$(generate_workspace)"
    echo "Generated workspace: ${temp_workspace}"

    for test_dir in "${BUILD_WORKSPACE_DIRECTORY}/${PACKAGE_NAME}"/*; do
        # Skip everything but directories
        if [[ ! -d "${test_dir}" ]]; then
            continue
        fi

        rust_analyzer_test "${test_dir}" "${temp_workspace}"
    done

    rm -rf "${temp_workspace}"
}

run_test_suite

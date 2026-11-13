#!/usr/bin/env bash

# End-to-end test for the targets discovery selects. Checks that
# whole-workspace discovery keeps targets tagged `manual`, and that
# `setup --root-target-query` narrows it to the queried targets.

set -euo pipefail

if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
    >&2 echo "This script should be run under Bazel"
    exit 1
fi

workspace="$(mktemp -d -t rules_rust_ra_target_query-XXXXXXXXXX)"

cat >"${workspace}/MODULE.bazel" <<EOF
module(name = "rules_rust_ra_target_query", version = "0.0.0")
bazel_dep(name = "rules_rust", version = "0.0.0")
local_path_override(
    module_name = "rules_rust",
    path = "${BUILD_WORKSPACE_DIRECTORY}",
)
rust = use_extension("@rules_rust//rust:extensions.bzl", "rust")
use_repo(rust, "rust_toolchains")
register_toolchains("@rust_toolchains//:all")
EOF

if [[ -f "${BUILD_WORKSPACE_DIRECTORY}/.bazelversion" ]]; then
    cp "${BUILD_WORKSPACE_DIRECTORY}/.bazelversion" "${workspace}/.bazelversion"
fi

mkdir -p "${workspace}/app" "${workspace}/other"
echo "pub fn app() {}" >"${workspace}/app/lib.rs"
echo "pub fn manual() {}" >"${workspace}/app/manual.rs"
echo "pub fn other() {}" >"${workspace}/other/lib.rs"
touch "${workspace}/BUILD.bazel"

cat >"${workspace}/app/BUILD.bazel" <<EOF
load("@rules_rust//rust:defs.bzl", "rust_library")

rust_library(
    name = "app",
    srcs = ["lib.rs"],
    edition = "2021",
)

rust_library(
    name = "manual_lib",
    srcs = ["manual.rs"],
    edition = "2021",
    tags = ["manual"],
)
EOF

cat >"${workspace}/other/BUILD.bazel" <<EOF
load("@rules_rust//rust:defs.bzl", "rust_library")

rust_library(
    name = "other",
    srcs = ["lib.rs"],
    edition = "2021",
)
EOF

cd "${workspace}"

fail() {
    >&2 echo "FAIL: $1"
    >&2 echo "--- discovery.json ---"
    >&2 cat discovery.json
    exit 1
}

echo "Running whole-workspace discovery..."
bazel run @rules_rust//tools/rust_analyzer:setup -- --no-per-package-workspaces neovim >/dev/null
launcher_dir="${workspace}/.rules_rust_analyzer"
"${launcher_dir}/discover_bazel_rust_project.exe" --workspace="${workspace}" >discovery.json || true

grep -q '"kind":"error"' discovery.json && fail "discovery returned an error"
grep -q '"kind":"finished"' discovery.json || fail "discovery did not finish"
grep -q '"display_name":"app"' discovery.json || fail "'app' is missing"
grep -q '"display_name":"manual_lib"' discovery.json || fail "the manual-tagged 'manual_lib' is missing"
grep -q '"display_name":"other"' discovery.json || fail "'other' is missing"

echo "Running discovery with --root-target-query..."
bazel run @rules_rust//tools/rust_analyzer:setup -- --root-target-query='//app/...' neovim >/dev/null
grep -q '"root_target_query": *"//app/..."' "${launcher_dir}/user_config.json" ||
    fail "user_config.json did not record root_target_query"
"${launcher_dir}/discover_bazel_rust_project.exe" --workspace="${workspace}" >discovery.json || true

grep -q '"kind":"error"' discovery.json && fail "discovery returned an error"
grep -q '"kind":"finished"' discovery.json || fail "discovery did not finish"
grep -q '"display_name":"app"' discovery.json || fail "'app' is missing"
grep -q '"display_name":"manual_lib"' discovery.json || fail "the manual-tagged 'manual_lib' is missing"
grep -q '"display_name":"other"' discovery.json && fail "'other' is outside the root target query but present"

echo "PASS: discovery kept manual targets and honored --root-target-query"

bazel clean --expunge --async >/dev/null 2>&1 || true
cd /
rm -rf "${workspace}"

#!/usr/bin/env bash

# End-to-end test that discovery still produces a project when part of
# the workspace is broken. Stands up a workspace with one good
# `rust_library` and one target that fails analysis, runs
# `discover_bazel_rust_project`, and checks the good crate is still
# discovered. See `--keep_going` in tools/rust_analyzer/lib.rs.

set -euo pipefail

if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
    >&2 echo "This script should be run under Bazel"
    exit 1
fi

workspace="$(mktemp -d -t rules_rust_ra_partial-XXXXXXXXXX)"

cat >"${workspace}/MODULE.bazel" <<EOF
module(name = "rules_rust_ra_partial", version = "0.0.0")
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

echo "pub fn good() {}" >"${workspace}/lib.rs"

cat >"${workspace}/BUILD.bazel" <<EOF
load("@rules_rust//rust:defs.bzl", "rust_library")

rust_library(
    name = "good",
    srcs = ["lib.rs"],
    edition = "2021",
)

# Fails analysis: depends on a target that does not exist.
rust_library(
    name = "bad",
    srcs = ["lib.rs"],
    edition = "2021",
    deps = [":does_not_exist"],
)
EOF

cd "${workspace}"

fail() {
    >&2 echo "FAIL: $1"
    >&2 echo "--- discovery.json ---"
    >&2 cat discovery.json
    exit 1
}

# The workspace must actually fail to build, or the checks below are
# vacuous.
if bazel build //... >/dev/null 2>&1; then
    >&2 echo "FAIL: expected '//...' to fail to build"
    exit 1
fi

echo "Running discovery against the half-broken workspace..."
bazel run @rules_rust//tools/rust_analyzer:discover_bazel_rust_project >discovery.json || true

grep -q '"kind":"error"' discovery.json && fail "discovery returned an error instead of a partial project"
grep -q '"kind":"finished"' discovery.json || fail "discovery did not finish"
grep -q '"display_name":"good"' discovery.json || fail "the good crate is missing from the project"
grep -q '"display_name":"bad"' discovery.json && fail "the bad crate should have been skipped but is present"

echo "PASS: discovery produced a project with 'good' and without 'bad'"

bazel clean --expunge --async >/dev/null 2>&1 || true
cd /
rm -rf "${workspace}"

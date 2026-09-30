#!/usr/bin/env bash

# End-to-end test for the setup → discover → flycheck pipeline with
# clippy enabled. Stands up a workspace with a `rust_library` whose
# source triggers a clippy-only lint, runs `setup --clippy`, runs
# discovery, invokes flycheck the way rust-analyzer would on save,
# and checks that a clippy diagnostic ends up in flycheck's output.
#
# Regression coverage for two contract failures:
#   1. `assemble_rust_project` baking a flag into the runnable command
#      that flycheck's CLI doesn't accept — the bug pattern that shipped
#      the initial clippy support: `--clippy` was prepended to the
#      runnable but flycheck's Args struct never learned about it.
#   2. `bin/flycheck.rs` silently ignoring the per-user `clippy=true`
#      preference in `user_config.json` — the fallback path that keeps
#      the runnable command byte-identical across users.

set -euo pipefail

if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
    >&2 echo "This script should be run under Bazel"
    exit 1
fi

workspace="$(mktemp -d -t rules_rust_ra_flycheck_clippy-XXXXXXXXXX)"

cat >"${workspace}/MODULE.bazel" <<EOF
module(name = "rules_rust_ra_flycheck_clippy", version = "0.0.0")
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

# `assert!(true)` triggers `clippy::assertions_on_constants` (warn by
# default) without triggering any rustc warning — a clean signal that a
# clippy diagnostic reached flycheck's output.
cat >"${workspace}/lib.rs" <<'EOF'
pub fn check_it() {
    assert!(true);
}
EOF

cat >"${workspace}/BUILD.bazel" <<'EOF'
load("@rules_rust//rust:defs.bzl", "rust_library")

rust_library(
    name = "clippy_target",
    srcs = ["lib.rs"],
    edition = "2021",
)
EOF

cd "${workspace}"

fail() {
    >&2 echo "FAIL: $1"
    for f in discovery.json flycheck.out flycheck.err; do
        if [[ -f "${f}" ]]; then
            >&2 echo "--- ${f} ---"
            >&2 cat "${f}"
        fi
    done
    exit 1
}

echo "Installing setup binaries with --clippy..."
bazel run @rules_rust//tools/rust_analyzer:setup -- --clippy neovim >/dev/null

launcher_dir="${workspace}/.rules_rust_analyzer"
[[ -f "${launcher_dir}/flycheck.exe" ]] || fail "flycheck.exe not installed at ${launcher_dir}"
[[ -f "${launcher_dir}/user_config.json" ]] || fail "user_config.json not written by setup"
grep -q '"clippy": *true' "${launcher_dir}/user_config.json" || \
    fail "user_config.json did not record clippy=true"

# Discover self-locates via `dirname(current_exe())` when invoked from
# an install directory, but here we're running the bazel-bin copy —
# publish the launcher dir explicitly so `flycheck_launcher_path`
# resolves to the install we just wrote.
export RULES_RUST_RA_LAUNCHER_DIR="${launcher_dir}"

echo "Running discovery..."
bazel run @rules_rust//tools/rust_analyzer:discover_bazel_rust_project >discovery.json || true

# Regression #1: discovery must NOT bake `--clippy` (or any per-user
# preference) into the runnable command. The runnable is shared across
# developers and must stay byte-identical regardless of who ran discover.
if grep -q '"--clippy"' discovery.json; then
    fail "'--clippy' leaked into the discovery output — the runnable command should be user-agnostic"
fi

grep -q '"kind":"finished"' discovery.json || fail "discovery did not finish"

# Invoke flycheck as rust-analyzer would on save. The runnable's exact
# arg shape is verified by the `flycheck_runnable_uses_positional_args_only`
# unit test in `rust_project.rs`; this test just needs the two
# positional args in place so we can prove the user_config → aspect
# path fires. `BUILD_WORKSPACE_DIRECTORY` is overridden because the
# outer `bazel run` for this test leaks its own value (this repo's
# root).
echo "Invoking flycheck as rust-analyzer would..."
BUILD_WORKSPACE_DIRECTORY="${workspace}" \
    "${launcher_dir}/flycheck.exe" "//:clippy_target" "${workspace}/lib.rs" \
    >flycheck.out 2>flycheck.err || true

# Regression #2: with clippy enabled in user_config, flycheck must
# actually invoke the clippy aspect (proven by the lint firing). The
# diagnostic surfaces via stdout (JSON from `.clippy.diagnostics` when
# the action succeeds) or stderr (bazel's rendered output when
# `-D warnings` fails the build hard) — check both.
if ! grep -q "assertions_on_constants\|assertions-on-constants" flycheck.out flycheck.err; then
    fail "no clippy diagnostic in flycheck output — the user_config → aspect path is broken"
fi

echo "PASS: discovery emitted a user-agnostic runnable that flycheck accepts, and clippy diagnostics reached the output"

bazel clean --expunge --async >/dev/null 2>&1 || true
cd /
rm -rf "${workspace}"

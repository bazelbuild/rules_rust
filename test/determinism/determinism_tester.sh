#!/usr/bin/env bash

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
# shellcheck disable=SC1090
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
    source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
    source "$0.runfiles/$f" 2>/dev/null || \
    source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
    source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
    { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

set -euo pipefail

CHECKER_BIN="$(rlocation "${CHECKER_BIN}")"

if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
    cd "${BUILD_WORKSPACE_DIRECTORY}"
fi

# make a temp dir
TEMP_DIR="$(mktemp -d -t determinism-XXXX)"
REPO_A="${TEMP_DIR}/repo_a"
REPO_B="${TEMP_DIR}/repo_b"

# get the current commit
CURRENT_COMMIT="$(git rev-parse HEAD)"

function clone_at_revision() {
    local location="$1"
    local rev="$2"

    git clone --no-checkout https://github.com/bazelbuild/rules_rust.git "${location}"
    pushd "${location}"
    git checkout "${rev}" || git checkout main
    popd
}

clone_at_revision "${REPO_A}" "${CURRENT_COMMIT}"
clone_at_revision "${REPO_B}" "${CURRENT_COMMIT}"

# Hash each repo
pushd "${REPO_A}"
bazel test //... --config=clippy --config=rustfmt
"${CHECKER_BIN}" hash --output="${TEMP_DIR}/repo_a.json"
popd

pushd "${REPO_B}"
bazel test //... --config=clippy --config=rustfmt
"${CHECKER_BIN}" hash --output="${TEMP_DIR}/repo_b.json"
popd

# Compare results
"${CHECKER_BIN}" \
    check \
    --left="${TEMP_DIR}/repo_a.json" \
    --right="${TEMP_DIR}/repo_b.json" \
    --output="${TEMP_DIR}/results.json"

# If all checks passed, cleanup the new checkouts
pushd "${REPO_A}"
bazel clean --expunge --async
popd

pushd "${REPO_B}"
bazel clean --expunge --async
popd

rm -rf "${TEMP_DIR}"

echo "Success!"

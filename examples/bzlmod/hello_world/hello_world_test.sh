#!/usr/bin/env bash

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---


set -euo pipefail

# MARK - Functions

fail() {
  echo >&2 "$@"
  exit 1
}

# MARK - Args

if [[ "$#" -ne 2 ]]; then
  fail "Usage: $0 /path/to/hello_world_transient /path/to/hello_world_vendored"
fi
HELLO_WORLD_TRANSIENT="$(rlocation "$1")"
HELLO_WORLD_VENDORED="$(rlocation "$2")"

# MARK - Test

OUTPUT="$("${HELLO_WORLD_TRANSIENT}")"
[[ "${OUTPUT}" == "Hello, world!" ]] ||
  fail 'Expected "Hello, world!", but was' "${OUTPUT}"

OUTPUT="$("${HELLO_WORLD_VENDORED}")"
[[ "${OUTPUT}" == "Hello, world!" ]] ||
  fail 'Expected "Hello, world!", but was' "${OUTPUT}"

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
  fail "Usage: $0 /path/to/hello_world expected_arch"
fi
HELLO_WORLD="$(rlocation "$1")"
ARCH_STRING="$2"

# MARK - Test

OUTPUT="$(readelf -h "${HELLO_WORLD}")"

# Match the architecture string with grep.
echo "${OUTPUT}" | grep -E "Machine:(.+)${ARCH_STRING}" ||
  fail "Expected '${ARCH_STRING}' in ${OUTPUT}"

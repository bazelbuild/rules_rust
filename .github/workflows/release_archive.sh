#!/usr/bin/env bash
# Write the rules_rust source archive.
# Invoked by release_prep.sh and exercised by release_archive_test.sh.
#
# Args:
#   $1: workspace to archive.
#   $2: path of the archive to write.
#   $3...: target triples. The release job downloads each triple's cargo-bazel
#          binary to <workspace>/<triple>/; those directories stay out of the
#          archive because the binaries are published as separate assets.

set -euo pipefail

WORKSPACE="${1:?workspace required}"
ARCHIVE="${2:?archive required}"
shift 2

TRIPLE_EXCLUDES=()
for triple in "$@"; do
    TRIPLE_EXCLUDES+=("--exclude=./${triple}")
done

# `examples/hello_world` is included for the BCR presubmit; it must appear
# before --exclude="examples".
tar -czf "${ARCHIVE}" \
    -C "${WORKSPACE}" \
    --exclude=".git" \
    --exclude=".github" \
    --exclude="crate_universe/target" \
    --exclude="bazel-*" \
    --exclude="rules_rust-*.tar.gz" \
    --exclude="cargo-bazel-*" \
    "${TRIPLE_EXCLUDES[@]}" \
    examples/hello_world \
    --exclude="examples" \
    .

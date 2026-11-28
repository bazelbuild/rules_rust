#!/usr/bin/env bash
# Checks that release_archive.sh keeps the release job's downloads and the
# excluded directories out of the source archive.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

WORKSPACE="${TMP}/workspace"
for file in \
    MODULE.bazel \
    rust/defs.bzl \
    examples/hello_world/BUILD.bazel \
    examples/ffi/BUILD.bazel \
    .git/HEAD \
    .github/workflows/release.yaml \
    crate_universe/target/artifacts/x86_64-unknown-linux-gnu/cargo-bazel \
    x86_64-unknown-linux-gnu/cargo-bazel \
    x86_64-pc-windows-msvc/cargo-bazel.exe \
    rust/platform/x86_64-unknown-linux-gnu/BUILD.bazel; do
    mkdir -p "$(dirname "${WORKSPACE}/${file}")"
    echo "${file}" >"${WORKSPACE}/${file}"
done

"${SCRIPT_DIR}/release_archive.sh" "${WORKSPACE}" "${TMP}/rules_rust.tar.gz" \
    x86_64-unknown-linux-gnu \
    x86_64-pc-windows-msvc

MEMBERS="$(tar -tzf "${TMP}/rules_rust.tar.gz" | sed 's#^\./##' | grep -v '/$')"

status=0
for want in \
    MODULE.bazel \
    rust/defs.bzl \
    examples/hello_world/BUILD.bazel \
    rust/platform/x86_64-unknown-linux-gnu/BUILD.bazel; do
    if ! grep -qxF "${want}" <<<"${MEMBERS}"; then
        echo "missing from the archive: ${want}" >&2
        status=1
    fi
done
for unwanted in \
    examples/ffi/BUILD.bazel \
    .git/HEAD \
    .github/workflows/release.yaml \
    crate_universe/target/artifacts/x86_64-unknown-linux-gnu/cargo-bazel \
    x86_64-unknown-linux-gnu/cargo-bazel \
    x86_64-pc-windows-msvc/cargo-bazel.exe; do
    if grep -qxF "${unwanted}" <<<"${MEMBERS}"; then
        echo "unexpected in the archive: ${unwanted}" >&2
        status=1
    fi
done

if [[ "${status}" -ne 0 ]]; then
    echo "archive members:" >&2
    echo "${MEMBERS}" >&2
fi
exit "${status}"

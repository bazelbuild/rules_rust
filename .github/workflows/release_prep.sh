#!/usr/bin/env bash
# Build the rules_rust release archive and stage release assets.
# Invoked by bazel-contrib/.github/.github/workflows/release_ruleset.yaml.
#
# Args:
#   $1: tag name (e.g. 0.61.0). Must match VERSION in version.bzl.
#
# Side effects:
#   Writes rules_rust-${TAG}.tar.gz and renamed cargo-bazel-<triple>[.exe]
#   binaries to the current directory. These match the release_files glob in
#   release.yaml.
#
# Output:
#   Release notes to stdout. The release_ruleset workflow redirects this into
#   release_notes.txt for the GitHub release body. All build noise (bazel,
#   tar, sed, etc.) is redirected to stderr.

set -euo pipefail

# Redirect all stdout to stderr; keep fd 3 for the final release-notes write.
exec 3>&1 1>&2

TAG="${1:?tag_name required}"

WORKSPACE="${GITHUB_WORKSPACE:-$(pwd)}"
REPOSITORY_OWNER="${GITHUB_REPOSITORY_OWNER:-bazelbuild}"

# Validate the tag matches version.bzl.
ON_DISK_VERSION="$(grep 'VERSION =' "${WORKSPACE}/version.bzl" | sed 's/VERSION = "//' | sed 's/"//')"
if [[ "${ON_DISK_VERSION}" != "${TAG}" ]]; then
    echo "ERROR: tag ${TAG} does not match version.bzl VERSION=${ON_DISK_VERSION}"
    exit 1
fi

# Triples must match each artifact's `name:` in the `builds` matrix of release.yaml.
TRIPLES=(
    aarch64-apple-darwin
    aarch64-pc-windows-msvc
    aarch64-unknown-linux-gnu
    aarch64-unknown-linux-musl
    s390x-unknown-linux-gnu
    x86_64-apple-darwin
    x86_64-pc-windows-gnu
    x86_64-pc-windows-msvc
    x86_64-unknown-linux-gnu
    x86_64-unknown-linux-musl
)

# actions/download-artifact@v8 with no inputs places each artifact at
# ${GITHUB_WORKSPACE}/<artifact-name>/...; the matrix uploads use the triple as
# the name. Restructure into the layout urls_generator expects and restore the
# executable bit (download-artifact strips it on cross-runner downloads).
ARTIFACTS_DIR="${WORKSPACE}/crate_universe/target/artifacts"
mkdir -p "${ARTIFACTS_DIR}"
for triple in "${TRIPLES[@]}"; do
    src_dir="${WORKSPACE}/${triple}"
    if [[ ! -d "${src_dir}" ]]; then
        echo "ERROR: missing matrix artifact directory ${src_dir}"
        exit 1
    fi
    mkdir -p "${ARTIFACTS_DIR}/${triple}"
    if [[ "${triple}" == *windows* ]]; then
        binary="cargo-bazel.exe"
    else
        binary="cargo-bazel"
    fi
    cp "${src_dir}/${binary}" "${ARTIFACTS_DIR}/${triple}/${binary}"
    chmod +x "${ARTIFACTS_DIR}/${triple}/${binary}"
done

# Comment out rules_rust module overrides in any .bazelrc files so released
# users don't inherit local development overrides.
find "${WORKSPACE}" -name "*.bazelrc" -type f | while read -r file; do
    if grep -q "^common --override_module=rules_rust=" "${file}"; then
        echo "Commenting out module override in: ${file}"
        sed -i 's/^common --override_module=rules_rust=/# &/' "${file}"
    fi
done

# Update crate_universe/private/urls.bzl with download URLs and SHA256s for
# each platform's cargo-bazel binary.
export CARGO_BAZEL_GENERATOR_URL="file://${ARTIFACTS_DIR}/x86_64-unknown-linux-gnu/cargo-bazel"
URL_PREFIX="https://github.com/${REPOSITORY_OWNER}/rules_rust/releases/download/${TAG}"
(
    cd "${WORKSPACE}"
    bazel run //crate_universe/tools/urls_generator -- \
        --artifacts-dir="${ARTIFACTS_DIR}" \
        --url-prefix="${URL_PREFIX}"
    bazel clean
)

# Build the source archive. The on-disk filename matches the URL in
# .bcr/source.template.json — the SLSA attestation subject must equal the
# published asset name.
ARCHIVE="rules_rust-${TAG}.tar.gz"
# `examples/hello_world` is included for the BCR presubmit; it must appear
# before --exclude="examples".
tar -czf "${ARCHIVE}" \
    -C "${WORKSPACE}" \
    --exclude=".git" \
    --exclude=".github" \
    --exclude="crate_universe/target" \
    examples/hello_world \
    --exclude="examples" \
    .

# Rename cargo-bazel binaries to the release asset names expected by the
# release_files glob in release.yaml.
for triple in "${TRIPLES[@]}"; do
    if [[ "${triple}" == *windows* ]]; then
        cp "${ARTIFACTS_DIR}/${triple}/cargo-bazel.exe" "cargo-bazel-${triple}.exe"
    else
        cp "${ARTIFACTS_DIR}/${triple}/cargo-bazel" "cargo-bazel-${triple}"
    fi
done

# Compute the SRI-compatible base64 sha256 of the source archive for the
# release notes template.
SHA256_BASE64="$(shasum --algorithm 256 "${ARCHIVE}" | awk '{ print $1 }' | xxd -r -p | base64)"

# Render release notes and emit only the rendered content on the original
# stdout (fd 3) so the reusable workflow captures clean notes.
NOTES="$(mktemp)"
sed "s#{version}#${TAG}#g; s#{sha256_base64}#${SHA256_BASE64}#g" \
    "${WORKSPACE}/.github/release_notes.template" > "${NOTES}"
cat "${NOTES}" >&3

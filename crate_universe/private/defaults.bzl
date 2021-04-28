"""A module defining generated information about crate_universe dependencies"""

# This global should match the current release of `crate_unvierse`.
DEFAULT_URL_TEMPLATE = "{host_triple}{extension}"

# Note that if any additional platforms are added here, the pipeline defined
# by `pre-release.yaml` should also be updated. The current shas are from
# release canddidate {rc}
DEFAULT_SHA256_CHECKSUMS = {
    "aarch64-apple-darwin": "{aarch64-apple-darwin--sha256}",
    "aarch64-unknown-linux-gnu": "{aarch64-unknown-linux-gnu--sha256}",
    "x86_64-apple-darwin": "{x86_64-apple-darwin--sha256}",
    "x86_64-pc-windows-gnu": "{x86_64-pc-windows-gnu--sha256}",
    "x86_64-unknown-linux-gnu": "{x86_64-unknown-linux-gnu--sha256}",
}

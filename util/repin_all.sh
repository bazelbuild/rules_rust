#!/usr/bin/env bash
set -eux

# Normalize working directory to root of repository.
cd "$(dirname "${BASH_SOURCE[0]}")"/..

# Re-generates all files which may need to be re-generated after changing crate_universe.
for target in $(bazel query 'kind("crates_vendor", //...)'); do
  bazel run "${target}"
done

for d in examples/crate_universe/vendor_*; do
  (cd "${d}" && CARGO_BAZEL_REPIN=true bazel run :crates_vendor)
done

for d in examples/crate_universe* test/no_std
do
  (cd "${d}" && CARGO_BAZEL_REPIN=true bazel query //... >/dev/null)
done

# `nix_cross_compiling` special cased as `//...` will invoke Nix.
(cd examples/nix_cross_compiling && CARGO_BAZEL_REPIN=true bazel query @crate_index//... >/dev/null)

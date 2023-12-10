#!/usr/bin/env bash
set -eu

# Normalize working directory to root of repository.
cd "$(dirname "${BASH_SOURCE[0]}")"/..

# Re-generates all files which may need to be re-generated after changing crate_universe.
bazel run //crate_universe/3rdparty:crates_vendor

for d in examples/crate_universe* examples/nix_cross_compiling test/no_std
do
  (cd ${d} && CARGO_BAZEL_REPIN=true bazel query @crate_index//... >/dev/null)
done

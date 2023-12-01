#!/bin/bash -eu

# Re-generates all files which may need to be re-generated after changing crate_universe.

bazel run //crate_universe/3rdparty:crates_vendor

for d in examples/crate_universe* test/no_std
do
  (cd ${d} && CARGO_BAZEL_REPIN=true bazel query ... >/dev/null)
done

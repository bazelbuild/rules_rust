#!/usr/bin/env bash
set -eux

# Normalize working directory to root of repository.
cd "$(dirname "${BASH_SOURCE[0]}")"/..

# Build the cargo-bazel binary and expose it for repin operations.
bazel build -c opt //crate_universe:cargo_bazel_bin
CARGO_BAZEL_GENERATOR_URL="file://$(pwd)/$(bazel cquery -c opt --output=files //crate_universe:cargo_bazel_bin 2>/dev/null)"
export CARGO_BAZEL_GENERATOR_URL

# Re-generates all files which may need to be re-generated after changing crate_universe.
for target in $(bazel query 'kind("crates_vendor", //...)'); do
  bazel run "${target}"
done

for d in extensions/*; do
  pushd "${d}"
  for target in $(bazel query 'kind("crates_vendor", //...)'); do
    bazel run "${target}"
  done
  popd
done

# Vendor consolidated workspace
(cd crate_universe/tests/integration/vendor && \
  for target in $(bazel query 'kind("crates_vendor", //...)'); do
    CARGO_BAZEL_REPIN=true bazel run "${target}"
  done
)

for d in crate_universe/tests/integration/* examples/cross_compile_musl test/integration/no_std
do
  # vendor/ is handled explicitly above via bazel run of crates_vendor targets
  [[ "${d}" == */vendor ]] && continue
  (cd "${d}" && CARGO_BAZEL_REPIN=true bazel query //... >/dev/null)
done

# `nix_cross_compiling` special cased as `//...` will invoke Nix.
(cd examples/cross_compile_nix && CARGO_BAZEL_REPIN=true bazel query @crate_index//... >/dev/null)

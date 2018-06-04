#!/bin/bash
set -eu
set -o pipefail

if ! (which cargo &>/dev/null); then
    echo "Cannot find cargo in PATH, please install Cargo." >&2
    exit 1
fi

if ! (which cargo-raze &>/dev/null); then
    echo "Cannot find cargo-raze in PATH, please install cargo-raze (cargo install cargo-raze)." >&2
    exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")"

rm -fr remote
# Now run cargo generate-lockfile && cargo raze
cargo generate-lockfile && cargo raze

# We need to update the build file path.
sed -i.bak 's|//proto|@io_bazel_rules_rust//proto|g' "crates.bzl"
rm crates.bzl.bak

# And also add to the build file the binary target we need
cat >>BUILD <<EOF

alias(
    name = "protoc_gen_rust",
    actual = "@raze__protobuf_codegen__1_6_0//:cargo_bin_protoc_gen_rust",
)

alias(
    name = "protoc_gen_rust_grpc",
    actual = "@raze__grpc_compiler__0_4_0//:cargo_bin_protoc_gen_rust_grpc",
)
EOF

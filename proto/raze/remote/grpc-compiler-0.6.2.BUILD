"""
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""
package(default_visibility = [
  # Public for visibility by "@raze__crate__version//" targets.
  #
  # Prefer access through "//proto/raze", which limits external
  # visibility to explicit Cargo.toml dependencies.
  "//visibility:public",
])

licenses([
  "notice", # "MIT,Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)



rust_library(
    name = "grpc_compiler",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__protobuf__2_8_2//:protobuf",
        "@raze__protobuf_codegen__2_8_2//:protobuf_codegen",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.6.2",
    crate_features = [
    ],
)

rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_protoc_gen_rust_grpc",
    crate_root = "src/bin/protoc-gen-rust-grpc.rs",
    edition = "2015",
    srcs = glob(["**/*.rs"]),
    deps = [
        # Binaries get an implicit dependency on their crate's lib
        ":grpc_compiler",
        "@raze__protobuf__2_8_2//:protobuf",
        "@raze__protobuf_codegen__2_8_2//:protobuf_codegen",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.6.2",
    crate_features = [
    ],
)


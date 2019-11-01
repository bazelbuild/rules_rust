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
    "notice",  # "MIT,Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_protobuf_bin_gen_rust_do_not_use",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/bin/protobuf-bin-gen-rust-do-not-use.rs",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.6.0",
    deps = [
        # Binaries get an implicit dependency on their lib
        ":protobuf_codegen",
        "@raze__protobuf__1_6_0//:protobuf",
    ],
)

rust_library(
    name = "protobuf_codegen",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.6.0",
    deps = [
        "@raze__protobuf__1_6_0//:protobuf",
    ],
)

rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_protoc_gen_rust",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/bin/protoc-gen-rust.rs",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.6.0",
    deps = [
        # Binaries get an implicit dependency on their lib
        ":protobuf_codegen",
        "@raze__protobuf__1_6_0//:protobuf",
    ],
)

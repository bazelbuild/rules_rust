"""
@generated
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

# buildifier: disable=load
load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

# buildifier: disable=load
load("@bazel_skylib//lib:selects.bzl", "selects")

package(default_visibility = [
    # Public for visibility by "@raze__crate__version//" targets.
    #
    # Prefer access through "//proto/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "notice",  # MIT from expression "MIT"
])

# Generated targets

# buildifier: leave-alone
rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_protobuf_bin_gen_rust_do_not_use",
    deps = [
        # Binaries get an implicit dependency on their crate's lib
        ":protobuf_codegen",
        "@rules_rust_proto__protobuf__2_8_2//:protobuf",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/bin/protobuf-bin-gen-rust-do-not-use.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "2.8.2",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)

# buildifier: leave-alone
rust_library(
    name = "protobuf_codegen",
    crate_type = "lib",
    deps = [
        "@rules_rust_proto__protobuf__2_8_2//:protobuf",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "2.8.2",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)

# buildifier: leave-alone
rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_protoc_gen_rust",
    deps = [
        # Binaries get an implicit dependency on their crate's lib
        ":protobuf_codegen",
        "@rules_rust_proto__protobuf__2_8_2//:protobuf",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/bin/protoc-gen-rust.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "2.8.2",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)

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
# Unsupported target "bytes" with type "bench" omitted

# buildifier: leave-alone
rust_library(
    name = "bytes",
    crate_type = "lib",
    deps = [
        "@rules_rust_proto__byteorder__1_3_4//:byteorder",
        "@rules_rust_proto__iovec__0_1_4//:iovec",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.4.12",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
# Unsupported target "test_buf" with type "test" omitted
# Unsupported target "test_buf_mut" with type "test" omitted
# Unsupported target "test_bytes" with type "test" omitted
# Unsupported target "test_chain" with type "test" omitted
# Unsupported target "test_debug" with type "test" omitted
# Unsupported target "test_from_buf" with type "test" omitted
# Unsupported target "test_iter" with type "test" omitted
# Unsupported target "test_reader" with type "test" omitted
# Unsupported target "test_serde" with type "test" omitted
# Unsupported target "test_take" with type "test" omitted

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
    # Prefer access through "//bindgen/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "notice",  # MIT from expression "MIT OR Apache-2.0"
])

# Generated targets
# Unsupported target "build-script-build" with type "custom-build" omitted
# Unsupported target "comments" with type "test" omitted
# Unsupported target "features" with type "test" omitted
# Unsupported target "marker" with type "test" omitted

# buildifier: leave-alone
rust_library(
    name = "proc_macro2",
    crate_type = "lib",
    deps = [
        "@rules_rust_bindgen__unicode_xid__0_2_1//:unicode_xid",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.0.21",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
# Unsupported target "test" with type "test" omitted
# Unsupported target "test_fmt" with type "test" omitted

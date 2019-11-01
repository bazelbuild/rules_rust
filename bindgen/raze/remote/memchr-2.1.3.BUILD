"""
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

package(default_visibility = [
    # Public for visibility by "@raze__crate__version//" targets.
    #
    # Prefer access through "//bindgen/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "notice",  # "MIT"
    "unencumbered",  # "Unlicense"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

# Unsupported target "build-script-build" with type "custom-build" omitted

rust_library(
    name = "memchr",
    srcs = glob(["**/*.rs"]),
    crate_features = [
        "default",
        "libc",
        "use_std",
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "2.1.3",
    deps = [
        "@raze__cfg_if__0_1_6//:cfg_if",
        "@raze__libc__0_2_48//:libc",
    ],
)

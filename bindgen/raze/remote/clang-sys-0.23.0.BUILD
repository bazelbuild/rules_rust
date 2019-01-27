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
  "notice", # "Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)


# Unsupported target "build-script-build" with type "custom-build" omitted

rust_library(
    name = "clang_sys",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__glob__0_2_11//:glob",
        "@raze__libc__0_2_48//:libc",
        "@raze__libloading__0_5_0//:libloading",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.23.0",
    crate_features = [
        "clang_6_0",
        "gte_clang_3_6",
        "gte_clang_3_7",
        "gte_clang_3_8",
        "gte_clang_3_9",
        "gte_clang_4_0",
        "gte_clang_5_0",
        "gte_clang_6_0",
        "libloading",
        "runtime",
    ],
)

# Unsupported target "lib" with type "test" omitted

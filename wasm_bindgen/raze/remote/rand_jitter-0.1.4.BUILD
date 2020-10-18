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
    # Prefer access through "//wasm_bindgen/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "notice",  # MIT from expression "MIT OR Apache-2.0"
])

# Generated targets
# Unsupported target "mod" with type "bench" omitted
# Unsupported target "mod" with type "test" omitted

# buildifier: leave-alone
rust_library(
    name = "rand_jitter",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__rand_core__0_4_2//:rand_core",
    ] + selects.with_or({
        # cfg(any(target_os = "macos", target_os = "ios"))
        (
            "@io_bazel_rules_rust//rust/platform:aarch64-apple-ios",
            "@io_bazel_rules_rust//rust/platform:i686-apple-darwin",
            "@io_bazel_rules_rust//rust/platform:x86_64-apple-darwin",
            "@io_bazel_rules_rust//rust/platform:x86_64-apple-ios",
        ): [
            "@rules_rust_wasm_bindgen__libc__0_2_76//:libc",
        ],
        "//conditions:default": [],
    }) + selects.with_or({
        # cfg(target_os = "windows")
        (
            "@io_bazel_rules_rust//rust/platform:i686-pc-windows-msvc",
            "@io_bazel_rules_rust//rust/platform:x86_64-pc-windows-msvc",
        ): [
            "@rules_rust_wasm_bindgen__winapi__0_3_9//:winapi",
        ],
        "//conditions:default": [],
    }),
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.4",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "std",
    ],
    aliases = {
    },
)

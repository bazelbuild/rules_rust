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
# Unsupported target "build-script-build" with type "custom-build" omitted

# buildifier: leave-alone
rust_library(
    name = "libz_sys",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__libc__0_2_76//:libc",
    ] + selects.with_or({
        # cfg(target_env = "msvc")
        (
            "@io_bazel_rules_rust//rust/platform:i686-pc-windows-msvc",
            "@io_bazel_rules_rust//rust/platform:x86_64-pc-windows-msvc",
        ): [
        ],
        "//conditions:default": [],
    }),
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.1.2",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "libc",
    ],
    aliases = {
    },
)

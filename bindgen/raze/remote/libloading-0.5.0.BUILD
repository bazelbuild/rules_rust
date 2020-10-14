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
    "notice",  # ISC from expression "ISC"
])

# Generated targets
# Unsupported target "build-script-build" with type "custom-build" omitted
# Unsupported target "functions" with type "test" omitted

# buildifier: leave-alone
rust_library(
    name = "libloading",
    crate_type = "lib",
    deps = [
        ":global_static",
    ] + selects.with_or({
        # cfg(windows)
        (
            "@io_bazel_rules_rust//rust/platform:i686-pc-windows-gnu",
            "@io_bazel_rules_rust//rust/platform:x86_64-pc-windows-gnu",
        ): [
            "@rules_rust_bindgen__winapi__0_3_9//:winapi",
        ],
        "//conditions:default": [],
    }),
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.5.0",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
    aliases = {
    },
)
# Unsupported target "markers" with type "test" omitted
# Unsupported target "windows" with type "test" omitted

# Additional content from libloading-global-static.BUILD
# buildifier: disable=load-on-top
load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "global_static",
    srcs = ["src/os/unix/global_static.c"],
    copts = ["-fPIC"],
)

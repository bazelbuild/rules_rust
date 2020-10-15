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
# Unsupported target "bench_poll" with type "bench" omitted

# buildifier: leave-alone
rust_library(
    name = "mio",
    crate_type = "lib",
    deps = [
        "@rules_rust_proto__cfg_if__0_1_10//:cfg_if",
        "@rules_rust_proto__iovec__0_1_4//:iovec",
        "@rules_rust_proto__log__0_4_6//:log",
        "@rules_rust_proto__net2__0_2_33//:net2",
        "@rules_rust_proto__slab__0_4_2//:slab",
    ] + selects.with_or({
        # cfg(unix)
        (
            "@io_bazel_rules_rust//rust/platform:aarch64-apple-ios",
            "@io_bazel_rules_rust//rust/platform:aarch64-linux-android",
            "@io_bazel_rules_rust//rust/platform:aarch64-unknown-linux-gnu",
            "@io_bazel_rules_rust//rust/platform:arm-unknown-linux-gnueabi",
            "@io_bazel_rules_rust//rust/platform:i686-apple-darwin",
            "@io_bazel_rules_rust//rust/platform:i686-linux-android",
            "@io_bazel_rules_rust//rust/platform:i686-unknown-freebsd",
            "@io_bazel_rules_rust//rust/platform:i686-unknown-linux-gnu",
            "@io_bazel_rules_rust//rust/platform:powerpc-unknown-linux-gnu",
            "@io_bazel_rules_rust//rust/platform:s390x-unknown-linux-gnu",
            "@io_bazel_rules_rust//rust/platform:x86_64-apple-darwin",
            "@io_bazel_rules_rust//rust/platform:x86_64-apple-ios",
            "@io_bazel_rules_rust//rust/platform:x86_64-linux-android",
            "@io_bazel_rules_rust//rust/platform:x86_64-unknown-freebsd",
            "@io_bazel_rules_rust//rust/platform:x86_64-unknown-linux-gnu",
        ): [
            "@rules_rust_proto__libc__0_2_69//:libc",
        ],
        "//conditions:default": [],
    }) + selects.with_or({
        # cfg(windows)
        (
            "@io_bazel_rules_rust//rust/platform:i686-pc-windows-gnu",
            "@io_bazel_rules_rust//rust/platform:x86_64-pc-windows-gnu",
        ): [
            "@rules_rust_proto__kernel32_sys__0_2_2//:kernel32_sys",
            "@rules_rust_proto__miow__0_2_1//:miow",
            "@rules_rust_proto__winapi__0_2_8//:winapi",
        ],
        "//conditions:default": [],
    }),
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.6.21",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "default",
        "with-deprecated",
    ],
    aliases = {
    },
)
# Unsupported target "test" with type "test" omitted

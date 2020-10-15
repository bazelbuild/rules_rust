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
    "notice",  # MIT from expression "MIT OR Apache-2.0"
])

# Generated targets
# Unsupported target "bad" with type "test" omitted
# Unsupported target "smoke" with type "test" omitted

# buildifier: leave-alone
rust_library(
    name = "tokio_tls_api",
    crate_type = "lib",
    deps = [
        "@rules_rust_proto__futures__0_1_29//:futures",
        "@rules_rust_proto__tls_api__0_1_22//:tls_api",
        "@rules_rust_proto__tokio_io__0_1_13//:tokio_io",
    ] + selects.with_or({
        # cfg(all(not(target_os = "macos"), not(windows), not(target_os = "ios")))
        (
            "@io_bazel_rules_rust//rust/platform:aarch64-linux-android",
            "@io_bazel_rules_rust//rust/platform:aarch64-unknown-linux-gnu",
            "@io_bazel_rules_rust//rust/platform:arm-unknown-linux-gnueabi",
            "@io_bazel_rules_rust//rust/platform:i686-linux-android",
            "@io_bazel_rules_rust//rust/platform:i686-unknown-freebsd",
            "@io_bazel_rules_rust//rust/platform:i686-unknown-linux-gnu",
            "@io_bazel_rules_rust//rust/platform:powerpc-unknown-linux-gnu",
            "@io_bazel_rules_rust//rust/platform:s390x-unknown-linux-gnu",
            "@io_bazel_rules_rust//rust/platform:wasm32-unknown-unknown",
            "@io_bazel_rules_rust//rust/platform:x86_64-linux-android",
            "@io_bazel_rules_rust//rust/platform:x86_64-unknown-freebsd",
            "@io_bazel_rules_rust//rust/platform:x86_64-unknown-linux-gnu",
        ): [
        ],
        "//conditions:default": [],
    }) + selects.with_or({
        # cfg(any(target_os = "macos", target_os = "ios"))
        (
            "@io_bazel_rules_rust//rust/platform:aarch64-apple-ios",
            "@io_bazel_rules_rust//rust/platform:i686-apple-darwin",
            "@io_bazel_rules_rust//rust/platform:x86_64-apple-darwin",
            "@io_bazel_rules_rust//rust/platform:x86_64-apple-ios",
        ): [
        ],
        "//conditions:default": [],
    }) + selects.with_or({
        # cfg(windows)
        (
            "@io_bazel_rules_rust//rust/platform:i686-pc-windows-gnu",
            "@io_bazel_rules_rust//rust/platform:x86_64-pc-windows-gnu",
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
    version = "0.1.22",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
    aliases = {
    },
)

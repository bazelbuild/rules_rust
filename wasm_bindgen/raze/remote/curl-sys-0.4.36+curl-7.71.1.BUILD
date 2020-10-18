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
    "notice",  # MIT from expression "MIT"
])

# Generated targets
# Unsupported target "build-script-build" with type "custom-build" omitted

# buildifier: leave-alone
rust_library(
    name = "curl_sys",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__libc__0_2_76//:libc",
        "@rules_rust_wasm_bindgen__libz_sys__1_1_2//:libz_sys",
    ] + selects.with_or({
        # cfg(all(unix, not(target_os = "macos")))
        (
            "@io_bazel_rules_rust//rust/platform:aarch64-apple-ios",
            "@io_bazel_rules_rust//rust/platform:aarch64-linux-android",
            "@io_bazel_rules_rust//rust/platform:aarch64-unknown-linux-gnu",
            "@io_bazel_rules_rust//rust/platform:arm-unknown-linux-gnueabi",
            "@io_bazel_rules_rust//rust/platform:i686-linux-android",
            "@io_bazel_rules_rust//rust/platform:i686-unknown-freebsd",
            "@io_bazel_rules_rust//rust/platform:i686-unknown-linux-gnu",
            "@io_bazel_rules_rust//rust/platform:powerpc-unknown-linux-gnu",
            "@io_bazel_rules_rust//rust/platform:s390x-unknown-linux-gnu",
            "@io_bazel_rules_rust//rust/platform:x86_64-apple-ios",
            "@io_bazel_rules_rust//rust/platform:x86_64-linux-android",
            "@io_bazel_rules_rust//rust/platform:x86_64-unknown-freebsd",
            "@io_bazel_rules_rust//rust/platform:x86_64-unknown-linux-gnu",
        ): [
            "@rules_rust_wasm_bindgen__openssl_sys__0_9_58//:openssl_sys",
        ],
        "//conditions:default": [],
    }) + selects.with_or({
        # cfg(target_env = "msvc")
        (
            "@io_bazel_rules_rust//rust/platform:i686-pc-windows-msvc",
            "@io_bazel_rules_rust//rust/platform:x86_64-pc-windows-msvc",
        ): [
        ],
        "//conditions:default": [],
    }) + selects.with_or({
        # cfg(windows)
        (
            "@io_bazel_rules_rust//rust/platform:i686-pc-windows-msvc",
            "@io_bazel_rules_rust//rust/platform:x86_64-pc-windows-msvc",
        ): [
            "@rules_rust_wasm_bindgen__winapi__0_3_9//:winapi",
        ],
        "//conditions:default": [],
    }),
    srcs = glob(["**/*.rs"]),
    crate_root = "lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.4.36+curl-7.71.1",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "openssl-sys",
        "ssl",
    ],
    aliases = {
    },
)

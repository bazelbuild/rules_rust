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
# Unsupported target "distributions" with type "bench" omitted
# Unsupported target "generators" with type "bench" omitted
# Unsupported target "misc" with type "bench" omitted
# Unsupported target "monte-carlo" with type "example" omitted
# Unsupported target "monty-hall" with type "example" omitted

# buildifier: leave-alone
rust_library(
    name = "rand",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__rand_chacha__0_1_1//:rand_chacha",
        "@rules_rust_wasm_bindgen__rand_core__0_4_2//:rand_core",
        "@rules_rust_wasm_bindgen__rand_hc__0_1_0//:rand_hc",
        "@rules_rust_wasm_bindgen__rand_isaac__0_1_1//:rand_isaac",
        "@rules_rust_wasm_bindgen__rand_jitter__0_1_4//:rand_jitter",
        "@rules_rust_wasm_bindgen__rand_os__0_1_3//:rand_os",
        "@rules_rust_wasm_bindgen__rand_pcg__0_1_2//:rand_pcg",
        "@rules_rust_wasm_bindgen__rand_xorshift__0_1_1//:rand_xorshift",
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
            "@rules_rust_wasm_bindgen__libc__0_2_79//:libc",
        ],
        "//conditions:default": [],
    }) + selects.with_or({
        # cfg(windows)
        (
            "@io_bazel_rules_rust//rust/platform:i686-pc-windows-gnu",
            "@io_bazel_rules_rust//rust/platform:x86_64-pc-windows-gnu",
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
    version = "0.6.5",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "alloc",
        "default",
        "rand_os",
        "std",
    ],
    aliases = {
    },
)
# Unsupported target "seq" with type "bench" omitted
# Unsupported target "uniformity" with type "test" omitted

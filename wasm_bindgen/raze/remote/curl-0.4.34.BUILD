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
# Unsupported target "atexit" with type "test" omitted
# Unsupported target "build-script-build" with type "custom-build" omitted

# buildifier: leave-alone
rust_library(
    name = "curl",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__curl_sys__0_4_38_curl_7_73_0//:curl_sys",
        "@rules_rust_wasm_bindgen__libc__0_2_79//:libc",
        "@rules_rust_wasm_bindgen__socket2__0_3_15//:socket2",
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
            "@rules_rust_wasm_bindgen__openssl_probe__0_1_2//:openssl_probe",
            "@rules_rust_wasm_bindgen__openssl_sys__0_9_58//:openssl_sys",
        ],
        "//conditions:default": [],
    }),
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.4.34",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "default",
        "openssl-probe",
        "openssl-sys",
        "ssl",
    ],
    aliases = {
    },
)
# Unsupported target "easy" with type "test" omitted
# Unsupported target "multi" with type "test" omitted
# Unsupported target "post" with type "test" omitted
# Unsupported target "protocols" with type "test" omitted
# Unsupported target "ssl_proxy" with type "example" omitted

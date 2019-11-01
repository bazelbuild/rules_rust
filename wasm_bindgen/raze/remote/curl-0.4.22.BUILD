"""
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

package(default_visibility = [
    # Public for visibility by "@raze__crate__version//" targets.
    #
    # Prefer access through "//wasm_bindgen/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "notice",  # "MIT"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

# Unsupported target "atexit" with type "test" omitted
# Unsupported target "build-script-build" with type "custom-build" omitted

rust_library(
    name = "curl",
    srcs = glob(["**/*.rs"]),
    crate_features = [
        "curl-sys",
        "default",
        "openssl-probe",
        "openssl-sys",
        "ssl",
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.4.22",
    deps = [
        "@raze__curl_sys__0_4_19//:curl_sys",
        "@raze__libc__0_2_58//:libc",
        "@raze__openssl_probe__0_1_2//:openssl_probe",
        "@raze__openssl_sys__0_9_47//:openssl_sys",
        "@raze__socket2__0_3_9//:socket2",
    ],
)

# Unsupported target "easy" with type "test" omitted
# Unsupported target "multi" with type "test" omitted
# Unsupported target "post" with type "test" omitted

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
    "notice",  # "MIT,Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

# Unsupported target "database" with type "example" omitted
# Unsupported target "git-http-backend" with type "example" omitted
# Unsupported target "hello-world" with type "example" omitted
# Unsupported target "login-session" with type "example" omitted
# Unsupported target "php" with type "example" omitted
# Unsupported target "reverse-proxy" with type "example" omitted

rust_library(
    name = "rouille",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "3.0.0",
    deps = [
        "@raze__base64__0_9_3//:base64",
        "@raze__chrono__0_4_7//:chrono",
        "@raze__filetime__0_2_6//:filetime",
        "@raze__multipart__0_15_4//:multipart",
        "@raze__num_cpus__1_10_1//:num_cpus",
        "@raze__rand__0_5_6//:rand",
        "@raze__serde__1_0_94//:serde",
        "@raze__serde_json__1_0_39//:serde_json",
        "@raze__sha1__0_6_0//:sha1",
        "@raze__term__0_5_2//:term",
        "@raze__threadpool__1_7_1//:threadpool",
        "@raze__time__0_1_42//:time",
        "@raze__tiny_http__0_6_2//:tiny_http",
        "@raze__url__1_7_2//:url",
    ],
    proc_macro_deps = [
        "@raze__serde_derive__1_0_94//:serde_derive",
    ],
)

# Unsupported target "simple-form" with type "example" omitted
# Unsupported target "static-files" with type "example" omitted
# Unsupported target "websocket" with type "example" omitted

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
# Unsupported target "database" with type "example" omitted
# Unsupported target "git-http-backend" with type "example" omitted
# Unsupported target "hello-world" with type "example" omitted
# Unsupported target "login-session" with type "example" omitted
# Unsupported target "php" with type "example" omitted
# Unsupported target "reverse-proxy" with type "example" omitted

# buildifier: leave-alone
rust_library(
    name = "rouille",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__base64__0_9_3//:base64",
        "@rules_rust_wasm_bindgen__chrono__0_4_19//:chrono",
        "@rules_rust_wasm_bindgen__filetime__0_2_12//:filetime",
        "@rules_rust_wasm_bindgen__multipart__0_15_4//:multipart",
        "@rules_rust_wasm_bindgen__num_cpus__1_13_0//:num_cpus",
        "@rules_rust_wasm_bindgen__rand__0_5_6//:rand",
        "@rules_rust_wasm_bindgen__serde__1_0_116//:serde",
        "@rules_rust_wasm_bindgen__serde_json__1_0_59//:serde_json",
        "@rules_rust_wasm_bindgen__sha1__0_6_0//:sha1",
        "@rules_rust_wasm_bindgen__term__0_5_2//:term",
        "@rules_rust_wasm_bindgen__threadpool__1_8_1//:threadpool",
        "@rules_rust_wasm_bindgen__time__0_1_44//:time",
        "@rules_rust_wasm_bindgen__tiny_http__0_6_2//:tiny_http",
        "@rules_rust_wasm_bindgen__url__1_7_2//:url",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    proc_macro_deps = [
        "@rules_rust_wasm_bindgen__serde_derive__1_0_116//:serde_derive",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "3.0.0",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
# Unsupported target "simple-form" with type "example" omitted
# Unsupported target "static-files" with type "example" omitted
# Unsupported target "websocket" with type "example" omitted

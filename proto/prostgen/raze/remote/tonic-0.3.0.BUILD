"""
@generated
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""
package(default_visibility = [
  # Public for visibility by "@raze__crate__version//" targets.
  #
  # Prefer access through "//proto/prostgen/raze", which limits external
  # visibility to explicit Cargo.toml dependencies.
  "//visibility:public",
])

licenses([
  "notice", # MIT from expression "MIT"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)


# Unsupported target "decode" with type "bench" omitted

rust_library(
    name = "tonic",
    crate_type = "lib",
    deps = [
        "@raze__async_stream__0_2_1//:async_stream",
        "@raze__base64__0_12_3//:base64",
        "@raze__bytes__0_5_6//:bytes",
        "@raze__futures_core__0_3_5//:futures_core",
        "@raze__futures_util__0_3_5//:futures_util",
        "@raze__http__0_2_1//:http",
        "@raze__http_body__0_3_1//:http_body",
        "@raze__hyper__0_13_6//:hyper",
        "@raze__percent_encoding__2_1_0//:percent_encoding",
        "@raze__pin_project__0_4_23//:pin_project",
        "@raze__prost__0_6_1//:prost",
        "@raze__rustls_native_certs__0_4_0//:rustls_native_certs",
        "@raze__tokio__0_2_22//:tokio",
        "@raze__tokio_rustls__0_14_1//:tokio_rustls",
        "@raze__tokio_util__0_3_1//:tokio_util",
        "@raze__tower__0_3_1//:tower",
        "@raze__tower_balance__0_3_0//:tower_balance",
        "@raze__tower_load__0_3_0//:tower_load",
        "@raze__tower_make__0_3_0//:tower_make",
        "@raze__tower_service__0_3_0//:tower_service",
        "@raze__tracing__0_1_19//:tracing",
        "@raze__tracing_futures__0_2_4//:tracing_futures",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    proc_macro_deps = [
        "@raze__async_trait__0_1_40//:async_trait",
        "@raze__prost_derive__0_6_1//:prost_derive",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.3.0",
    tags = ["cargo-raze"],
    crate_features = [
        "async-trait",
        "codegen",
        "default",
        "hyper",
        "prost",
        "prost-derive",
        "prost1",
        "rustls-native-certs",
        "tls",
        "tls-roots",
        "tokio",
        "tokio-rustls",
        "tower",
        "tower-balance",
        "tower-load",
        "tracing-futures",
        "transport",
    ],
    aliases = {
        "@raze__prost__0_6_1//:prost": "prost1",
    },
)


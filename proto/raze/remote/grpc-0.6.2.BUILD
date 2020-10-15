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
# Unsupported target "client" with type "test" omitted

# buildifier: leave-alone
rust_library(
    name = "grpc",
    crate_type = "lib",
    deps = [
        "@rules_rust_proto__base64__0_9_3//:base64",
        "@rules_rust_proto__bytes__0_4_12//:bytes",
        "@rules_rust_proto__futures__0_1_29//:futures",
        "@rules_rust_proto__futures_cpupool__0_1_8//:futures_cpupool",
        "@rules_rust_proto__httpbis__0_7_0//:httpbis",
        "@rules_rust_proto__log__0_4_6//:log",
        "@rules_rust_proto__protobuf__2_8_2//:protobuf",
        "@rules_rust_proto__tls_api__0_1_22//:tls_api",
        "@rules_rust_proto__tls_api_stub__0_1_22//:tls_api_stub",
        "@rules_rust_proto__tokio_core__0_1_17//:tokio_core",
        "@rules_rust_proto__tokio_io__0_1_13//:tokio_io",
        "@rules_rust_proto__tokio_tls_api__0_1_22//:tokio_tls_api",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.6.2",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
# Unsupported target "server" with type "test" omitted
# Unsupported target "simple" with type "test" omitted

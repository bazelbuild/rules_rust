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
# Unsupported target "buffered" with type "test" omitted
# Unsupported target "chain" with type "test" omitted
# Unsupported target "chat" with type "example" omitted
# Unsupported target "compress" with type "example" omitted
# Unsupported target "connect" with type "example" omitted
# Unsupported target "echo" with type "example" omitted
# Unsupported target "echo" with type "test" omitted
# Unsupported target "echo-threads" with type "example" omitted
# Unsupported target "echo-udp" with type "example" omitted
# Unsupported target "hello" with type "example" omitted
# Unsupported target "interval" with type "test" omitted
# Unsupported target "latency" with type "bench" omitted
# Unsupported target "limit" with type "test" omitted
# Unsupported target "line-frames" with type "test" omitted
# Unsupported target "mio-ops" with type "bench" omitted
# Unsupported target "pipe-hup" with type "test" omitted
# Unsupported target "proxy" with type "example" omitted
# Unsupported target "sink" with type "example" omitted
# Unsupported target "spawn" with type "test" omitted
# Unsupported target "stream-buffered" with type "test" omitted
# Unsupported target "tcp" with type "bench" omitted
# Unsupported target "tcp" with type "test" omitted
# Unsupported target "timeout" with type "test" omitted
# Unsupported target "tinydb" with type "example" omitted
# Unsupported target "tinyhttp" with type "example" omitted

# buildifier: leave-alone
rust_library(
    name = "tokio_core",
    crate_type = "lib",
    deps = [
        "@rules_rust_proto__bytes__0_4_12//:bytes",
        "@rules_rust_proto__futures__0_1_29//:futures",
        "@rules_rust_proto__iovec__0_1_4//:iovec",
        "@rules_rust_proto__log__0_4_6//:log",
        "@rules_rust_proto__mio__0_6_21//:mio",
        "@rules_rust_proto__scoped_tls__0_1_2//:scoped_tls",
        "@rules_rust_proto__tokio__0_1_22//:tokio",
        "@rules_rust_proto__tokio_executor__0_1_10//:tokio_executor",
        "@rules_rust_proto__tokio_io__0_1_13//:tokio_io",
        "@rules_rust_proto__tokio_reactor__0_1_12//:tokio_reactor",
        "@rules_rust_proto__tokio_timer__0_2_13//:tokio_timer",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.17",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
# Unsupported target "udp" with type "test" omitted
# Unsupported target "udp-codec" with type "example" omitted

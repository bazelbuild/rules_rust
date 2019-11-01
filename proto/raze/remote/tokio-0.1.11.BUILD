"""
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

package(default_visibility = [
    # Public for visibility by "@raze__crate__version//" targets.
    #
    # Prefer access through "//proto/raze", which limits external
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

# Unsupported target "buffered" with type "test" omitted
# Unsupported target "chat" with type "example" omitted
# Unsupported target "chat-combinator" with type "example" omitted
# Unsupported target "clock" with type "test" omitted
# Unsupported target "connect" with type "example" omitted
# Unsupported target "drop-core" with type "test" omitted
# Unsupported target "echo" with type "example" omitted
# Unsupported target "echo-udp" with type "example" omitted
# Unsupported target "global" with type "test" omitted
# Unsupported target "hello_world" with type "example" omitted
# Unsupported target "latency" with type "bench" omitted
# Unsupported target "length_delimited" with type "test" omitted
# Unsupported target "line-frames" with type "test" omitted
# Unsupported target "manual-runtime" with type "example" omitted
# Unsupported target "mio-ops" with type "bench" omitted
# Unsupported target "pipe-hup" with type "test" omitted
# Unsupported target "print_each_packet" with type "example" omitted
# Unsupported target "proxy" with type "example" omitted
# Unsupported target "reactor" with type "test" omitted
# Unsupported target "runtime" with type "test" omitted
# Unsupported target "tcp" with type "bench" omitted
# Unsupported target "timer" with type "test" omitted
# Unsupported target "tinydb" with type "example" omitted
# Unsupported target "tinyhttp" with type "example" omitted

rust_library(
    name = "tokio",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.11",
    deps = [
        "@raze__bytes__0_4_10//:bytes",
        "@raze__futures__0_1_25//:futures",
        "@raze__mio__0_6_16//:mio",
        "@raze__tokio_codec__0_1_1//:tokio_codec",
        "@raze__tokio_current_thread__0_1_3//:tokio_current_thread",
        "@raze__tokio_executor__0_1_5//:tokio_executor",
        "@raze__tokio_fs__0_1_4//:tokio_fs",
        "@raze__tokio_io__0_1_10//:tokio_io",
        "@raze__tokio_reactor__0_1_6//:tokio_reactor",
        "@raze__tokio_tcp__0_1_2//:tokio_tcp",
        "@raze__tokio_threadpool__0_1_8//:tokio_threadpool",
        "@raze__tokio_timer__0_2_7//:tokio_timer",
        "@raze__tokio_udp__0_1_2//:tokio_udp",
        "@raze__tokio_uds__0_2_3//:tokio_uds",
    ],
)

# Unsupported target "udp-client" with type "example" omitted
# Unsupported target "udp-codec" with type "example" omitted

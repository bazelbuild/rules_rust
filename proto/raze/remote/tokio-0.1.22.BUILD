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
  "notice", # "MIT"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)


# Unsupported target "blocking" with type "example" omitted
# Unsupported target "buffered" with type "test" omitted
# Unsupported target "chat" with type "example" omitted
# Unsupported target "chat-combinator" with type "example" omitted
# Unsupported target "chat-combinator-current-thread" with type "example" omitted
# Unsupported target "clock" with type "test" omitted
# Unsupported target "connect" with type "example" omitted
# Unsupported target "drop-core" with type "test" omitted
# Unsupported target "echo" with type "example" omitted
# Unsupported target "echo-udp" with type "example" omitted
# Unsupported target "enumerate" with type "test" omitted
# Unsupported target "global" with type "test" omitted
# Unsupported target "hello_world" with type "example" omitted
# Unsupported target "length_delimited" with type "test" omitted
# Unsupported target "line-frames" with type "test" omitted
# Unsupported target "manual-runtime" with type "example" omitted
# Unsupported target "pipe-hup" with type "test" omitted
# Unsupported target "print_each_packet" with type "example" omitted
# Unsupported target "proxy" with type "example" omitted
# Unsupported target "reactor" with type "test" omitted
# Unsupported target "runtime" with type "test" omitted
# Unsupported target "timer" with type "test" omitted
# Unsupported target "tinydb" with type "example" omitted
# Unsupported target "tinyhttp" with type "example" omitted

rust_library(
    name = "tokio",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__bytes__0_4_12//:bytes",
        "@raze__futures__0_1_29//:futures",
        "@raze__mio__0_6_21//:mio",
        "@raze__num_cpus__1_13_0//:num_cpus",
        "@raze__tokio_codec__0_1_2//:tokio_codec",
        "@raze__tokio_current_thread__0_1_7//:tokio_current_thread",
        "@raze__tokio_executor__0_1_10//:tokio_executor",
        "@raze__tokio_fs__0_1_7//:tokio_fs",
        "@raze__tokio_io__0_1_13//:tokio_io",
        "@raze__tokio_reactor__0_1_12//:tokio_reactor",
        "@raze__tokio_sync__0_1_8//:tokio_sync",
        "@raze__tokio_tcp__0_1_4//:tokio_tcp",
        "@raze__tokio_threadpool__0_1_18//:tokio_threadpool",
        "@raze__tokio_timer__0_2_13//:tokio_timer",
        "@raze__tokio_udp__0_1_6//:tokio_udp",
        "@raze__tokio_uds__0_2_6//:tokio_uds",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.22",
    crate_features = [
        "bytes",
        "codec",
        "default",
        "fs",
        "io",
        "mio",
        "num_cpus",
        "reactor",
        "rt-full",
        "sync",
        "tcp",
        "timer",
        "tokio-codec",
        "tokio-current-thread",
        "tokio-executor",
        "tokio-fs",
        "tokio-io",
        "tokio-reactor",
        "tokio-sync",
        "tokio-tcp",
        "tokio-threadpool",
        "tokio-timer",
        "tokio-udp",
        "tokio-uds",
        "udp",
        "uds",
    ],
)

# Unsupported target "udp-client" with type "example" omitted
# Unsupported target "udp-codec" with type "example" omitted

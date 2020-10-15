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
    "notice",  # MIT from expression "MIT"
])

# Generated targets
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

# buildifier: leave-alone
rust_library(
    name = "tokio",
    crate_type = "lib",
    deps = [
        "@rules_rust_proto__bytes__0_4_12//:bytes",
        "@rules_rust_proto__futures__0_1_29//:futures",
        "@rules_rust_proto__mio__0_6_21//:mio",
        "@rules_rust_proto__num_cpus__1_13_0//:num_cpus",
        "@rules_rust_proto__tokio_codec__0_1_2//:tokio_codec",
        "@rules_rust_proto__tokio_current_thread__0_1_7//:tokio_current_thread",
        "@rules_rust_proto__tokio_executor__0_1_10//:tokio_executor",
        "@rules_rust_proto__tokio_fs__0_1_7//:tokio_fs",
        "@rules_rust_proto__tokio_io__0_1_13//:tokio_io",
        "@rules_rust_proto__tokio_reactor__0_1_12//:tokio_reactor",
        "@rules_rust_proto__tokio_sync__0_1_8//:tokio_sync",
        "@rules_rust_proto__tokio_tcp__0_1_4//:tokio_tcp",
        "@rules_rust_proto__tokio_threadpool__0_1_18//:tokio_threadpool",
        "@rules_rust_proto__tokio_timer__0_2_13//:tokio_timer",
        "@rules_rust_proto__tokio_udp__0_1_6//:tokio_udp",
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
            "@rules_rust_proto__tokio_uds__0_2_6//:tokio_uds",
        ],
        "//conditions:default": [],
    }),
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.22",
    tags = [
        "cargo-raze",
        "manual",
    ],
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
    aliases = {
    },
)
# Unsupported target "udp-client" with type "example" omitted
# Unsupported target "udp-codec" with type "example" omitted

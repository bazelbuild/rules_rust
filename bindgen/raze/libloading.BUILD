"""
OVERRIDDEN:
cargo-raze crate build file.

- Libloading has a CC dep that needs to be built.
"""

load("@rules_cc//cc:defs.bzl", "cc_library")

licenses([
    "notice",  # "ISC"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_benchmark",
    "rust_binary",
    "rust_library",
    "rust_test",
)

cc_library(
    name = "global_static",
    srcs = ["src/os/unix/global_static.c"],
    copts = ["-fPIC"],
)

rust_library(
    name = "libloading",
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    crate_type = "lib",
    rustc_flags = ["--cap-lints=allow"],
    visibility = ["//visibility:public"],
    deps = [":global_static"],
)

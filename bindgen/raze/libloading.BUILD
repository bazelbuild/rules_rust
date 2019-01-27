"""
OVERRIDDEN:
cargo-raze crate build file.

- Libloading has a CC dep that needs to be brought in
"""

package(default_visibility = ["//visibility:public"])

licenses([
    "notice",  # "ISC"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
    "rust_benchmark",
)

cc_library(
    name = "global_whatever",
    srcs = [
        "src/os/unix/global_static.c",
    ],
    copts = [ "-fPIC" ],
)

rust_library(
    name = "libloading",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    deps = [
        ":global_whatever",
    ],
)

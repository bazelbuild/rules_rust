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
# Unsupported target "build-script-build" with type "custom-build" omitted

# buildifier: leave-alone
rust_library(
    name = "winapi",
    crate_type = "lib",
    deps = [
    ] + selects.with_or({
        # i686-pc-windows-gnu
        (
            "@io_bazel_rules_rust//rust/platform:i686-pc-windows-gnu",
        ): [
            "@rules_rust_proto__winapi_i686_pc_windows_gnu__0_4_0//:winapi_i686_pc_windows_gnu",
        ],
        "//conditions:default": [],
    }) + selects.with_or({
        # x86_64-pc-windows-gnu
        (
            "@io_bazel_rules_rust//rust/platform:x86_64-pc-windows-gnu",
        ): [
            "@rules_rust_proto__winapi_x86_64_pc_windows_gnu__0_4_0//:winapi_x86_64_pc_windows_gnu",
        ],
        "//conditions:default": [],
    }),
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.3.8",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "errhandlingapi",
        "handleapi",
        "minwindef",
        "ntstatus",
        "winbase",
        "winerror",
        "winnt",
        "winsock2",
        "ws2def",
        "ws2ipdef",
        "ws2tcpip",
    ],
    aliases = {
    },
)

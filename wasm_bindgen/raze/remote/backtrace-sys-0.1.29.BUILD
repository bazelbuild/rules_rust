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

# buildifier: leave-alone
rust_library(
    name = "backtrace_sys",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__libc__0_2_77//:libc",
        ":native_backtrace",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.29",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
# Unsupported target "build-script-build" with type "custom-build" omitted

# Additional content from overrides/backtrace-sys-0.1.29.BUILD
load("@rules_cc//cc:defs.bzl", "cc_library")

package(default_visibility = ["//ext/public/rust/cargo:__subpackages__"])

licenses([
    "notice",  # "MIT,Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
)

genrule(
    name = "touch_config_header",
    outs = [
        "config.h",
    ],
    cmd = "touch $@",
)

genrule(
    name = "touch_backtrace_supported_header",
    outs = [
        "backtrace-supported.h",
    ],
    cmd = "touch $@",
)

cc_library(
    name = "backtrace_native",
    srcs = [
        "src/libbacktrace/alloc.c",
        "src/libbacktrace/backtrace.h",
        "src/libbacktrace/dwarf.c",
        "src/libbacktrace/elf.c",
        "src/libbacktrace/fileline.c",
        "src/libbacktrace/internal.h",
        "src/libbacktrace/posix.c",
        "src/libbacktrace/read.c",
        "src/libbacktrace/sort.c",
        "src/libbacktrace/state.c",
        ":touch_backtrace_supported_header",
        ":touch_config_header",
    ],
    copts = [
        "-fvisibility=hidden",
        "-fPIC",
    ],
    defines = [
        "BACKTRACE_ELF_SIZE=64",
        "BACKTRACE_SUPPORTED=1",
        "BACKTRACE_USES_MALLOC=1",
        "BACKTRACE_SUPPORTS_THREADS=0",
        "BACKTRACE_SUPPORTS_DATA=0",
        "_GNU_SOURCE=1",
        "_LARGE_FILES=1",
    ],
    includes = ["."],
)

rust_library(
    name = "backtrace_sys",
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    crate_type = "lib",
    visibility = ["//visibility:public"],
    deps = [
        ":backtrace_native",
        "@raze__libc__0_2_58//:libc",
    ],
)

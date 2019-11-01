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

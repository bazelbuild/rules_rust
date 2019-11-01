"""
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

package(default_visibility = [
    # Public for visibility by "@raze__crate__version//" targets.
    #
    # Prefer access through "//wasm_bindgen/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "notice",  # "MIT,Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

# Unsupported target "accuracy" with type "test" omitted
# Unsupported target "backtrace" with type "example" omitted

rust_library(
    name = "backtrace",
    srcs = glob(["**/*.rs"]),
    crate_features = [
        "backtrace-sys",
        "dbghelp",
        "default",
        "dladdr",
        "libbacktrace",
        "libunwind",
        "std",
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.3.32",
    deps = [
        "@raze__cfg_if__0_1_9//:cfg_if",
        "@raze__libc__0_2_58//:libc",
        "@raze__rustc_demangle__0_1_15//:rustc_demangle",
        "@wasm_bindgen_backtrace_sys_0_1_29//:backtrace_sys",
    ],
)

# Unsupported target "benchmarks" with type "bench" omitted
# Unsupported target "long_fn_name" with type "test" omitted
# Unsupported target "raw" with type "example" omitted
# Unsupported target "skip_inner_frames" with type "test" omitted
# Unsupported target "smoke" with type "test" omitted

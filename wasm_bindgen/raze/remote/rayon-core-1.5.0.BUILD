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
    "notice",  # "Apache-2.0,MIT"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

# Unsupported target "build-script-build" with type "custom-build" omitted
# Unsupported target "double_init_fail" with type "test" omitted
# Unsupported target "init_zero_threads" with type "test" omitted

rust_library(
    name = "rayon_core",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.5.0",
    deps = [
        "@raze__crossbeam_deque__0_6_3//:crossbeam_deque",
        "@raze__crossbeam_queue__0_1_2//:crossbeam_queue",
        "@raze__crossbeam_utils__0_6_5//:crossbeam_utils",
        "@raze__lazy_static__1_3_0//:lazy_static",
        "@raze__num_cpus__1_10_1//:num_cpus",
    ],
)

# Unsupported target "scope_join" with type "test" omitted
# Unsupported target "scoped_threadpool" with type "test" omitted
# Unsupported target "simple_panic" with type "test" omitted
# Unsupported target "stack_overflow_crash" with type "test" omitted

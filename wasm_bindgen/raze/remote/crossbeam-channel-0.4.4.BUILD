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
# Unsupported target "after" with type "test" omitted
# Unsupported target "array" with type "test" omitted
# Unsupported target "crossbeam" with type "bench" omitted

# buildifier: leave-alone
rust_library(
    name = "crossbeam_channel",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__crossbeam_utils__0_7_2//:crossbeam_utils",
        "@rules_rust_wasm_bindgen__maybe_uninit__2_0_0//:maybe_uninit",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.4.4",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
# Unsupported target "fibonacci" with type "example" omitted
# Unsupported target "golang" with type "test" omitted
# Unsupported target "iter" with type "test" omitted
# Unsupported target "list" with type "test" omitted
# Unsupported target "matching" with type "example" omitted
# Unsupported target "mpsc" with type "test" omitted
# Unsupported target "never" with type "test" omitted
# Unsupported target "ready" with type "test" omitted
# Unsupported target "same_channel" with type "test" omitted
# Unsupported target "select" with type "test" omitted
# Unsupported target "select_macro" with type "test" omitted
# Unsupported target "stopwatch" with type "example" omitted
# Unsupported target "thread_locals" with type "test" omitted
# Unsupported target "tick" with type "test" omitted
# Unsupported target "zero" with type "test" omitted

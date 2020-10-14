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
    # Prefer access through "//bindgen/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "notice",  # MIT from expression "MIT"
])

# Generated targets
# Unsupported target "arithmetic" with type "bench" omitted
# Unsupported target "arithmetic" with type "test" omitted
# Unsupported target "arithmetic_ast" with type "test" omitted
# Unsupported target "blockbuf-arithmetic" with type "test" omitted
# Unsupported target "build-script-build" with type "custom-build" omitted
# Unsupported target "css" with type "test" omitted
# Unsupported target "custom_errors" with type "test" omitted
# Unsupported target "escaped" with type "test" omitted
# Unsupported target "float" with type "test" omitted
# Unsupported target "http" with type "bench" omitted
# Unsupported target "inference" with type "test" omitted
# Unsupported target "ini" with type "bench" omitted
# Unsupported target "ini" with type "test" omitted
# Unsupported target "ini_complete" with type "bench" omitted
# Unsupported target "ini_str" with type "bench" omitted
# Unsupported target "ini_str" with type "test" omitted
# Unsupported target "issues" with type "test" omitted
# Unsupported target "json" with type "bench" omitted
# Unsupported target "json" with type "example" omitted
# Unsupported target "json" with type "test" omitted
# Unsupported target "mp4" with type "test" omitted
# Unsupported target "multiline" with type "test" omitted
# Unsupported target "named_args" with type "test" omitted

# buildifier: leave-alone
rust_library(
    name = "nom",
    crate_type = "lib",
    deps = [
        "@rules_rust_bindgen__memchr__2_3_3//:memchr",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "5.1.2",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "alloc",
        "std",
    ],
)
# Unsupported target "overflow" with type "test" omitted
# Unsupported target "reborrow_fold" with type "test" omitted
# Unsupported target "s_expression" with type "example" omitted
# Unsupported target "string" with type "example" omitted
# Unsupported target "test1" with type "test" omitted

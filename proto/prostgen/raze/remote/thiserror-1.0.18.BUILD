"""
@generated
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""
package(default_visibility = [
  # Public for visibility by "@raze__crate__version//" targets.
  #
  # Prefer access through "//proto/prostgen/raze", which limits external
  # visibility to explicit Cargo.toml dependencies.
  "//visibility:public",
])

licenses([
  "notice", # MIT from expression "MIT OR Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)


# Unsupported target "compiletest" with type "test" omitted
# Unsupported target "test_deprecated" with type "test" omitted
# Unsupported target "test_display" with type "test" omitted
# Unsupported target "test_error" with type "test" omitted
# Unsupported target "test_expr" with type "test" omitted
# Unsupported target "test_from" with type "test" omitted
# Unsupported target "test_option" with type "test" omitted
# Unsupported target "test_path" with type "test" omitted
# Unsupported target "test_source" with type "test" omitted
# Unsupported target "test_transparent" with type "test" omitted

rust_library(
    name = "thiserror",
    crate_type = "lib",
    deps = [
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    proc_macro_deps = [
        "@raze__thiserror_impl__1_0_18//:thiserror_impl",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.0.18",
    tags = ["cargo-raze"],
    crate_features = [
    ],
)


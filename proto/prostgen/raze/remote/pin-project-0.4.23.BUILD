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
  "notice", # Apache-2.0 from expression "Apache-2.0 OR MIT"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)


# Unsupported target "cfg" with type "test" omitted
# Unsupported target "compiletest" with type "test" omitted
# Unsupported target "enum-default" with type "example" omitted
# Unsupported target "enum-default-expanded" with type "example" omitted
# Unsupported target "lint" with type "test" omitted
# Unsupported target "not_unpin" with type "example" omitted
# Unsupported target "not_unpin-expanded" with type "example" omitted

rust_library(
    name = "pin_project",
    crate_type = "lib",
    deps = [
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    proc_macro_deps = [
        "@raze__pin_project_internal__0_4_23//:pin_project_internal",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.4.23",
    tags = ["cargo-raze"],
    crate_features = [
    ],
)

# Unsupported target "pin_project" with type "test" omitted
# Unsupported target "pinned_drop" with type "example" omitted
# Unsupported target "pinned_drop" with type "test" omitted
# Unsupported target "pinned_drop-expanded" with type "example" omitted
# Unsupported target "project" with type "test" omitted
# Unsupported target "project_ref" with type "test" omitted
# Unsupported target "project_replace" with type "example" omitted
# Unsupported target "project_replace" with type "test" omitted
# Unsupported target "project_replace-expanded" with type "example" omitted
# Unsupported target "repr_packed" with type "test" omitted
# Unsupported target "sized" with type "test" omitted
# Unsupported target "struct-default" with type "example" omitted
# Unsupported target "struct-default-expanded" with type "example" omitted
# Unsupported target "unsafe_unpin" with type "example" omitted
# Unsupported target "unsafe_unpin" with type "test" omitted
# Unsupported target "unsafe_unpin-expanded" with type "example" omitted

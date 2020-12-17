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
  "notice", # MIT from expression "MIT"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)


# Unsupported target "event" with type "test" omitted
# Unsupported target "filter_caching_is_lexically_scoped" with type "test" omitted
# Unsupported target "filters_are_not_reevaluated_for_the_same_span" with type "test" omitted
# Unsupported target "filters_are_reevaluated_for_different_call_sites" with type "test" omitted
# Unsupported target "macro_imports" with type "test" omitted
# Unsupported target "macros" with type "test" omitted
# Unsupported target "max_level_hint" with type "test" omitted
# Unsupported target "multiple_max_level_hints" with type "test" omitted
# Unsupported target "no_subscriber" with type "bench" omitted
# Unsupported target "span" with type "test" omitted
# Unsupported target "subscriber" with type "bench" omitted
# Unsupported target "subscriber" with type "test" omitted

rust_library(
    name = "tracing",
    crate_type = "lib",
    deps = [
        "@raze__cfg_if__0_1_10//:cfg_if",
        "@raze__log__0_4_11//:log",
        "@raze__tracing_core__0_1_16//:tracing_core",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    proc_macro_deps = [
        "@raze__tracing_attributes__0_1_11//:tracing_attributes",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.1.19",
    tags = ["cargo-raze"],
    crate_features = [
        "attributes",
        "default",
        "log",
        "std",
        "tracing-attributes",
    ],
)


"""
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""
package(default_visibility = [
  # Public for visibility by "@raze__crate__version//" targets.
  #
  # Prefer access through "//bindgen/raze", which limits external
  # visibility to explicit Cargo.toml dependencies.
  "//visibility:public",
])

licenses([
  "notice", # "MIT,Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)


# Unsupported target "custom_default_format" with type "example" omitted
# Unsupported target "custom_format" with type "example" omitted
# Unsupported target "custom_logger" with type "example" omitted
# Unsupported target "default" with type "example" omitted
# Unsupported target "direct_logger" with type "example" omitted

rust_library(
    name = "env_logger",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2018",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__atty__0_2_14//:atty",
        "@raze__humantime__1_3_0//:humantime",
        "@raze__log__0_4_8//:log",
        "@raze__regex__1_3_9//:regex",
        "@raze__termcolor__1_1_0//:termcolor",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.7.1",
    crate_features = [
        "atty",
        "default",
        "humantime",
        "regex",
        "termcolor",
    ],
)

# Unsupported target "filters_from_code" with type "example" omitted
# Unsupported target "init-twice-retains-filter" with type "test" omitted
# Unsupported target "log-in-log" with type "test" omitted
# Unsupported target "log_tls_dtors" with type "test" omitted
# Unsupported target "regexp_filter" with type "test" omitted

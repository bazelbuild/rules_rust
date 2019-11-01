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

# Unsupported target "custom_default_format" with type "example" omitted
# Unsupported target "custom_format" with type "example" omitted
# Unsupported target "custom_logger" with type "example" omitted
# Unsupported target "default" with type "example" omitted
# Unsupported target "direct_logger" with type "example" omitted

rust_library(
    name = "env_logger",
    srcs = glob(["**/*.rs"]),
    crate_features = [
        "atty",
        "default",
        "humantime",
        "regex",
        "termcolor",
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.6.1",
    deps = [
        "@raze__atty__0_2_11//:atty",
        "@raze__humantime__1_2_0//:humantime",
        "@raze__log__0_4_6//:log",
        "@raze__regex__1_1_7//:regex",
        "@raze__termcolor__1_0_5//:termcolor",
    ],
)

# Unsupported target "init-twice-retains-filter" with type "test" omitted
# Unsupported target "log-in-log" with type "test" omitted
# Unsupported target "regexp_filter" with type "test" omitted

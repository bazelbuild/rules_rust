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

# Unsupported target "build-script-build" with type "custom-build" omitted
# Unsupported target "distributions" with type "bench" omitted
# Unsupported target "generators" with type "bench" omitted
# Unsupported target "misc" with type "bench" omitted
# Unsupported target "monte-carlo" with type "example" omitted
# Unsupported target "monty-hall" with type "example" omitted

rust_library(
    name = "rand",
    srcs = glob(["**/*.rs"]),
    crate_features = [
        "alloc",
        "default",
        "rand_core",
        "rand_jitter",
        "rand_os",
        "std",
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.6.5",
    deps = [
        "@raze__libc__0_2_58//:libc",
        "@raze__rand_chacha__0_1_1//:rand_chacha",
        "@raze__rand_core__0_4_0//:rand_core",
        "@raze__rand_hc__0_1_0//:rand_hc",
        "@raze__rand_isaac__0_1_1//:rand_isaac",
        "@raze__rand_jitter__0_1_4//:rand_jitter",
        "@raze__rand_os__0_1_3//:rand_os",
        "@raze__rand_pcg__0_1_2//:rand_pcg",
        "@raze__rand_xorshift__0_1_1//:rand_xorshift",
    ],
)

# Unsupported target "seq" with type "bench" omitted
# Unsupported target "uniformity" with type "test" omitted

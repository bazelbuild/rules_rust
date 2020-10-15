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
# Unsupported target "chrono" with type "bench" omitted

# buildifier: leave-alone
rust_library(
    name = "chrono",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__libc__0_2_79//:libc",
        "@rules_rust_wasm_bindgen__num_integer__0_1_43//:num_integer",
        "@rules_rust_wasm_bindgen__num_traits__0_2_12//:num_traits",
        "@rules_rust_wasm_bindgen__time__0_1_44//:time",
    ] + selects.with_or({
        # cfg(all(target_arch = "wasm32", not(any(target_os = "emscripten", target_os = "wasi"))))
        (
            "@io_bazel_rules_rust//rust/platform:wasm32-unknown-unknown",
        ): [
        ],
        "//conditions:default": [],
    }) + selects.with_or({
        # cfg(windows)
        (
            "@io_bazel_rules_rust//rust/platform:i686-pc-windows-gnu",
            "@io_bazel_rules_rust//rust/platform:x86_64-pc-windows-gnu",
        ): [
            "@rules_rust_wasm_bindgen__winapi__0_3_9//:winapi",
        ],
        "//conditions:default": [],
    }),
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.4.19",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "clock",
        "default",
        "libc",
        "oldtime",
        "std",
        "time",
        "winapi",
    ],
    aliases = {
    },
)
# Unsupported target "serde" with type "bench" omitted
# Unsupported target "wasm" with type "test" omitted

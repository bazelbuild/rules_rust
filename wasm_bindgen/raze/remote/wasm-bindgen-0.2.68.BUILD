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
# buildifier: disable=load-on-top
load(
    "@io_bazel_rules_rust//cargo:cargo_build_script.bzl",
    "cargo_build_script",
)

# buildifier: leave-alone
cargo_build_script(
    name = "wasm_bindgen_build_script",
    srcs = glob(["**/*.rs"]),
    crate_root = "build.rs",
    edition = "2018",
    deps = [
    ] + selects.with_or({
        # cfg(target_arch = "wasm32")
        (
            "@io_bazel_rules_rust//rust/platform:wasm32-unknown-unknown",
        ): [
        ],
        "//conditions:default": [],
    }),
    rustc_flags = [
        "--cap-lints=allow",
    ],
    crate_features = [
      "default",
      "spans",
      "std",
    ],
    build_script_env = {
    },
    data = glob(["**"]),
    tags = [
        "cargo-raze",
        "manual",
    ],
    version = "0.2.68",
    visibility = ["//visibility:private"],
)

# Unsupported target "headless" with type "test" omitted
# Unsupported target "must_use" with type "test" omitted
# Unsupported target "non_wasm" with type "test" omitted
# Unsupported target "std-crate-no-std-dep" with type "test" omitted
# Unsupported target "unwrap_throw" with type "test" omitted
# Unsupported target "wasm" with type "test" omitted

# buildifier: leave-alone
rust_library(
    name = "wasm_bindgen",
    crate_type = "lib",
    deps = [
        ":wasm_bindgen_build_script",
        "@rules_rust_wasm_bindgen__cfg_if__0_1_10//:cfg_if",
    ] + selects.with_or({
        # cfg(target_arch = "wasm32")
        (
            "@io_bazel_rules_rust//rust/platform:wasm32-unknown-unknown",
        ): [
        ],
        "//conditions:default": [],
    }),
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    proc_macro_deps = [
        "@rules_rust_wasm_bindgen__wasm_bindgen_macro__0_2_68//:wasm_bindgen_macro",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.2.68",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "default",
        "spans",
        "std",
    ],
    aliases = {
    },
)

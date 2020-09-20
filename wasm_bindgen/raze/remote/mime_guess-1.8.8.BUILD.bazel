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
    "notice",  # MIT from expression "MIT"
])

# Generated targets
# buildifier: disable=load-on-top
load(
    "@io_bazel_rules_rust//cargo:cargo_build_script.bzl",
    "cargo_build_script",
)

# buildifier: leave-alone
cargo_build_script(
    name = "mime_guess_build_script",
    srcs = glob(["**/*.rs"]),
    crate_root = "build.rs",
    edition = "2015",
    deps = [
        "@rules_rust_wasm_bindgen__phf__0_7_24//:phf",
        "@rules_rust_wasm_bindgen__phf_codegen__0_7_24//:phf_codegen",
        "@rules_rust_wasm_bindgen__unicase__1_4_2//:unicase",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    crate_features = [
    ],
    build_script_env = {
    },
    data = glob(["**"]),
    tags = [
        "cargo-raze",
        "manual",
    ],
    version = "1.8.8",
    visibility = ["//visibility:private"],
)


# buildifier: leave-alone
rust_library(
    name = "mime_guess",
    crate_type = "lib",
    deps = [
        ":mime_guess_build_script",
        "@rules_rust_wasm_bindgen__mime__0_2_6//:mime",
        "@rules_rust_wasm_bindgen__phf__0_7_24//:phf",
        "@rules_rust_wasm_bindgen__unicase__1_4_2//:unicase",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.8.8",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
    ],
)
# Unsupported target "rev_map" with type "example" omitted

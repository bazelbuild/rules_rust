load("@io_bazel_rules_rust//wasm_bindgen:wasm_bindgen.bzl", "rust_wasm_bindgen_toolchain")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

toolchain_type(name = "wasm_bindgen_toolchain")

bzl_library(
    name = "rules",
    srcs = glob(["**/*.bzl"]),
    deps = ["@io_bazel_rules_rust//rust:rules"],
)

rust_wasm_bindgen_toolchain(
    name = "default_wasm_bindgen_toolchain_impl",
    bindgen = "//wasm_bindgen/raze:cargo_bin_wasm_bindgen",
)

toolchain(
    name = "default_wasm_bindgen_toolchain",
    toolchain = "default_wasm_bindgen_toolchain_impl",
    toolchain_type = "@io_bazel_rules_rust//wasm_bindgen:wasm_bindgen_toolchain",
)

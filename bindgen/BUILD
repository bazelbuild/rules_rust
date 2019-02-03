load("@io_bazel_rules_rust//bindgen:bindgen.bzl", "rust_bindgen_toolchain")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

toolchain_type(name = "bindgen_toolchain")

bzl_library(
    name = "rules",
    srcs = glob(["**/*.bzl"]),
    deps = ["@io_bazel_rules_rust//rust:rules"],
)

rust_bindgen_toolchain(
    name = "example-bindgen-toolchain-impl",
    bindgen = "//bindgen/raze:cargo_bin_bindgen",
    clang = "@bindgen_clang//:clang",
    libclang = "@bindgen_clang//:libclang.so",
    libstdcxx = "@local_libstdcpp//:libstdc++",
)

toolchain(
    name = "example-bindgen-toolchain",
    toolchain = "example-bindgen-toolchain-impl",
    toolchain_type = "@io_bazel_rules_rust//bindgen:bindgen_toolchain",
)

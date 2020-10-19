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
    name = "default_bindgen_toolchain_impl",
    bindgen = "//bindgen/raze:cargo_bin_bindgen",
    clang = select({
        "@io_bazel_rules_rust//rust/platform:osx": "@bindgen_clang_osx//:clang",
        "//conditions:default": "@bindgen_clang_linux//:clang",
    }),
    libclang = select({
        "@io_bazel_rules_rust//rust/platform:osx": "@bindgen_clang_osx//:libclang.so",
        "//conditions:default": "@bindgen_clang_linux//:libclang.so",
    }),
    libstdcxx = "@local_libstdcpp//:libstdc++",
)

toolchain(
    name = "default_bindgen_toolchain",
    toolchain = "default_bindgen_toolchain_impl",
    toolchain_type = "@io_bazel_rules_rust//bindgen:bindgen_toolchain",
)

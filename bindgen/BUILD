load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("//bindgen:bindgen.bzl", "rust_bindgen_toolchain")

package(default_visibility = ["//visibility:public"])

toolchain_type(name = "bindgen_toolchain")

bzl_library(
    name = "rules",
    srcs = glob(["**/*.bzl"]) + ["//bindgen/raze:crates.bzl"],
    deps = ["//rust:rules"],
)

rust_bindgen_toolchain(
    name = "default_bindgen_toolchain_impl",
    bindgen = "//bindgen/raze:cargo_bin_bindgen",
    clang = select({
        "//rust/platform:osx": "@bindgen_clang_osx//:clang",
        "//conditions:default": "@bindgen_clang_linux//:clang",
    }),
    libclang = select({
        "//rust/platform:osx": "@bindgen_clang_osx//:libclang.so",
        "//conditions:default": "@bindgen_clang_linux//:libclang.so",
    }),
    libstdcxx = "@local_libstdcpp//:libstdc++",
)

toolchain(
    name = "default_bindgen_toolchain",
    toolchain = "default_bindgen_toolchain_impl",
    toolchain_type = "//bindgen:bindgen_toolchain",
)

load("@io_bazel_rules_rust//bindgen:bindgen.bzl", "rust_bindgen_toolchain")

package(default_visibility = ["//visibility:public"])

toolchain_type(name = "bindgen_toolchain")

rust_bindgen_toolchain(
    name = "example-bindgen-toolchain-impl",
    bindgen = "//bindgen/raze:cargo_bin_bindgen",
    clang = "@clang//:clang",
    libclang = "@clang//:libclang.so",
    libstdcxx = "@local_linux//:libstdc++",
    rustfmt = "@local_cargo//:rustfmt",
)

toolchain(
    name = "example-bindgen-toolchain",
    toolchain = "example-bindgen-toolchain-impl",
    toolchain_type = "@io_bazel_rules_rust//bindgen:bindgen_toolchain",
)

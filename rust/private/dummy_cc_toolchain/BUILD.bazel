load(":dummy_cc_toolchain.bzl", "dummy_cc_toolchain")

dummy_cc_toolchain(name = "dummy_cc_wasm32")

# When compiling Rust code for wasm32, we avoid linking to cpp code so we introduce a dummy cc
# toolchain since we know we'll never look it up.
# TODO(jedmonds@spotify.com): Need to support linking C code to rust code when compiling for wasm32.
toolchain(
    name = "dummy_cc_wasm32_toolchain",
    target_compatible_with = ["//rust/platform/cpu:wasm32"],
    toolchain = ":dummy_cc_wasm32",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

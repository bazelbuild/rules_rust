"""
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""
package(default_visibility = [
  # Public for visibility by "@raze__crate__version//" targets.
  #
  # Prefer access through "//bindgen/raze", which limits external
  # visibility to explicit Cargo.toml dependencies.
  "//visibility:public",
])

licenses([
  "notice", # "Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)

rust_binary(
    name = "clang_sys_build_script",
    srcs = glob(["**/*.rs"]),
    crate_root = "build.rs",
    edition = "2015",
    deps = [
        "@raze__glob__0_3_0//:glob",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    crate_features = [
      "clang_6_0",
      "gte_clang_3_6",
      "gte_clang_3_7",
      "gte_clang_3_8",
      "gte_clang_3_9",
      "gte_clang_4_0",
      "gte_clang_5_0",
      "gte_clang_6_0",
      "libloading",
      "runtime",
    ],
    data = glob(["*"]),
    version = "0.29.3",
    visibility = ["//visibility:private"],
)

genrule(
    name = "clang_sys_build_script_executor",
    srcs = glob(["*", "**/*.rs"]),
    outs = ["clang_sys_out_dir_outputs.tar.gz"],
    tools = [
      ":clang_sys_build_script",
    ],
    tags = ["no-sandbox"],
    cmd = "mkdir -p $$(dirname $@)/clang_sys_out_dir_outputs/;"
        + " (export CARGO_MANIFEST_DIR=\"$$PWD/$$(dirname $(location :Cargo.toml))\";"
        # TODO(acmcarther): This needs to be revisited as part of the cross compilation story.
        #                   See also: https://github.com/google/cargo-raze/pull/54
        + " export TARGET='x86_64-unknown-linux-gnu';"
        + " export RUST_BACKTRACE=1;"
        + " export CARGO_FEATURE_CLANG_6_0=1;"
        + " export CARGO_FEATURE_GTE_CLANG_3_6=1;"
        + " export CARGO_FEATURE_GTE_CLANG_3_7=1;"
        + " export CARGO_FEATURE_GTE_CLANG_3_8=1;"
        + " export CARGO_FEATURE_GTE_CLANG_3_9=1;"
        + " export CARGO_FEATURE_GTE_CLANG_4_0=1;"
        + " export CARGO_FEATURE_GTE_CLANG_5_0=1;"
        + " export CARGO_FEATURE_GTE_CLANG_6_0=1;"
        + " export CARGO_FEATURE_LIBLOADING=1;"
        + " export CARGO_FEATURE_RUNTIME=1;"
        + " export OUT_DIR=$$PWD/$$(dirname $@)/clang_sys_out_dir_outputs;"
        + " export BINARY_PATH=\"$$PWD/$(location :clang_sys_build_script)\";"
        + " export OUT_TAR=$$PWD/$@;"
        + " cd $$(dirname $(location :Cargo.toml)) && $$BINARY_PATH && tar -czf $$OUT_TAR -C $$OUT_DIR .)"
)


rust_library(
    name = "clang_sys",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__glob__0_3_0//:glob",
        "@raze__libc__0_2_71//:libc",
        "@raze__libloading__0_5_2//:libloading",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    out_dir_tar = ":clang_sys_build_script_executor",
    version = "0.29.3",
    crate_features = [
        "clang_6_0",
        "gte_clang_3_6",
        "gte_clang_3_7",
        "gte_clang_3_8",
        "gte_clang_3_9",
        "gte_clang_4_0",
        "gte_clang_5_0",
        "gte_clang_6_0",
        "libloading",
        "runtime",
    ],
)

# Unsupported target "lib" with type "test" omitted

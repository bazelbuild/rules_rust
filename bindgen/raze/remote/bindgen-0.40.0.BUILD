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
  "notice", # "BSD-3-Clause"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)

rust_binary(
    name = "bindgen_build_script",
    srcs = glob(["**/*.rs"]),
    crate_root = "build.rs",
    edition = "2015",
    deps = [
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    crate_features = [
      "default",
      "env_logger",
      "log",
      "logging",
    ],
    data = glob(["*"]),
    version = "0.40.0",
    visibility = ["//visibility:private"],
)

genrule(
    name = "bindgen_build_script_executor",
    srcs = glob(["*", "**/*.rs"]),
    outs = ["bindgen_out_dir_outputs.tar.gz"],
    tools = [
      ":bindgen_build_script",
    ],
    local = 1,
    cmd = "mkdir -p bindgen_out_dir_outputs/;"
        + " (export CARGO_MANIFEST_DIR=\"$$PWD/$$(dirname $(location :Cargo.toml))\";"
        # TODO(acmcarther): This needs to be revisited as part of the cross compilation story.
        #                   See also: https://github.com/google/cargo-raze/pull/54
        + " export TARGET='x86_64-unknown-linux-gnu';"
        + " export RUST_BACKTRACE=1;"
        + " export CARGO_FEATURE_DEFAULT=1;"
        + " export CARGO_FEATURE_ENV_LOGGER=1;"
        + " export CARGO_FEATURE_LOG=1;"
        + " export CARGO_FEATURE_LOGGING=1;"
        + " export OUT_DIR=$$PWD/bindgen_out_dir_outputs;"
        + " export BINARY_PATH=\"$$PWD/$(location :bindgen_build_script)\";"
        + " export OUT_TAR=$$PWD/$@;"
        + " cd $$(dirname $(location :Cargo.toml)) && $$BINARY_PATH && tar -czf $$OUT_TAR -C $$OUT_DIR .)"
)

rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_bindgen",
    crate_root = "src/main.rs",
    edition = "2015",
    srcs = glob(["**/*.rs"]),
    deps = [
        # Binaries get an implicit dependency on their lib
        ":bindgen",
        "@raze__bitflags__1_0_4//:bitflags",
        "@raze__cexpr__0_2_3//:cexpr",
        "@raze__cfg_if__0_1_6//:cfg_if",
        "@raze__clang_sys__0_23_0//:clang_sys",
        "@raze__clap__2_32_0//:clap",
        "@raze__env_logger__0_5_13//:env_logger",
        "@raze__lazy_static__1_2_0//:lazy_static",
        "@raze__log__0_4_6//:log",
        "@raze__peeking_take_while__0_1_2//:peeking_take_while",
        "@raze__proc_macro2__0_3_5//:proc_macro2",
        "@raze__quote__0_5_2//:quote",
        "@raze__regex__1_1_0//:regex",
        "@raze__which__1_0_5//:which",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    out_dir_tar = ":bindgen_build_script_executor",
    version = "0.40.0",
    crate_features = [
        "default",
        "env_logger",
        "log",
        "logging",
    ],
)


rust_library(
    name = "bindgen",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__bitflags__1_0_4//:bitflags",
        "@raze__cexpr__0_2_3//:cexpr",
        "@raze__cfg_if__0_1_6//:cfg_if",
        "@raze__clang_sys__0_23_0//:clang_sys",
        "@raze__clap__2_32_0//:clap",
        "@raze__env_logger__0_5_13//:env_logger",
        "@raze__lazy_static__1_2_0//:lazy_static",
        "@raze__log__0_4_6//:log",
        "@raze__peeking_take_while__0_1_2//:peeking_take_while",
        "@raze__proc_macro2__0_3_5//:proc_macro2",
        "@raze__quote__0_5_2//:quote",
        "@raze__regex__1_1_0//:regex",
        "@raze__which__1_0_5//:which",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    out_dir_tar = ":bindgen_build_script_executor",
    version = "0.40.0",
    crate_features = [
        "default",
        "env_logger",
        "log",
        "logging",
    ],
)


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
    edition = "2018",
    deps = [
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    crate_features = [
      "clap",
      "default",
      "env_logger",
      "log",
      "logging",
      "runtime",
      "which",
      "which-rustfmt",
    ],
    data = glob(["*"]),
    version = "0.54.0",
    visibility = ["//visibility:private"],
)

genrule(
    name = "bindgen_build_script_executor",
    srcs = glob(["*", "**/*.rs"]),
    outs = ["bindgen_out_dir_outputs.tar.gz"],
    tools = [
      ":bindgen_build_script",
    ],
    tags = ["no-sandbox"],
    cmd = "mkdir -p $$(dirname $@)/bindgen_out_dir_outputs/;"
        + " (export CARGO_MANIFEST_DIR=\"$$PWD/$$(dirname $(location :Cargo.toml))\";"
        # TODO(acmcarther): This needs to be revisited as part of the cross compilation story.
        #                   See also: https://github.com/google/cargo-raze/pull/54
        + " export TARGET='x86_64-unknown-linux-gnu';"
        + " export RUST_BACKTRACE=1;"
        + " export CARGO_FEATURE_CLAP=1;"
        + " export CARGO_FEATURE_DEFAULT=1;"
        + " export CARGO_FEATURE_ENV_LOGGER=1;"
        + " export CARGO_FEATURE_LOG=1;"
        + " export CARGO_FEATURE_LOGGING=1;"
        + " export CARGO_FEATURE_RUNTIME=1;"
        + " export CARGO_FEATURE_WHICH=1;"
        + " export CARGO_FEATURE_WHICH_RUSTFMT=1;"
        + " export OUT_DIR=$$PWD/$$(dirname $@)/bindgen_out_dir_outputs;"
        + " export BINARY_PATH=\"$$PWD/$(location :bindgen_build_script)\";"
        + " export OUT_TAR=$$PWD/$@;"
        + " cd $$(dirname $(location :Cargo.toml)) && $$BINARY_PATH && tar -czf $$OUT_TAR -C $$OUT_DIR .)"
)

rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_bindgen",
    crate_root = "src/main.rs",
    edition = "2018",
    srcs = glob(["**/*.rs"]),
    deps = [
        # Binaries get an implicit dependency on their crate's lib
        ":bindgen",
        "@raze__bitflags__1_2_1//:bitflags",
        "@raze__cexpr__0_4_0//:cexpr",
        "@raze__cfg_if__0_1_10//:cfg_if",
        "@raze__clang_sys__0_29_3//:clang_sys",
        "@raze__clap__2_33_1//:clap",
        "@raze__env_logger__0_7_1//:env_logger",
        "@raze__lazy_static__1_4_0//:lazy_static",
        "@raze__lazycell__1_2_1//:lazycell",
        "@raze__log__0_4_8//:log",
        "@raze__peeking_take_while__0_1_2//:peeking_take_while",
        "@raze__proc_macro2__1_0_18//:proc_macro2",
        "@raze__quote__1_0_6//:quote",
        "@raze__regex__1_3_9//:regex",
        "@raze__rustc_hash__1_1_0//:rustc_hash",
        "@raze__shlex__0_1_1//:shlex",
        "@raze__which__3_1_1//:which",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    out_dir_tar = ":bindgen_build_script_executor",
    version = "0.54.0",
    crate_features = [
        "clap",
        "default",
        "env_logger",
        "log",
        "logging",
        "runtime",
        "which",
        "which-rustfmt",
    ],
)


rust_library(
    name = "bindgen",
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2018",
    srcs = glob(["**/*.rs"]),
    deps = [
        "@raze__bitflags__1_2_1//:bitflags",
        "@raze__cexpr__0_4_0//:cexpr",
        "@raze__cfg_if__0_1_10//:cfg_if",
        "@raze__clang_sys__0_29_3//:clang_sys",
        "@raze__clap__2_33_1//:clap",
        "@raze__env_logger__0_7_1//:env_logger",
        "@raze__lazy_static__1_4_0//:lazy_static",
        "@raze__lazycell__1_2_1//:lazycell",
        "@raze__log__0_4_8//:log",
        "@raze__peeking_take_while__0_1_2//:peeking_take_while",
        "@raze__proc_macro2__1_0_18//:proc_macro2",
        "@raze__quote__1_0_6//:quote",
        "@raze__regex__1_3_9//:regex",
        "@raze__rustc_hash__1_1_0//:rustc_hash",
        "@raze__shlex__0_1_1//:shlex",
        "@raze__which__3_1_1//:which",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    out_dir_tar = ":bindgen_build_script_executor",
    version = "0.54.0",
    crate_features = [
        "clap",
        "default",
        "env_logger",
        "log",
        "logging",
        "runtime",
        "which",
        "which-rustfmt",
    ],
)


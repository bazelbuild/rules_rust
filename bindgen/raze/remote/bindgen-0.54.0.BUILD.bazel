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
    # Prefer access through "//bindgen/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "notice",  # BSD-3-Clause from expression "BSD-3-Clause"
])

# Generated targets
# buildifier: disable=load-on-top
load(
    "@io_bazel_rules_rust//cargo:cargo_build_script.bzl",
    "cargo_build_script",
)

# buildifier: leave-alone
cargo_build_script(
    name = "bindgen_build_script",
    srcs = glob(["**/*.rs"]),
    crate_root = "build.rs",
    edition = "2018",
    deps = [
        "@rules_rust_bindgen__clang_sys__0_29_3//:clang_sys",
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
    build_script_env = {
    },
    data = glob(["**"]),
    tags = [
        "cargo-raze",
        "manual",
    ],
    version = "0.54.0",
    visibility = ["//visibility:private"],
)


# buildifier: leave-alone
rust_binary(
    # Prefix bin name to disambiguate from (probable) collision with lib name
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_bindgen",
    deps = [
        # Binaries get an implicit dependency on their crate's lib
        ":bindgen",
        ":bindgen_build_script",
        "@rules_rust_bindgen__bitflags__1_2_1//:bitflags",
        "@rules_rust_bindgen__cexpr__0_4_0//:cexpr",
        "@rules_rust_bindgen__cfg_if__0_1_10//:cfg_if",
        "@rules_rust_bindgen__clang_sys__0_29_3//:clang_sys",
        "@rules_rust_bindgen__clap__2_33_3//:clap",
        "@rules_rust_bindgen__env_logger__0_7_1//:env_logger",
        "@rules_rust_bindgen__lazy_static__1_4_0//:lazy_static",
        "@rules_rust_bindgen__lazycell__1_3_0//:lazycell",
        "@rules_rust_bindgen__log__0_4_11//:log",
        "@rules_rust_bindgen__peeking_take_while__0_1_2//:peeking_take_while",
        "@rules_rust_bindgen__proc_macro2__1_0_21//:proc_macro2",
        "@rules_rust_bindgen__quote__1_0_7//:quote",
        "@rules_rust_bindgen__regex__1_3_9//:regex",
        "@rules_rust_bindgen__rustc_hash__1_1_0//:rustc_hash",
        "@rules_rust_bindgen__shlex__0_1_1//:shlex",
        "@rules_rust_bindgen__which__3_1_1//:which",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/main.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.54.0",
    tags = [
        "cargo-raze",
        "manual",
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
)

# buildifier: leave-alone
rust_library(
    name = "bindgen",
    crate_type = "lib",
    deps = [
        ":bindgen_build_script",
        "@rules_rust_bindgen__bitflags__1_2_1//:bitflags",
        "@rules_rust_bindgen__cexpr__0_4_0//:cexpr",
        "@rules_rust_bindgen__cfg_if__0_1_10//:cfg_if",
        "@rules_rust_bindgen__clang_sys__0_29_3//:clang_sys",
        "@rules_rust_bindgen__clap__2_33_3//:clap",
        "@rules_rust_bindgen__env_logger__0_7_1//:env_logger",
        "@rules_rust_bindgen__lazy_static__1_4_0//:lazy_static",
        "@rules_rust_bindgen__lazycell__1_3_0//:lazycell",
        "@rules_rust_bindgen__log__0_4_11//:log",
        "@rules_rust_bindgen__peeking_take_while__0_1_2//:peeking_take_while",
        "@rules_rust_bindgen__proc_macro2__1_0_21//:proc_macro2",
        "@rules_rust_bindgen__quote__1_0_7//:quote",
        "@rules_rust_bindgen__regex__1_3_9//:regex",
        "@rules_rust_bindgen__rustc_hash__1_1_0//:rustc_hash",
        "@rules_rust_bindgen__shlex__0_1_1//:shlex",
        "@rules_rust_bindgen__which__3_1_1//:which",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.54.0",
    tags = [
        "cargo-raze",
        "manual",
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
)

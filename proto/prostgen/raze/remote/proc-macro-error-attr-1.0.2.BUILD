"""
@generated
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""
package(default_visibility = [
  # Public for visibility by "@raze__crate__version//" targets.
  #
  # Prefer access through "//proto/prostgen/raze", which limits external
  # visibility to explicit Cargo.toml dependencies.
  "//visibility:public",
])

licenses([
  "notice", # MIT from expression "MIT OR Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_library",
    "rust_binary",
    "rust_test",
)

load(
    "@io_bazel_rules_rust//cargo:cargo_build_script.bzl",
    "cargo_build_script",
)

cargo_build_script(
    name = "proc_macro_error_attr_build_script",
    srcs = glob(["**/*.rs"]),
    crate_root = "build.rs",
    edition = "2018",
    deps = [
        "@raze__version_check__0_9_2//:version_check",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    crate_features = [
    ],
    build_script_env = {
    },
    data = glob(["**"]),
    tags = ["cargo-raze"],
    version = "1.0.2",
    visibility = ["//visibility:private"],
)


rust_library(
    name = "proc_macro_error_attr",
    crate_type = "proc-macro",
    deps = [
        ":proc_macro_error_attr_build_script",
        "@raze__proc_macro2__1_0_18//:proc_macro2",
        "@raze__quote__1_0_7//:quote",
        "@raze__syn__1_0_31//:syn",
        "@raze__syn_mid__0_5_0//:syn_mid",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2018",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.0.2",
    tags = ["cargo-raze"],
    crate_features = [
    ],
)


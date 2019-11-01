"""
cargo-raze crate build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

package(default_visibility = [
    # Public for visibility by "@raze__crate__version//" targets.
    #
    # Prefer access through "//wasm_bindgen/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "notice",  # "MIT"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

rust_binary(
    name = "mime_guess_build_script",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "build.rs",
    data = glob(["*"]),
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.8.7",
    visibility = ["//visibility:private"],
    deps = [
        "@raze__phf_codegen__0_7_24//:phf_codegen",
        "@raze__unicase__1_4_2//:unicase",
    ],
)

genrule(
    name = "mime_guess_build_script_executor",
    srcs = glob([
        "*",
        "**/*.rs",
    ]),
    outs = ["mime_guess_out_dir_outputs.tar.gz"],
    cmd = "mkdir -p $$(dirname $@)/mime_guess_out_dir_outputs/;" +
          " (export CARGO_MANIFEST_DIR=\"$$PWD/$$(dirname $(location :Cargo.toml))\";" +
          # TODO(acmcarther): This needs to be revisited as part of the cross compilation story.
          #                   See also: https://github.com/google/cargo-raze/pull/54
          " export TARGET='x86_64-unknown-linux-gnu';" +
          " export RUST_BACKTRACE=1;" +
          " export OUT_DIR=$$PWD/$$(dirname $@)/mime_guess_out_dir_outputs;" +
          " export BINARY_PATH=\"$$PWD/$(location :mime_guess_build_script)\";" +
          " export OUT_TAR=$$PWD/$@;" +
          " cd $$(dirname $(location :Cargo.toml)) && $$BINARY_PATH && tar -czf $$OUT_TAR -C $$OUT_DIR .)",
    tags = ["no-sandbox"],
    tools = [
        ":mime_guess_build_script",
    ],
)

rust_library(
    name = "mime_guess",
    srcs = glob(["**/*.rs"]),
    crate_features = [
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    out_dir_tar = ":mime_guess_build_script_executor",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.8.7",
    deps = [
        "@raze__mime__0_2_6//:mime",
        "@raze__phf__0_7_24//:phf",
        "@raze__unicase__1_4_2//:unicase",
    ],
)

# Unsupported target "rev_map" with type "example" omitted

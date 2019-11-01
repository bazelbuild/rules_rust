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
    "restricted",  # "MIT OR Apache-2.0"
])

load(
    "@io_bazel_rules_rust//rust:rust.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
)

rust_binary(
    name = "syn_build_script",
    srcs = glob(["**/*.rs"]),
    crate_features = [
        "clone-impls",
        "default",
        "derive",
        "extra-traits",
        "full",
        "parsing",
        "printing",
        "proc-macro",
        "proc-macro2",
        "quote",
        "visit",
    ],
    crate_root = "build.rs",
    data = glob(["*"]),
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.15.43",
    visibility = ["//visibility:private"],
    deps = [
    ],
)

genrule(
    name = "syn_build_script_executor",
    srcs = glob([
        "*",
        "**/*.rs",
    ]),
    outs = ["syn_out_dir_outputs.tar.gz"],
    cmd = "mkdir -p $$(dirname $@)/syn_out_dir_outputs/;" +
          " (export CARGO_MANIFEST_DIR=\"$$PWD/$$(dirname $(location :Cargo.toml))\";" +
          # TODO(acmcarther): This needs to be revisited as part of the cross compilation story.
          #                   See also: https://github.com/google/cargo-raze/pull/54
          " export TARGET='x86_64-unknown-linux-gnu';" +
          " export RUST_BACKTRACE=1;" +
          " export CARGO_FEATURE_CLONE_IMPLS=1;" +
          " export CARGO_FEATURE_DEFAULT=1;" +
          " export CARGO_FEATURE_DERIVE=1;" +
          " export CARGO_FEATURE_EXTRA_TRAITS=1;" +
          " export CARGO_FEATURE_FULL=1;" +
          " export CARGO_FEATURE_PARSING=1;" +
          " export CARGO_FEATURE_PRINTING=1;" +
          " export CARGO_FEATURE_PROC_MACRO=1;" +
          " export CARGO_FEATURE_PROC_MACRO2=1;" +
          " export CARGO_FEATURE_QUOTE=1;" +
          " export CARGO_FEATURE_VISIT=1;" +
          " export OUT_DIR=$$PWD/$$(dirname $@)/syn_out_dir_outputs;" +
          " export BINARY_PATH=\"$$PWD/$(location :syn_build_script)\";" +
          " export OUT_TAR=$$PWD/$@;" +
          " cd $$(dirname $(location :Cargo.toml)) && $$BINARY_PATH && tar -czf $$OUT_TAR -C $$OUT_DIR .)",
    tags = ["no-sandbox"],
    tools = [
        ":syn_build_script",
    ],
)

rust_library(
    name = "syn",
    srcs = glob(["**/*.rs"]),
    crate_features = [
        "clone-impls",
        "default",
        "derive",
        "extra-traits",
        "full",
        "parsing",
        "printing",
        "proc-macro",
        "proc-macro2",
        "quote",
        "visit",
    ],
    crate_root = "src/lib.rs",
    crate_type = "lib",
    edition = "2015",
    out_dir_tar = ":syn_build_script_executor",
    rustc_flags = [
        "--cap-lints=allow",
        "--cfg=syn_can_call_macro_by_path",
    ],
    version = "0.15.43",
    deps = [
        "@raze__proc_macro2__0_4_30//:proc_macro2",
        "@raze__quote__0_6_12//:quote",
        "@raze__unicode_xid__0_1_0//:unicode_xid",
    ],
)

# Unsupported target "test_asyncness" with type "test" omitted
# Unsupported target "test_attribute" with type "test" omitted
# Unsupported target "test_derive_input" with type "test" omitted
# Unsupported target "test_expr" with type "test" omitted
# Unsupported target "test_generics" with type "test" omitted
# Unsupported target "test_grouping" with type "test" omitted
# Unsupported target "test_ident" with type "test" omitted
# Unsupported target "test_lit" with type "test" omitted
# Unsupported target "test_meta" with type "test" omitted
# Unsupported target "test_parse_buffer" with type "test" omitted
# Unsupported target "test_pat" with type "test" omitted
# Unsupported target "test_precedence" with type "test" omitted
# Unsupported target "test_round_trip" with type "test" omitted
# Unsupported target "test_should_parse" with type "test" omitted
# Unsupported target "test_token_trees" with type "test" omitted
# Unsupported target "zzz_stable" with type "test" omitted

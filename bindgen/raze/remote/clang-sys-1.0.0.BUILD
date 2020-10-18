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
    "notice",  # Apache-2.0 from expression "Apache-2.0"
])

# Generated targets
# buildifier: disable=load-on-top
load(
    "@io_bazel_rules_rust//cargo:cargo_build_script.bzl",
    "cargo_build_script",
)

# buildifier: leave-alone
cargo_build_script(
    name = "clang_sys_build_script",
    srcs = glob(["**/*.rs"]),
    crate_root = "build.rs",
    edition = "2015",
    deps = [
        "@rules_rust_bindgen__glob__0_3_0//:glob",
    ],
    rustc_flags = [
        "--cap-lints=allow",
    ],
    crate_features = [
      "clang_3_5",
      "clang_3_6",
      "clang_3_7",
      "clang_3_8",
      "clang_3_9",
      "clang_4_0",
      "clang_5_0",
      "clang_6_0",
      "libloading",
      "runtime",
    ],
    build_script_env = {
    },
    data = glob(["**"]),
    tags = [
        "cargo-raze",
        "manual",
    ],
    version = "1.0.0",
    visibility = ["//visibility:private"],
)


# buildifier: leave-alone
rust_library(
    name = "clang_sys",
    crate_type = "lib",
    deps = [
        ":clang_sys_build_script",
        "@rules_rust_bindgen__glob__0_3_0//:glob",
        "@rules_rust_bindgen__libc__0_2_77//:libc",
        "@rules_rust_bindgen__libloading__0_6_3//:libloading",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "1.0.0",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "clang_3_5",
        "clang_3_6",
        "clang_3_7",
        "clang_3_8",
        "clang_3_9",
        "clang_4_0",
        "clang_5_0",
        "clang_6_0",
        "libloading",
        "runtime",
    ],
)
# Unsupported target "lib" with type "test" omitted

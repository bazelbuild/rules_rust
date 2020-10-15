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
    # Prefer access through "//wasm_bindgen/raze", which limits external
    # visibility to explicit Cargo.toml dependencies.
    "//visibility:public",
])

licenses([
    "notice",  # MIT from expression "MIT"
])

# Generated targets

# buildifier: leave-alone
rust_library(
    name = "redox_users",
    crate_type = "lib",
    deps = [
        "@rules_rust_wasm_bindgen__getrandom__0_1_15//:getrandom",
        "@rules_rust_wasm_bindgen__redox_syscall__0_1_57//:redox_syscall",
        "@rules_rust_wasm_bindgen__rust_argon2__0_8_2//:rust_argon2",
    ],
    srcs = glob(["**/*.rs"]),
    crate_root = "src/lib.rs",
    edition = "2015",
    rustc_flags = [
        "--cap-lints=allow",
    ],
    version = "0.3.5",
    tags = [
        "cargo-raze",
        "manual",
    ],
    crate_features = [
        "auth",
        "default",
        "rust-argon2",
    ],
)

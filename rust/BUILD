package(default_visibility = ["//visibility:public"])

load(":triple_mappings.bzl", "define_platforms", "SUPPORTED_TRIPLES")

exports_files([
    "rust.bzl",
    "toolchain.bzl",
    "repositories.bzl",
])

constraint_setting(name = "rust_abi")

constraint_value(
    name = "gnu",
    constraint_setting = ":rust_abi",
)

constraint_value(
    name = "msvc",
    constraint_setting = ":rust_abi",
)

constraint_value(
    name = "musl",
    constraint_setting = ":rust_abi",
)

define_platforms(CONFIGURED_TRIPLES)

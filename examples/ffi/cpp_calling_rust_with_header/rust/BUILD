load("@rules_cc//cc:defs.bzl", "cc_import")
load("@rules_rust//rust:defs.bzl", "rust_static_library")

rust_static_library(
    name = "librusty",
    srcs = ["librusty.rs"],
    crate_name = "rusty",
    visibility = ["//visibility:public"],
)

cc_import(
    name = "librusty_for_cc",
    hdrs = ["rusty.h"],
    includes = [package_name()],
    static_library = ":librusty",
    visibility = ["//visibility:public"],
)

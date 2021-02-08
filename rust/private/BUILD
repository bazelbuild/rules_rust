load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

exports_files(["test_runner_template.rs"])

bzl_library(
    name = "rules",
    srcs = glob(
        ["**/*.bzl"],
    ),
    visibility = ["//rust:__subpackages__"],
    deps = [
        "//rust/platform:rules",
    ],
)

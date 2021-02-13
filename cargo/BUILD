load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

bzl_library(
    name = "rules",
    srcs = glob(["**/*.bzl"]),
)

alias(
    name = "raze",
    actual = "//cargo/cargo_raze:cargo_raze_bin",
)

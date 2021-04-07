load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

exports_files([
    "known_shas.bzl",
    "repositories.bzl",
    "rust.bzl",
    "defs.bzl",
    "toolchain.bzl",
])

toolchain_type(
    name = "toolchain",
)

bzl_library(
    name = "rules",
    srcs = glob(["**/*.bzl"]),
    deps = [
        "//rust/platform:rules",
        "//rust/private:rules",
    ],
)

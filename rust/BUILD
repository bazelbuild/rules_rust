load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

exports_files([
    "doc_server.template.py",
    "known_shas.bzl",
    "repositories.bzl",
    "rust.bzl",
    "toolchain.bzl",
])

toolchain_type(
    name = "toolchain",
)

bzl_library(
    name = "rules",
    srcs = glob(["**/*.bzl"]),
    deps = [
        "@io_bazel_rules_rust//rust/platform:rules",
    ],
)

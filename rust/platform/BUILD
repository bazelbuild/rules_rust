load(":platform.bzl", "declare_config_settings")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

declare_config_settings()

package_group(
    name = "function_transition_whitelist",
    packages = [
        "//...",
    ],
)

bzl_library(
    name = "rules",
    srcs = glob(["**/*.bzl"]),
    visibility = ["//rust:__pkg__"],
)

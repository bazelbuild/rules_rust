load("@rules_python//python:defs.bzl", "py_binary", "py_library", "py_test")

py_binary(
    name = "dir_zipper",
    srcs = ["dir_zipper.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = ["//visibility:public"],
    deps = [":dir_zipper_lib"],
)

py_library(
    name = "dir_zipper_lib",
    srcs = ["dir_zipper_lib.py"],
    srcs_version = "PY3",
    visibility = ["//visibility:private"],
)

py_test(
    name = "dir_zipper_lib_test",
    srcs = ["dir_zipper_lib_test.py"],
    data = [
        "@bazel_tools//tools/zip:zipper",
    ],
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = ["//visibility:private"],
    deps = [
        ":dir_zipper_lib",
    ],
)

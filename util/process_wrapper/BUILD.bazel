load("@rules_cc//cc:defs.bzl", "cc_binary")

cc_binary(
    name = "process_wrapper",
    srcs = [
        "process_wrapper.cc",
        "system.h",
        "utils.h",
        "utils.cc",
    ] + select({
        "@bazel_tools//src/conditions:host_windows": [
            "system_windows.cc",
        ],
        "//conditions:default": [
            "system_posix.cc",
        ],
    }),
    defines = [] + select({
        "@bazel_tools//src/conditions:host_windows": [
            "UNICODE",
            "_UNICODE",
        ],
        "//conditions:default": [],
    }),
    visibility = ["//visibility:public"],
)

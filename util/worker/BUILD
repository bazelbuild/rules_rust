load("@rules_cc//cc:defs.bzl", "cc_binary")
load("@rules_proto//proto:defs.bzl", "proto_library");

cc_binary(
    name = "worker",
    srcs = [
        "worker.cc",
        "//util/process_wrapper:system.h",
        "//util/process_wrapper:utils.h",
        "//util/process_wrapper:utils.cc",
    ] + select({
        "@bazel_tools//src/conditions:host_windows": [
            "//util/process_wrapper:system_windows.cc",
        ],
        "//conditions:default": [
            "//util/process_wrapper:system_posix.cc",
        ],
    }),
    deps = [":worker_cc_proto"],
    defines = [] + select({
        "@bazel_tools//src/conditions:host_windows": [
            "UNICODE",
            "_UNICODE",
        ],
        "//conditions:default": [],
    }),
    visibility = ["//visibility:public"],
)

cc_proto_library(
    name = "worker_cc_proto",
    deps = [":worker_protocol"],
)

proto_library(
    name = "worker_protocol",
    srcs = ["worker_protocol.proto"],
)

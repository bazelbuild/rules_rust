# Testing the prost_library macro usability

load("//rust:rust.bzl", "rust_library", "rust_test")
load("@rules_proto//proto:defs.bzl", "proto_library")
load("//proto/prostgen:prostgen.bzl", "prost_library", "tonic_library")

package(default_visibility = ["//visibility:private"])

proto_library(
    name = "echo_proto",
    srcs = ["echo.proto"],
    visibility = ["//visibility:public"],
)

prost_library(
    name = "echo_prost",
    visibility = ["//visibility:public"],
    deps = [
        ":echo_proto",
    ],
)

tonic_library(
    name = "echo_tonic",
    visibility = ["//visibility:public"],
    deps = [
        ":echo_proto",
    ],
)

rust_library(
    name = "echo_impl",
    testonly = True,
    srcs = [
        "echo_impl.rs",
    ],
    edition = "2018",
    visibility = ["//visibility:public"],
    deps = [
        ":echo_tonic",
        "//test/prostgen/raze:tonic",
    ],
)

rust_test(
    name = "prostgen_proto_usage_test",
    srcs = ["echo_usage_test.rs"],
    edition = "2018",
    deps = [":echo_prost"],
)

rust_test(
    name = "tonic_usage_test",
    srcs = ["echo_service_test.rs"],
    edition = "2018",
    deps = [
        ":echo_tonic",
        "//test/prostgen/raze:tonic",
    ],
)

proto_library(
    name = "a_proto",
    srcs = ["a.proto"],
)

proto_library(
    name = "b_proto",
    srcs = ["b.proto"],
)

proto_library(
    name = "x_proto",
    srcs = ["x.proto"],
    deps = [
        ":a_proto",
        ":b_proto",
    ],
)

proto_library(
    name = "y_proto",
    srcs = ["y.proto"],
    deps = [
        ":a_proto",
        ":b_proto",
    ],
)

prost_library(
    name = "a_prost",
    deps = [":a_proto"],
)

prost_library(
    name = "b_prost",
    deps = [":b_proto"],
)

prost_library(
    name = "x_prost",
    extern = [
        ":a_prost",
        ":b_prost",
    ],
    deps = [":x_proto"],
)

prost_library(
    name = "y_prost",
    extern = [
        ":a_prost",
        ":b_prost",
    ],
    deps = [":y_proto"],
)

rust_test(
    name = "extern_path_test",
    srcs = ["extern_path_test.rs"],
    edition = "2018",
    deps = [
        ":a_prost",
        ":b_prost",
        ":x_prost",
        ":y_prost",
    ],
)

# Demonstrate include directories for folders which are not in this one
proto_library(
    name = "use_external_proto",
    srcs = ["use_external.proto"],
    deps = [
        "@com_google_protobuf//:any_proto",
        "@com_google_protobuf//:timestamp_proto",
    ],
)

prost_library(
    name = "use_directly_prost",
    deps = [
        ":use_external_proto",
    ],
)

prost_library(
    name = "use_indirectly_prost",
    deps = [
        ":use_external_proto",
    ],
)

proto_library(
    name = "depends_on_use_external_proto",
    srcs = ["depends_on_use_external.proto"],
    deps = [
        ":use_external_proto",
    ],
)

prost_library(
    name = "depends_on_use_external_prost",
    extern = [
    ],
    deps = [
        ":depends_on_use_external_proto",
    ],
)

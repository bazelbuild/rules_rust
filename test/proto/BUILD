load("@io_bazel_rules_rust//proto:proto.bzl", "rust_proto_library")

proto_library(
    name = "a_proto",
    srcs = ["a.proto"],
    proto_source_root = "test/proto",
)

proto_library(
    name = "b_proto",
    srcs = ["b.proto"],
    proto_source_root = "test/proto",
    deps = [":a_proto"],
)

rust_proto_library(
    name = "b_rust",
    deps = [":b_proto"],
)

rust_proto_library(
    name = "yolo1",
    deps = ["//test/proto/yolo_pkg:yolo"],
)

rust_proto_library(
    name = "yolo2",
    deps = ["//test/proto/yolo_pkg:yolo_strip_absolute"],
)

rust_proto_library(
    name = "yolo3",
    deps = ["//test/proto/yolo_pkg:yolo_strip_relative"],
)

rust_proto_library(
    name = "yolo4",
    deps = ["//test/proto/yolo_pkg:yolo_prefix"],
)

rust_proto_library(
    name = "yolo5",
    deps = ["//test/proto/yolo_pkg:yolo_all_relative"],
)

rust_proto_library(
    name = "yolo6",
    deps = ["//test/proto/yolo_pkg:yolo_all_absolute"],
)

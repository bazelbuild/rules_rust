package(default_visibility = ["//visibility:public"])

proto_library(
    name = "yolo",
    srcs = [ "strip_pkg/yolo.proto" ],
)

proto_library(
    name = "yolo_strip_absolute",
    srcs = [ "strip_pkg/yolo.proto" ],
    strip_import_prefix = "/test/proto/yolo_pkg"
)

proto_library(
    name = "yolo_strip_relative",
    srcs = [ "strip_pkg/yolo.proto" ],
    strip_import_prefix = "strip_pkg"
)

proto_library(
    name = "yolo_prefix",
    srcs = [ "strip_pkg/yolo.proto" ],
    import_prefix = "yolo_prefix",
)

proto_library(
    name = "yolo_all_relative",
    srcs = [ "strip_pkg/yolo.proto" ],
    import_prefix = "yolo_prefix",
    strip_import_prefix = "strip_pkg"
)

proto_library(
    name = "yolo_all_absolute",
    srcs = [ "strip_pkg/yolo.proto" ],
    import_prefix = "yolo_prefix",
    strip_import_prefix = "/test/proto/yolo_pkg"
)

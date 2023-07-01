"""Legacy load locations for rust-protobuf rules"""

load(
    "//proto/protobuf:proto.bzl",
    _RustProtoInfo = "RustProtoInfo",
    _rust_grpc_library = "rust_grpc_library",
    _rust_proto_library = "rust_proto_library",
)

RustProtoInfo = _RustProtoInfo
rust_proto_library = _rust_proto_library
rust_grpc_library = _rust_grpc_library

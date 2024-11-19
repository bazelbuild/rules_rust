"""Rust Protobuf Rules"""

load(":proto.bzl", _rust_grpc_library = "rust_grpc_library", _rust_proto_library = "rust_proto_library")

rust_grpc_library = _rust_grpc_library
rust_proto_library = _rust_proto_library

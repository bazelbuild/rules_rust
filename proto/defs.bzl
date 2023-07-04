"""Rust proto rules."""

load(
    "//proto/prost:defs.bzl",
    _rust_prost_library = "rust_prost_library",
)
load(
    ":proto.bzl",
    _rust_grpc_library = "rust_grpc_library",
    _rust_proto_library = "rust_proto_library",
)

rust_proto_library = _rust_proto_library
rust_grpc_library = _rust_grpc_library

rust_prost_library = _rust_prost_library

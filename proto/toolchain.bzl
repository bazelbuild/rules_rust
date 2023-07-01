"""Legacy load locations for rust-protobuf toolchains"""

load("//proto/protobuf:toolchain.bzl", _rust_proto_toolchain = "rust_proto_toolchain")

rust_proto_toolchain = _rust_proto_toolchain

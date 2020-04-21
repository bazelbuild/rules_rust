"""
cargo-raze workspace build file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""
package(default_visibility = ["//visibility:public"])

licenses([
  "notice" # See individual crates for specific licenses
])
alias(
    name = "grpc",
    actual = "@raze__grpc__0_6_2//:grpc",
)
alias(
    name = "grpc_compiler",
    actual = "@raze__grpc_compiler__0_6_2//:grpc_compiler",
)
alias(
    # Extra aliased target, from raze configuration
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_protoc_gen_rust_grpc",
    actual = "@raze__grpc_compiler__0_6_2//:cargo_bin_protoc_gen_rust_grpc",
)
alias(
    name = "log",
    actual = "@raze__log__0_4_6//:log",
)
alias(
    name = "protobuf",
    actual = "@raze__protobuf__2_8_2//:protobuf",
)
alias(
    name = "protobuf_codegen",
    actual = "@raze__protobuf_codegen__2_8_2//:protobuf_codegen",
)
alias(
    # Extra aliased target, from raze configuration
    # N.B.: The exact form of this is subject to change.
    name = "cargo_bin_protoc_gen_rust",
    actual = "@raze__protobuf_codegen__2_8_2//:cargo_bin_protoc_gen_rust",
)
alias(
    name = "tls_api",
    actual = "@raze__tls_api__0_1_22//:tls_api",
)
alias(
    name = "tls_api_stub",
    actual = "@raze__tls_api_stub__0_1_22//:tls_api_stub",
)

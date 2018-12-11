load("@io_bazel_rules_rust//rust:toolchain.bzl", _rust_toolchain = "rust_toolchain")
load("@io_bazel_rules_rust//proto:toolchain.bzl", _rust_proto_toolchain = "rust_proto_toolchain")

# TODO: Blocked up lack of upstream bzl_library instances...
# load(
#     "@io_bazel_rules_rust//rust:rust.bzl",
#     "rust_benchmark ",
#     "rust_binary",
#     "rust_doc",
#     "rust_doc_test",
#     "rust_library",
#     "rust_test",
# )

# TODO: This aliasing isn't mentioned in the docs, but generated documentation is broken without it.
rust_toolchain = _rust_toolchain
rust_proto_toolchain = _rust_proto_toolchain

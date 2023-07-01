"""Dependencies for Rust prost rules"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def rust_prost_dependencies():
    maybe(
        http_archive,
        name = "rules_proto",
        sha256 = "dc3fb206a2cb3441b485eb1e423165b231235a1ea9b031b4433cf7bc1fa460dd",
        strip_prefix = "rules_proto-5.3.0-21.7",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_proto/archive/refs/tags/5.3.0-21.7.tar.gz",
            "https://github.com/bazelbuild/rules_proto/archive/refs/tags/5.3.0-21.7.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "com_google_protobuf",
        sha256 = "758249b537abba2f21ebc2d02555bf080917f0f2f88f4cbe2903e0e28c4187ed",
        strip_prefix = "protobuf-3.10.0",
        urls = ["https://github.com/protocolbuffers/protobuf/releases/download/v23.3/protobuf-23.3.tar.gz"],
    )

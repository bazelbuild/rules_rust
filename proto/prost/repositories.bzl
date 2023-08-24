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
        sha256 = "52b6160ae9266630adb5e96a9fc645215336371a740e87d411bfb63ea2f268a0",
        strip_prefix = "protobuf-3.18.0",
        urls = ["https://github.com/protocolbuffers/protobuf/releases/download/v3.18.0/protobuf-all-3.18.0.tar.gz"],
    )

    maybe(
        http_archive,
        name = "rules_rust_prost__heck",
        sha256 = "95505c38b4572b2d910cecb0281560f54b440a19336cbbcb27bf6ce6adc6f5a8",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/heck/0.4.1/download"],
        strip_prefix = "heck-0.4.1",
        build_file = Label("@rules_rust//proto/prost/private/3rdparty/crates:BUILD.heck-0.4.1.bazel"),
    )

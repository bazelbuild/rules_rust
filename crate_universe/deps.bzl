"""Dependencies required by the `cargo-bazel` rules"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//3rdparty:third_party_deps.bzl", "third_party_deps")
load("//private:vendor_utils.bzl", "crates_vendor_deps")

def cargo_bazel_deps():
    maybe(
        http_archive,
        name = "rules_rust",
        sha256 = "7826dbbbf617da8645d2cdd9a944e7948cc9cf87e7242c54cc0c53110495d1c7",
        strip_prefix = "rules_rust-acca6f400003b9ae097b69ba8f44878aaf65beed",
        urls = [
            # `main` branch as of 2022-03-01
            "https://github.com/bazelbuild/rules_rust/archive/acca6f400003b9ae097b69ba8f44878aaf65beed.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "bazel_skylib",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.2.0/bazel-skylib-1.2.0.tar.gz",
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.2.0/bazel-skylib-1.2.0.tar.gz",
        ],
        sha256 = "af87959afe497dc8dfd4c6cb66e1279cb98ccc84284619ebfec27d9c09a903de",
    )

    third_party_deps()

    crates_vendor_deps()

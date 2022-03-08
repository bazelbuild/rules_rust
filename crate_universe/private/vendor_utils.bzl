"""Utility functions for use with the `crates_vendor` rule"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

_BUILDIFIER_VERSION = "5.0.1"
_BUILDIFIER_URL_TEMPLATE = "https://github.com/bazelbuild/buildtools/releases/download/{version}/{bin}"
_BUILDIFIER_SHA256S = {
    "buildifier-darwin-amd64": "2cb0a54683633ef6de4e0491072e22e66ac9c6389051432b76200deeeeaf93fb",
    "buildifier-darwin-arm64": "4da23315f0dccabf878c8227fddbccf35545b23b3cb6225bfcf3107689cc4364",
    "buildifier-linux-amd64": "3ed7358c7c6a1ca216dc566e9054fd0b97a1482cb0b7e61092be887d42615c5d",
    "buildifier-linux-arm64": "c657c628fca72b7e0446f1a542231722a10ba4321597bd6f6249a5da6060b6ff",
    "buildifier-windows-amd64.exe": "45e13b2951e4c611d346dacdaf0aafaa484045a3e7300fbc5dd01a896a688177",
}

def crates_vendor_deps():
    for bin, sha256 in _BUILDIFIER_SHA256S.items():
        maybe(
            http_file,
            name = "cargo_bazel.{}".format(bin),
            urls = [_BUILDIFIER_URL_TEMPLATE.format(
                bin = bin,
                version = _BUILDIFIER_VERSION,
            )],
            sha256 = sha256,
            downloaded_file_path = "buildifier.exe",
            executable = True,
        )

# buildifier: disable=unnamed-macro
def crates_vendor_deps_targets():
    """Define dependencies of the `crates_vendor` rule"""

    native.config_setting(
        name = "linux_amd64",
        constraint_values = ["@platforms//os:linux", "@platforms//cpu:x86_64"],
        visibility = ["//visibility:public"],
    )

    native.config_setting(
        name = "linux_arm64",
        constraint_values = ["@platforms//os:linux", "@platforms//cpu:arm64"],
        visibility = ["//visibility:public"],
    )

    native.config_setting(
        name = "macos_amd64",
        constraint_values = ["@platforms//os:macos", "@platforms//cpu:x86_64"],
        visibility = ["//visibility:public"],
    )

    native.config_setting(
        name = "macos_arm64",
        constraint_values = ["@platforms//os:macos", "@platforms//cpu:arm64"],
        visibility = ["//visibility:public"],
    )

    native.config_setting(
        name = "windows",
        constraint_values = ["@platforms//os:windows"],
        visibility = ["//visibility:public"],
    )

    native.alias(
        name = "buildifier",
        actual = select({
            ":linux_amd64": "@cargo_bazel.buildifier-linux-amd64//file",
            ":linux_arm64": "@cargo_bazel.buildifier-linux-arm64//file",
            ":macos_amd64": "@cargo_bazel.buildifier-darwin-amd64//file",
            ":macos_arm64": "@cargo_bazel.buildifier-darwin-arm64//file",
            ":windows": "@cargo_bazel.buildifier-windows-amd64.exe//file",
        }),
        visibility = ["//visibility:public"],
    )

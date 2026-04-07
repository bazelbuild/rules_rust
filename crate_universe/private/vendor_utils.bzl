"""Utility functions for use with the `crates_vendor` rule"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

_BUILDIFIER_VERSION = "8.5.1"
_BUILDIFIER_URL_TEMPLATE = "https://github.com/bazelbuild/buildtools/releases/download/v{version}/{bin}"
_BUILDIFIER_INTEGRITY = {
    "buildifier-darwin-amd64": "sha256-Md4Ynho/5Tqp6Mj3SgMJwyUnStGXkzk5GeHKZRY8oaQ=",
    "buildifier-darwin-arm64": "sha256-YoNqlmf6DbMJsNkehA8KPygTqcjqPkS5zVgYfJC8iLo=",
    "buildifier-linux-amd64": "sha256-iHN3/GTSOoUPTRigd7XbBbGZE/S5mycNGT88czS1qac=",
    "buildifier-linux-arm64": "sha256-lHv2cA1wgCayBXsJvqCau8PK/BXZ7Oo1uziFxLCczQQ=",
    "buildifier-windows-amd64.exe": "sha256-9Oy5xz3ivDi4RdTuJ2aPYkjEgTpmR9tLSTGnVWBS5OE=",
}

def crates_vendor_deps():
    """Define dependencies of the `crates_vendor` rule

    Returns:
        list[struct(repo=str, is_dev_dep=bool)]: List of the dependency repositories.
    """
    direct_deps = []

    for bin, integrity in _BUILDIFIER_INTEGRITY.items():
        repo = "cargo_bazel.{}".format(bin)
        maybe(
            http_file,
            name = repo,
            urls = [_BUILDIFIER_URL_TEMPLATE.format(
                bin = bin,
                version = _BUILDIFIER_VERSION,
            )],
            integrity = integrity,
            downloaded_file_path = "buildifier.exe" if bin.endswith(".exe") else "buildifier",
            executable = True,
        )
        direct_deps.append(struct(repo = repo, is_dev_dep = False))

    return direct_deps

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

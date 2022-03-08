"""Dependencies needed for the cross-installer tool"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def cross_installer_deps():
    version = "0.2.1"

    components = {
        "x86_64-apple-darwin": "589da89453291dc26f0b10b521cdadb98376d495645b210574bd9ca4ec8cfa2c",
        "x86_64-pc-windows-msvc": "3af59ff5a2229f92b54df937c50a9a88c96dffc8ac3dde520a38fdf046d656c4",
        "x86_64-unknown-linux-gnu": "06dcce3248488e95fbb368d14bef17fa8e77461d5055fbd5193538574820f413",
    }

    for triple, sha256 in components.items():
        maybe(
            http_archive,
            name = "cross_{}".format(triple),
            urls = ["https://github.com/rust-embedded/cross/releases/download/v{version}/cross-v{version}-{triple}.tar.gz".format(
                triple = triple,
                version = version,
            )],
            sha256 = sha256,
            build_file_content = """exports_files(glob(["**"]), visibility = ["//visibility:public"])""",
        )

def cross_binary(name = "cross"):
    native.config_setting(
        name = "linux",
        constraint_values = ["@platforms//os:linux"],
    )

    native.config_setting(
        name = "macos",
        constraint_values = ["@platforms//os:macos"],
    )

    native.config_setting(
        name = "windows",
        constraint_values = ["@platforms//os:windows"],
    )

    native.alias(
        name = name,
        actual = select({
            ":linux": "@cross_x86_64-unknown-linux-gnu//:cross",
            ":macos": "@cross_x86_64-apple-darwin//:cross",
            ":windows": "@cross_x86_64-pc-windows-msvc//:cross.exe",
        }),
    )

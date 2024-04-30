"""Utility functions for use with the `crates_vendor` rule"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

_BUILDIFIER_VERSION = "7.1.1"
_BUILDIFIER_URL_TEMPLATE = "https://github.com/bazelbuild/buildtools/releases/download/v{version}/{bin}"
_BUILDIFIER_INTEGRITY = {
    "buildifier-darwin-amd64": "sha256-d0YNlXr3oCi7GK223EP6ZLbgAGTkc+rINoq4pwOzp0M=",
    "buildifier-darwin-arm64": "sha256-yZD0sDsn1qDYb/6TAUcypZwYurDE86TMVjS9OxYp/OM=",
    "buildifier-linux-amd64": "sha256-VLfyzo8idhz60mRBbpEgVq6chkX1nrZYO4RrSGSh7oM=",
    "buildifier-linux-arm64": "sha256-HZrx9pVqQ5/KKHii+/dguXyl3wD2aeXRlTvrDEYHrHE=",
    "buildifier-windows-amd64.exe": "sha256-Mx2IPnyjbIu+KKHoUoqccRAvS+Yj+Tn6PSCk2PAEvqs=",
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

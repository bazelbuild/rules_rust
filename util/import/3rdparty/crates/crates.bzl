###############################################################################
# @generated
# This file is auto-generated by the cargo-bazel tool.
#
# DO NOT MODIFY: Local changes may be replaced in future executions.
###############################################################################
"""Rules for defining repositories for remote `crates_vendor` repositories"""

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

# buildifier: disable=bzl-visibility
load("@rules_rust//crate_universe/private:crates_vendor.bzl", "crates_vendor_remote_repository")

# buildifier: disable=bzl-visibility
load("@rules_rust//util/import/3rdparty/crates:defs.bzl", _crate_repositories = "crate_repositories")

def crate_repositories():
    maybe(
        crates_vendor_remote_repository,
        name = "rules_rust_util_import",
        build_file = Label("@rules_rust//util/import/3rdparty/crates:BUILD.bazel"),
        defs_module = Label("@rules_rust//util/import/3rdparty/crates:defs.bzl"),
    )

    direct_deps = [struct(direct_deps = ["rules_rust_util_import"])]
    direct_deps.extend(_crate_repositories())
    return direct_deps

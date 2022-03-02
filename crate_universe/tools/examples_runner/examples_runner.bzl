"""A helper for defining a process wrapper for building and testing examples"""

load("@crate_index//:defs.bzl", "all_crate_deps")
load("@rules_rust//rust:defs.bzl", "rust_binary")

def examples_runner(name, cargo_bazel_bin, distro_archive, examples_package):
    rust_binary(
        name = name,
        srcs = ["//tools/examples_runner:srcs"],
        data = [
            distro_archive,
            cargo_bazel_bin,
        ],
        rustc_env = {
            "CARGO_BAZEL_BIN": "$(rootpath {})".format(cargo_bazel_bin),
            "DISTRO_ARCHIVE": "$(rootpath {})".format(distro_archive),
            "EXAMPLES_PACKAGE": examples_package,
        },
        deps = all_crate_deps(package_name = "tools/examples_runner"),
        proc_macro_deps = all_crate_deps(proc_macro = True, package_name = "tools/examples_runner"),
    )

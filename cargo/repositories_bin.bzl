load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

# These could perhaps be populated with pre-built versions as part of a release pipeline. Details to be discussed :)

def crate_universe_bin_deps():
    maybe(
        http_file,
        name = "crate_universe_resolver_linux",
        urls = [
            "file:///dev/null",
        ],
        executable = True,
    )

    maybe(
        http_file,
        name = "crate_universe_resolver_darwin",
        urls = [
            "file:///dev/null",
        ],
        executable = True,
    )

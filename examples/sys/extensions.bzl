"""Bzlmod module extensions"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//basic/3rdparty/crates:crates.bzl", basic_crate_repositories = "crate_repositories")
load("//complex/3rdparty/crates:crates.bzl", complex_crate_repositories = "crate_repositories")

def _rust_example_impl(module_ctx):
    # This should contain the subset of WORKSPACE.bazel that defines
    # repositories.
    direct_deps = []

    direct_deps.extend(basic_crate_repositories())
    direct_deps.extend(complex_crate_repositories())

    http_archive(
        name = "zlib",
        build_file = Label("//complex/3rdparty:BUILD.zlib.bazel"),
        sha256 = "c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1",
        strip_prefix = "zlib-1.2.11",
        urls = [
            "https://zlib.net/zlib-1.2.11.tar.gz",
            "https://storage.googleapis.com/mirror.tensorflow.org/zlib.net/zlib-1.2.11.tar.gz",
        ],
    )
    direct_deps.append(struct(repo = "zlib"))

    http_archive(
        name = "libgit2",
        build_file = Label("//complex/3rdparty:BUILD.libgit2.bazel"),
        sha256 = "d25866a4ee275a64f65be2d9a663680a5cf1ed87b7ee4c534997562c828e500d",
        # The version here should match the version used with the Rust crate `libgit2-sys`
        # https://github.com/rust-lang/git2-rs/tree/libgit2-sys-0.15.2+1.6.4/libgit2-sys
        strip_prefix = "libgit2-1.6.4",
        urls = ["https://github.com/libgit2/libgit2/archive/refs/tags/v1.6.4.tar.gz"],
    )
    direct_deps.append(struct(repo = "libgit2"))

    # is_dev_dep is ignored here. It's not relevant for internal_deps, as dev
    # dependencies are only relevant for module extensions that can be used
    # by other MODULES.
    return module_ctx.extension_metadata(
        root_module_direct_deps = [repo.repo for repo in direct_deps],
        root_module_direct_dev_deps = [],
    )

rust_example = module_extension(
    doc = "Dependencies for the rules_rust examples.",
    implementation = _rust_example_impl,
)

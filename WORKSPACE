workspace(name = "io_bazel_rules_rust")

load(
    "@bazel_tools//tools/build_defs/repo:git.bzl",
    "git_repository",
    "new_git_repository",
)
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

local_repository(
    name = "examples",
    path = "examples",
)

local_repository(
    name = "docs",
    path = "docs",
)

# TODO: Move this to examples/WORKSPACE when recursive repositories are enabled.
load("//rust:repositories.bzl", "rust_repositories")

rust_repositories()

new_git_repository(
    name = "libc",
    build_file = "//:libc.BUILD",
    remote = "https://github.com/rust-lang/libc",
    tag = "0.2.20",
)

# Used for documenting Rust rules.
git_repository(
    name = "io_bazel_rules_sass",
    remote = "https://github.com/bazelbuild/rules_sass.git",
    tag = "0.0.3",
)

load("@io_bazel_rules_sass//sass:sass.bzl", "sass_repositories")

sass_repositories()

git_repository(
    name = "io_bazel_skydoc",
    remote = "https://github.com/bazelbuild/skydoc.git",
    tag = "0.1.4",
)

load("@io_bazel_skydoc//skylark:skylark.bzl", "skydoc_repositories")

skydoc_repositories()

http_archive(
    name = "bazel_toolchains",
    sha256 = "7938215442cc96b1a16809f4643db14af7d91c3ef1e98d39593bb46862204537",
    strip_prefix = "bazel-toolchains-809c13c3a96966f63c7a43c586cb4e72589184b6",
    urls = [
        "https://github.com/bazelbuild/bazel-toolchains/archive/809c13c3a96966f63c7a43c586cb4e72589184b6.tar.gz",
    ],
)

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

http_archive(
    name = "bazel_skylib",
    sha256 = "eb5c57e4c12e68c0c20bc774bfbc60a568e800d025557bc4ea022c6479acc867",
    strip_prefix = "bazel-skylib-0.6.0",
    url = "https://github.com/bazelbuild/bazel-skylib/archive/0.6.0.tar.gz",
)

# TODO: Move this to examples/WORKSPACE when recursive repositories are enabled.
load("@io_bazel_rules_rust//rust:repositories.bzl", "rust_repositories")
rust_repositories()

new_git_repository(
    name = "libc",
    build_file = "@io_bazel_rules_rust//:libc.BUILD",
    remote = "https://github.com/rust-lang/libc",
    tag = "0.2.20",
)

load("@io_bazel_rules_rust//proto:repositories.bzl", "rust_proto_repositories")
rust_proto_repositories()

load("@io_bazel_rules_rust//bindgen:repositories.bzl", "rust_bindgen_repositories")
rust_bindgen_repositories()

# Stardoc and its dependencies
git_repository(
    name = "io_bazel_skydoc",
    remote = "https://github.com/bazelbuild/skydoc.git",
    commit = "82fdbfe797c6591d8732df0c0389a2b1c3e50992",  # 2018-12-12
)

load("@io_bazel_skydoc//:setup.bzl", "skydoc_repositories")
skydoc_repositories()

load("@io_bazel_rules_sass//:package.bzl", "rules_sass_dependencies")
rules_sass_dependencies()

load("@build_bazel_rules_nodejs//:defs.bzl", "node_repositories")
node_repositories()

load("@io_bazel_rules_sass//:defs.bzl", "sass_repositories")
sass_repositories()
# --- end stardoc


http_archive(
    name = "bazel_toolchains",
    sha256 = "7e85a14821536bc24e04610d309002056f278113c6cc82f1059a609361812431",
    strip_prefix = "bazel-toolchains-bc0091adceaf4642192a8dcfc46e3ae3e4560ea7",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-toolchains/archive/bc0091adceaf4642192a8dcfc46e3ae3e4560ea7.tar.gz",
        "https://github.com/bazelbuild/bazel-toolchains/archive/bc0091adceaf4642192a8dcfc46e3ae3e4560ea7.tar.gz",
    ],
)

load("@io_bazel_rules_rust//:workspace.bzl", "bazel_version")
bazel_version(name = "bazel_version")

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
    sha256 = "12ee3a5732e8c353fce4a710dbe045a16a161c49c79622faa1f2813f668bb442",
    strip_prefix = "bazel-skylib-8f3151fb4a91d5f2ae4cad5901ea72fe30a2aba0",
    url = "https://github.com/bazelbuild/bazel-skylib/archive/8f3151fb4a91d5f2ae4cad5901ea72fe30a2aba0.tar.gz",  # 2020-07-10
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

load("@io_bazel_rules_rust//wasm_bindgen:repositories.bzl", "rust_wasm_bindgen_repositories")
rust_wasm_bindgen_repositories()

http_archive(
    name = "build_bazel_rules_nodejs",
    sha256 = "e1a0d6eb40ec89f61a13a028e7113aa3630247253bcb1406281b627e44395145",
    urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/1.0.1/rules_nodejs-1.0.1.tar.gz"],
)

load("@build_bazel_rules_nodejs//:index.bzl", "node_repositories", "npm_install")
node_repositories()

# Dependencies for the @examples//hello_world_wasm example.
npm_install(
    name = "npm",
    package_json = "//:package.json",
    package_lock_json = "//:package-lock.json",
)

# Install all Bazel dependencies needed for npm packages that supply Bazel rules
load("@npm//:install_bazel_dependencies.bzl", "install_bazel_dependencies")

install_bazel_dependencies()
# --- end stardoc

http_archive(
    name = "bazel_toolchains",
    sha256 = "d8c2f20deb2f6143bac792d210db1a4872102d81529fe0ea3476c1696addd7ff",
    strip_prefix = "bazel-toolchains-0.28.3",
    urls = [
      "https://mirror.bazel.build/github.com/bazelbuild/bazel-toolchains/archive/0.28.3.tar.gz",
      "https://github.com/bazelbuild/bazel-toolchains/archive/0.28.3.tar.gz",
    ],
)

load("@bazel_toolchains//rules:rbe_repo.bzl", "rbe_autoconfig")

# Creates toolchain configuration for remote execution with BuildKite CI
# for rbe_ubuntu1604
rbe_autoconfig(
    name = "buildkite_config",
)

load("@io_bazel_rules_rust//:workspace.bzl", "bazel_version")
bazel_version(name = "bazel_version")

load("@examples//hello_sys:workspace.bzl", "remote_deps")
remote_deps()

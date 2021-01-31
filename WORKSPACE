workspace(name = "rules_rust")

load("@rules_rust//rust:repositories.bzl", "rust_repositories")

rust_repositories()

load("@rules_rust//proto:repositories.bzl", "rust_proto_repositories")

rust_proto_repositories()

load("@rules_rust//bindgen:repositories.bzl", "rust_bindgen_repositories")

rust_bindgen_repositories()

load("@rules_rust//wasm_bindgen:repositories.bzl", "rust_wasm_bindgen_repositories")

rust_wasm_bindgen_repositories()

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

load("//test:deps.bzl", "io_bazel_rules_rust_test_deps")

io_bazel_rules_rust_test_deps()

# --- end stardoc

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

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

# Load all dependencies for examples

local_repository(
    name = "examples",
    path = "examples",
)

load("@examples//:examples_repositories.bzl", examples_repositories = "repositories")

examples_repositories()

load("@examples//:examples_deps.bzl", examples_deps = "deps")

examples_deps()

load("@examples//:examples_transitive_deps.bzl", examples_transitive_deps = "transitive_deps")

examples_transitive_deps(is_top_level = True)

# Load all dependencies for docs

local_repository(
    name = "docs",
    path = "docs",
)

load("@docs//:docs_repositories.bzl", docs_repositories = "repositories")

docs_repositories()

load("@docs//:docs_deps.bzl", docs_deps = "deps")

docs_deps()

load("@docs//:docs_transitive_deps.bzl", docs_transitive_deps = "transitive_deps")

docs_transitive_deps(is_top_level = True)

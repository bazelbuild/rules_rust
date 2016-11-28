workspace(name = "io_bazel_rules_rust")

local_repository(
    name = "examples",
    path = "examples",
)

# TODO: Move this to examples/WORKSPACE when recursive repositories are enabled.
load("//rust:rust.bzl", "rust_repositories")

rust_repositories()

"""Transitive dependencies of the `cargo-bazel` Rust target"""

load("@crate_index//:defs.bzl", _repository_crate_repositories = "crate_repositories")
load("//:crates.bzl", "USE_CRATES_REPOSITORY")

def crate_repositories():
    if USE_CRATES_REPOSITORY:
        _repository_crate_repositories()

"""A module defining the required repositories of cargo-raze examples"""

load("@rules_rust//cargo/cargo_raze:repositories.bzl", "cargo_raze_repositories")
load("//cargo_raze/tools:examples_repository.bzl", "examples_repository")

def cargo_raze_example_repositories():
    """Load all required repositories for the cargo-raze exampls"""
    cargo_raze_repositories()

    examples_repository()

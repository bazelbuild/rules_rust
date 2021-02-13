"""A module defining the transitive dependencies of cargo-raze examples"""

load("@rules_rust//cargo/cargo_raze:transitive_deps.bzl", "cargo_raze_transitive_deps")
load("@rules_rust_cargo_raze_examples//:repositories.bzl", "repositories")

def cargo_raze_example_transitive_deps():
    cargo_raze_transitive_deps()

    repositories()

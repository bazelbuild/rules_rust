"""A module for loading the transitive dependnecies of cargo-raze"""

load("//cargo/cargo_raze/third_party:third_party_transitive_deps.bzl", "third_party_transitive_deps")

def cargo_raze_transitive_deps():
    third_party_transitive_deps()

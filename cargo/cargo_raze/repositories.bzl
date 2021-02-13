"""A module for loading the third party repositories of cargo-raze"""

load("//cargo/cargo_raze/third_party:third_party_repositories.bzl", "third_party_repositories")

def cargo_raze_repositories():
    third_party_repositories()

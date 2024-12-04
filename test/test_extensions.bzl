"""Bzlmod test extensions"""

load("//test/3rdparty/crates:crates.bzl", test_crate_repositories = "crate_repositories")
load("//tests:test_deps.bzl", "helm_test_deps")

def _rust_test_impl(_ctx):
    helm_test_deps()
    test_crate_repositories()

rust_test = module_extension(
    implementation = _rust_test_impl,
)

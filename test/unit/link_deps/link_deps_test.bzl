"""Unit tests for link_deps."""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//rust:defs.bzl", "rust_common")

def _link_deps_test_impl(env, target):
    # Verify that CcInfo (symbols) is present
    env.expect.that_target(target).has_provider(CcInfo)

    dep_info = target[rust_common.dep_info]

    # Verify that leaf_lib is NOT in direct_crates
    direct_crate_names = [
        direct_crate.name
        for direct_crate in dep_info.direct_crates.to_list()
    ]
    env.expect.that_collection(direct_crate_names).not_contains("leaf_lib")

    # Verify that transitive_noncrates specifically contains leaf_lib as a linking input
    linker_input_owners = [
        linker_input.owner
        for linker_input in dep_info.transitive_noncrates.to_list()
    ]
    env.expect.that_collection(linker_input_owners).contains(
        Label("//test/unit/link_deps:leaf_lib"),
    )

def link_deps_test(name, target):
    """Analysis test macro for link_deps.

    Args:
        name: Name of the test target.
        target: Target under test.
    """
    analysis_test(
        name = name,
        target = target,
        impl = _link_deps_test_impl,
    )

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//rust/private:common.bzl", "rust_common")

def _link_deps_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    # Verify that CcInfo (symbols) is present
    asserts.true(env, CcInfo in target, "Target should provide CcInfo from link_deps")

    dep_info = target[rust_common.dep_info]

    # Verify that leaf_lib is NOT in direct_crates
    for direct_crate in dep_info.direct_crates.to_list():
        asserts.not_equals(env, "leaf_lib", direct_crate.name, "link_deps should not be added to direct_crates")

    # Verify that transitive_noncrates specifically contains leaf_lib as a linking input
    linker_inputs = dep_info.transitive_noncrates.to_list()
    found_leaf_lib = False
    for linker_input in linker_inputs:
        if linker_input.owner == Label("//test/unit/link_deps:leaf_lib"):
            found_leaf_lib = True
            break
    asserts.true(env, found_leaf_lib, "link_deps should pass leaf_lib as a linker input")

    return analysistest.end(env)

link_deps_test = analysistest.make(_link_deps_test_impl)

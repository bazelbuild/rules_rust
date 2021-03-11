"""Unittests for rust rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc:defs.bzl", "cc_library")
load("//rust:defs.bzl", "rust_common", "rust_library")

def _interleaving_cc_link_order_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    cc_info = tut[CcInfo]
    linker_inputs = cc_info.linking_context.linker_inputs.to_list()
    a = linker_inputs[0]
    b = linker_inputs[1]
    c = linker_inputs[2]
    d = linker_inputs[3]
    e = linker_inputs[4]

    asserts.equals(env, "a", a.owner.name)
    asserts.equals(env, "b", b.owner.name)
    asserts.equals(env, "c", c.owner.name)
    asserts.equals(env, "d", d.owner.name)
    asserts.equals(env, "e", e.owner.name)

    return analysistest.end(env)

def _interleaving_rust_link_order_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    dep_info = tut[rust_common.dep_info]
    deps = dep_info.transitive_deps.to_list()

    asserts.equals(env, len(deps), 2, "expected transitive_deps to contain 2 elements")

    a_single_dep_info = deps[0]
    b_single_dep_info = deps[1]

    asserts.equals(env, "a", a_single_dep_info.crate.name)
    asserts.true(env, a_single_dep_info.native == None, "expected :a to not provide native deps")
    asserts.true(env, a_single_dep_info.crate != None, "expected :a to provide crate deps")
    asserts.true(env, b_single_dep_info.native != None, "expected :b to provide native deps")
    asserts.true(env, b_single_dep_info.crate == None, "expected :b to not provide crate deps")

    linker_inputs = b_single_dep_info.native.to_list()
    b_linker_input = linker_inputs[0]
    c_linker_input = linker_inputs[1]
    d_linker_input = linker_inputs[2]
    e_linker_input = linker_inputs[3]

    asserts.equals(env, "b", b_linker_input.owner.name)
    asserts.equals(env, "c", c_linker_input.owner.name)
    asserts.equals(env, "d", d_linker_input.owner.name)
    asserts.equals(env, "e", e_linker_input.owner.name)

    return analysistest.end(env)

interleaving_cc_link_order_test = analysistest.make(_interleaving_cc_link_order_test_impl)
interleaving_rust_link_order_test = analysistest.make(_interleaving_rust_link_order_test_impl)

def _interleaving_link_order_test():
    rust_library(
        name = "a",
        srcs = ["a.rs"],
        deps = [":b"],
    )
    cc_library(
        name = "b",
        srcs = ["b.cc"],
        deps = [":c"],
    )
    rust_library(
        name = "c",
        srcs = ["c.rs"],
        deps = [":d"],
    )
    cc_library(
        name = "d",
        srcs = ["d.cc"],
        deps = [":e"],
    )
    rust_library(
        name = "e",
        srcs = ["e.rs"],
    )

    interleaving_cc_link_order_test(
        name = "interleaving_cc_link_order_test",
        target_under_test = ":a",
    )

    interleaving_rust_link_order_test(
        name = "interleaving_rust_link_order_test",
        target_under_test = ":a",
    )

def interleaved_cc_info_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _interleaving_link_order_test()

    native.test_suite(
        name = name,
        tests = [
            ":interleaving_cc_link_order_test",
            ":interleaving_rust_link_order_test",
        ],
    )

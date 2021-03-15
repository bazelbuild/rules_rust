"""Unittests for rust rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc:defs.bzl", "cc_library")
load("//rust:defs.bzl", "rust_common", "rust_library")

def _interleaving_rust_link_order_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    dep_info = tut[rust_common.dep_info]
    deps = dep_info.transitive_deps.to_list()

    asserts.equals(env, len(deps), 5, "expected transitive_deps to contain 2 elements")

    a = deps[0]
    b = deps[1]
    c = deps[2]
    d = deps[3]
    e = deps[4]

    asserts.true(env, a.crate != None, "expected :a to provide crate deps")
    asserts.true(env, a.native == None, "expected :a to not provide native deps")
    asserts.equals(env, "a", a.crate.name)

    asserts.true(env, b.crate != None, "expected :b to provide crate deps")
    asserts.true(env, b.native == None, "expected :b to not provide native deps")
    asserts.equals(env, "b", b.crate.name)

    asserts.true(env, c.crate == None, "expected :c not to provide crate deps")
    asserts.true(env, c.native != None, "expected :c to provide native deps")
    asserts.equals(env, "c", c.native.to_list()[0].owner.name)

    asserts.true(env, d.crate != None, "expected :d to provide crate deps")
    asserts.true(env, d.native == None, "expected :d not to provide native deps")
    asserts.equals(env, "d", d.crate.name)

    asserts.true(env, e.crate == None, "expected :e not to provide crate deps")
    asserts.true(env, e.native != None, "expected :e to provide native deps")
    asserts.equals(env, "e", e.native.to_list()[0].owner.name)

    return analysistest.end(env)

interleaving_rust_link_order_test = analysistest.make(_interleaving_rust_link_order_test_impl)

def _interleaving_link_order_test():
    # a:rust_library
    # |-b: rust_library
    # | `-c: cc_library
    # `-d: rust_library
    #   `-e: cc_library
    rust_library(
        name = "a",
        srcs = ["a.rs"],
        deps = [":b", ":d"],
    )
    rust_library(
        name = "b",
        srcs = ["b.rs"],
        deps = [":c"],
    )
    cc_library(
        name = "c",
        srcs = ["c.cc"],
    )
    rust_library(
        name = "d",
        srcs = ["d.rs"],
        deps = [":e"],
    )
    cc_library(
        name = "e",
        srcs = ["e.cc"],
    )

    interleaving_rust_link_order_test(
        name = "interleaving_rust_link_order_test",
        target_under_test = ":a",
    )

def interleaved_dep_info_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _interleaving_link_order_test()

    native.test_suite(
        name = name,
        tests = [
            ":interleaving_rust_link_order_test",
        ],
    )

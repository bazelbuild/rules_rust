"""Unittests for rust rules."""

load("@rules_cc//cc:defs.bzl", "cc_library")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//rust:defs.bzl", "rust_library")

def _interleaving_cc_link_order_test_impl(env, target):
    cc_info = target[CcInfo]
    linker_inputs = cc_info.linking_context.linker_inputs.to_list()
    a = linker_inputs[0]
    b = linker_inputs[1]
    c = linker_inputs[2]
    d = linker_inputs[3]
    e = linker_inputs[4]

    env.expect.that_str(a.owner.name).equals("interleaving_cc_link_order_test_a")
    env.expect.that_str(b.owner.name).equals("interleaving_cc_link_order_test_b")
    env.expect.that_str(c.owner.name).equals("interleaving_cc_link_order_test_c")
    env.expect.that_str(d.owner.name).equals("interleaving_cc_link_order_test_d")
    env.expect.that_str(e.owner.name).equals("interleaving_cc_link_order_test_e")

def _interleaving_cc_link_order_test(name):
    util.helper_target(
        rust_library,
        name = name + "_a",
        srcs = ["a.rs"],
        edition = "2018",
        deps = [":" + name + "_b"],
    )
    util.helper_target(
        cc_library,
        name = name + "_b",
        srcs = ["b.cc"],
        deps = [":" + name + "_c"],
    )
    util.helper_target(
        rust_library,
        name = name + "_c",
        srcs = ["c.rs"],
        edition = "2018",
        deps = [":" + name + "_d"],
    )
    util.helper_target(
        cc_library,
        name = name + "_d",
        srcs = ["d.cc"],
        deps = [":" + name + "_e"],
    )
    util.helper_target(
        rust_library,
        name = name + "_e",
        srcs = ["e.rs"],
        edition = "2018",
    )

    analysis_test(
        name = name,
        target = ":" + name + "_a",
        impl = _interleaving_cc_link_order_test_impl,
    )

def interleaved_cc_info_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    test_suite(
        name = name,
        tests = [
            _interleaving_cc_link_order_test,
        ],
    )

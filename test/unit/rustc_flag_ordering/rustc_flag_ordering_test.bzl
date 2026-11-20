"""Unittest to verify rustc flag ordering"""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//rust:defs.bzl", "rust_test")

def _rustc_flag_ordering_test_impl(env, target):
    action = target.actions[0]
    env.expect.that_action(action).mnemonic().equals("Rustc")

    # We expect:
    # 1. --edition=2018 (one of the flags added by default by construct_arguments)
    # 2. --test (added via rust_flags in rust_test, now moved right before authored flags)
    # 3. --cfg=my_authored_flag (added via rustc_flags attribute, added last in construct_arguments)
    env.expect.that_action(action).argv().contains_at_least([
        "--edition=2018",
        "--test",
        "--cfg=my_authored_flag",
    ]).in_order()

def _rustc_flag_ordering_test(name):
    util.helper_target(
        rust_test,
        name = name + "_test_target",
        srcs = ["lib.rs"],
        edition = "2018",
        rustc_flags = ["--cfg=my_authored_flag"],
    )

    analysis_test(
        name = name,
        target = ":" + name + "_test_target",
        impl = _rustc_flag_ordering_test_impl,
    )

def rustc_flag_ordering_test_suite(name):
    test_suite(
        name = name,
        tests = [
            _rustc_flag_ordering_test,
        ],
    )

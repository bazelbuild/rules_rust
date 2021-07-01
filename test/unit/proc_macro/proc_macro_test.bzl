"""Unittest to verify proc-macro targets"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("//rust:defs.bzl", "rust_proc_macro", "rust_test")
load("//test/unit:common.bzl", "assert_action_mnemonic", "assert_list_contains_adjacent_elements", "assert_list_contains_adjacent_elements_not")

def _proc_macro_test_targets(edition):
    """Define a set of `rust_proc_macro` targets for testing

    Args:
        edition (str): The rust edition to use for the new targets
    """
    rust_proc_macro(
        name = "proc_macro_lib_{}".format(edition),
        srcs = [
            "proc_macro_{}.rs".format(edition),
        ],
        edition = edition,
    )

    rust_test(
        name = "proc_macro_lib_{}_unittest".format(edition),
        crate = ":proc_macro_lib_{}".format(edition),
        edition = edition,
    )

    rust_test(
        name = "proc_macro_lib_{}_integration_test".format(edition),
        srcs = ["proc_macro_{}_test.rs".format(edition)],
        edition = edition,
        proc_macro_deps = [":proc_macro_lib_{}".format(edition)],
    )

def _proc_macro_2015_no_extern_flag_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_under_test(env).actions
    action = actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    # Edition 2015 does not use `--extern proc_macro` instead this
    # must be explicitly set in Rust code.
    assert_list_contains_adjacent_elements_not(env, action.argv, ["--extern", "proc_macro"])
    return analysistest.end(env)

def _proc_macro_2018_extern_flag_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_under_test(env).actions
    action = actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    # `--extern proc_macro` is required to resolve build proc-macro
    assert_list_contains_adjacent_elements(env, action.argv, ["--extern", "proc_macro"])
    return analysistest.end(env)

proc_macro_2015_no_extern_flag_test = analysistest.make(_proc_macro_2015_no_extern_flag_impl)
proc_macro_2018_extern_flag_test = analysistest.make(_proc_macro_2018_extern_flag_impl)

def _proc_macro_test():
    """Generate targets and tests"""

    _proc_macro_test_targets("2015")
    _proc_macro_test_targets("2018")

    proc_macro_2015_no_extern_flag_test(
        name = "proc_macro_2015_no_extern_flag_test",
        target_under_test = ":proc_macro_lib_2015",
    )

    proc_macro_2015_no_extern_flag_test(
        name = "proc_macro_test_2015_no_extern_flag_test",
        target_under_test = ":proc_macro_lib_2015_unittest",
    )

    proc_macro_2018_extern_flag_test(
        name = "proc_macro_2018_extern_flag_test",
        target_under_test = ":proc_macro_lib_2018",
    )

    proc_macro_2018_extern_flag_test(
        name = "proc_macro_test_2018_extern_flag_test",
        target_under_test = ":proc_macro_lib_2018_unittest",
    )

def proc_macro_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _proc_macro_test()

    native.test_suite(
        name = name,
        tests = [
            ":proc_macro_2015_no_extern_flag_test",
            ":proc_macro_test_2015_no_extern_flag_test",
            ":proc_macro_2018_extern_flag_test",
            ":proc_macro_test_2018_extern_flag_test",
        ],
    )

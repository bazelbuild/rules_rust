"""Unittest to verify proc-macro targets"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_proc_macro", "rust_test")
load(
    "//test/unit:common.bzl",
    "assert_action_mnemonic",
)

def _proc_macro_does_not_leak_deps_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_under_test(env).actions
    action = actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    # Our test depends on the proc_macro_dep crate both directly and indirectly via a
    # proc_macro dependency. As proc_macro depdendencies are built in exec configuration mode,
    # we check that there isn't an `-exec-` path to `proc_macro_dep` in the command line arguments.
    proc_macro_dep_args = [arg for arg in action.argv if "proc_macro_dep" in arg]
    proc_macro_dep_in_exec_mode = [arg for arg in proc_macro_dep_args if "-exec-" in arg]

    asserts.equals(env, 0, len(proc_macro_dep_in_exec_mode))

    return analysistest.end(env)

proc_macro_does_not_leak_deps_test = analysistest.make(_proc_macro_does_not_leak_deps_impl)

def _proc_macro_does_not_leak_deps_test():
    rust_proc_macro(
        name = "proc_macro_definition",
        srcs = ["leaks_deps/proc_macro_definition.rs"],
        deps = ["//test/unit/proc_macro/leaks_deps/proc_macro_dep"],
    )

    rust_test(
        name = "deps_not_leaked",
        srcs = ["leaks_deps/proc_macro_user.rs"],
        proc_macro_deps = [":proc_macro_definition"],
    )

    proc_macro_does_not_leak_deps_test(
        name = "proc_macro_does_not_leak_deps_test",
        target_under_test = ":deps_not_leaked",
    )

def proc_macro_does_not_leak_deps_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _proc_macro_does_not_leak_deps_test()

    native.test_suite(
        name = name,
        tests = [
            ":proc_macro_does_not_leak_deps_test",
        ],
    )

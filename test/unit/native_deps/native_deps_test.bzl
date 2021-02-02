"""Unittests for rust rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc:defs.bzl", "cc_library")

# buildifier: disable=bzl-visibility
load("//rust/private:rust.bzl", "rust_binary", "rust_library")

def _assert_argv_contains_not(env, action, flag):
    asserts.true(
        env,
        flag not in action.argv,
        "Expected {args} to not contain {flag}".format(args = action.argv, flag = flag),
    )

def _assert_argv_contains(env, action, flag):
    asserts.true(
        env,
        flag in action.argv,
        "Expected {args} to contain {flag}".format(args = action.argv, flag = flag),
    )

def _lib_has_no_native_libs_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    asserts.equals(env, 1, len(actions))
    action = actions[0]
    _assert_argv_contains_not(env, action, "-lstatic=native_dep")
    _assert_argv_contains_not(env, action, "-ldylib=native_dep")
    return analysistest.end(env)

def _rlib_has_no_native_libs_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    asserts.equals(env, 1, len(actions))
    action = actions[0]
    _assert_argv_contains_not(env, action, "-lstatic=native_dep")
    _assert_argv_contains_not(env, action, "-ldylib=native_dep")
    return analysistest.end(env)

def _dylib_has_native_libs_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    action = actions[0]
    _assert_argv_contains(env, action, "-lstatic=native_dep")
    return analysistest.end(env)

def _cdylib_has_native_libs_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    action = actions[0]
    _assert_argv_contains(env, action, "-lstatic=native_dep")
    return analysistest.end(env)

def _staticlib_has_native_libs_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    action = actions[0]
    _assert_argv_contains(env, action, "-lstatic=native_dep")
    return analysistest.end(env)

def _proc_macro_has_native_libs_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    asserts.equals(env, 1, len(actions))
    action = actions[0]
    _assert_argv_contains(env, action, "-lstatic=native_dep")
    return analysistest.end(env)

def _bin_has_native_libs_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    action = actions[0]
    _assert_argv_contains(env, action, "-lstatic=native_dep")
    return analysistest.end(env)

lib_has_no_native_libs_test = analysistest.make(_lib_has_no_native_libs_test_impl)
rlib_has_no_native_libs_test = analysistest.make(_rlib_has_no_native_libs_test_impl)
staticlib_has_native_libs_test = analysistest.make(_staticlib_has_native_libs_test_impl)
dylib_has_native_libs_test = analysistest.make(_dylib_has_native_libs_test_impl)
cdylib_has_native_libs_test = analysistest.make(_cdylib_has_native_libs_test_impl)
proc_macro_has_native_libs_test = analysistest.make(_proc_macro_has_native_libs_test_impl)
bin_has_native_libs_test = analysistest.make(_bin_has_native_libs_test_impl)

def _native_dep_test():
    rust_library(
        name = "lib_has_no_native_dep",
        srcs = ["lib_using_native_dep.rs"],
        deps = [":native_dep"],
        crate_type = "lib",
    )

    rust_library(
        name = "rlib_has_no_native_dep",
        srcs = ["lib_using_native_dep.rs"],
        deps = [":native_dep"],
        crate_type = "rlib",
    )

    rust_library(
        name = "staticlib_has_native_dep",
        srcs = ["lib_using_native_dep.rs"],
        deps = [":native_dep"],
        crate_type = "staticlib",
    )

    rust_library(
        name = "dylib_has_native_dep",
        srcs = ["lib_using_native_dep.rs"],
        deps = [":native_dep"],
        crate_type = "dylib",
    )

    rust_library(
        name = "cdylib_has_native_dep",
        srcs = ["lib_using_native_dep.rs"],
        deps = [":native_dep"],
        crate_type = "cdylib",
    )

    rust_library(
        name = "proc_macro_has_native_dep",
        srcs = ["proc_macro_using_native_dep.rs"],
        deps = [":native_dep"],
        crate_type = "proc-macro",
        edition = "2018",
    )

    rust_binary(
        name = "bin_has_native_dep",
        srcs = ["bin_using_native_dep.rs"],
        deps = [":native_dep"],
    )

    cc_library(
        name = "native_dep",
        srcs = ["native_dep.cc"],
    )

    lib_has_no_native_libs_test(
        name = "lib_has_no_native_libs_test",
        target_under_test = ":lib_has_no_native_dep",
    )
    rlib_has_no_native_libs_test(
        name = "rlib_has_no_native_libs_test",
        target_under_test = ":rlib_has_no_native_dep",
    )
    staticlib_has_native_libs_test(
        name = "staticlib_has_native_libs_test",
        target_under_test = ":staticlib_has_native_dep",
    )
    dylib_has_native_libs_test(
        name = "dylib_has_native_libs_test",
        target_under_test = ":dylib_has_native_dep",
    )
    cdylib_has_native_libs_test(
        name = "cdylib_has_native_libs_test",
        target_under_test = ":cdylib_has_native_dep",
    )
    proc_macro_has_native_libs_test(
        name = "proc_macro_has_native_libs_test",
        target_under_test = ":proc_macro_has_native_dep",
    )
    bin_has_native_libs_test(
        name = "bin_has_native_libs_test",
        target_under_test = ":bin_has_native_dep",
    )

def native_deps_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _native_dep_test()

    native.test_suite(
        name = name,
        tests = [
            ":lib_has_no_native_libs_test",
            ":rlib_has_no_native_libs_test",
            ":staticlib_has_native_libs_test",
            ":dylib_has_native_libs_test",
            ":cdylib_has_native_libs_test",
            ":proc_macro_has_native_libs_test",
            ":bin_has_native_libs_test",
        ],
    )

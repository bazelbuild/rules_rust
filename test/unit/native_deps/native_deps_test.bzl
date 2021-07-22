"""Unittests for rust rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc:defs.bzl", "cc_library")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_proc_macro", "rust_shared_library", "rust_static_library")
load("//test/unit:common.bzl", "assert_argv_contains", "assert_argv_contains_not", "assert_argv_contains_prefix_suffix")

def _native_dep_lib_name(ctx):
    if ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]):
        return "native_dep.lib"
    else:
        return "libnative_dep.a"

def _lib_has_no_native_libs_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    action = actions[0]
    assert_argv_contains(env, action, "--crate-type=lib")
    assert_argv_contains_prefix_suffix(env, action, "-Lnative=", "/native_deps")
    assert_argv_contains_not(env, action, "-lstatic=native_dep")
    assert_argv_contains_not(env, action, "-ldylib=native_dep")
    return analysistest.end(env)

def _rlib_has_no_native_libs_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    action = actions[0]
    assert_argv_contains(env, action, "--crate-type=rlib")
    assert_argv_contains_not(env, action, "-lstatic=native_dep")
    assert_argv_contains_not(env, action, "-ldylib=native_dep")
    return analysistest.end(env)

def _dylib_has_native_libs_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    action = actions[0]
    assert_argv_contains(env, action, "--crate-type=dylib")
    assert_argv_contains(env, action, "-lstatic=native_dep")
    return analysistest.end(env)

def _cdylib_has_native_libs_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    action = actions[0]
    assert_argv_contains(env, action, "--crate-type=cdylib")
    assert_argv_contains_prefix_suffix(env, action, "link-arg=", "/native_deps/" + _native_dep_lib_name(ctx))
    return analysistest.end(env)

def _staticlib_has_native_libs_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    action = actions[0]
    assert_argv_contains(env, action, "--crate-type=staticlib")
    assert_argv_contains_prefix_suffix(env, action, "link-arg=", "/native_deps/" + _native_dep_lib_name(ctx))
    return analysistest.end(env)

def _proc_macro_has_native_libs_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    asserts.equals(env, 1, len(actions))
    action = actions[0]
    assert_argv_contains(env, action, "--crate-type=proc-macro")
    assert_argv_contains_prefix_suffix(env, action, "link-arg=", "/native_deps/" + _native_dep_lib_name(ctx))
    return analysistest.end(env)

def _bin_has_native_libs_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    action = actions[0]
    assert_argv_contains_prefix_suffix(env, action, "link-arg=", "/native_deps/" + _native_dep_lib_name(ctx))
    return analysistest.end(env)

def _extract_linker_args(argv):
    return [a for a in argv if (
        a.startswith("link-arg=") or
        a.startswith("link-args=") or
        a.startswith("-l") or
        a.endswith(".lo") or
        a.endswith(".o")
    )]

def _bin_has_native_dep_and_alwayslink_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    action = actions[0]

    if ctx.target_platform_has_constraint(ctx.attr._macos_constraint[platform_common.ConstraintValueInfo]):
        want = [
            "link-arg=bazel-out/darwin-fastbuild/bin/test/unit/native_deps/libnative_dep.a",
            "link-arg=-Wl,-force_load,bazel-out/darwin-fastbuild/bin/test/unit/native_deps/libalwayslink.lo",
        ]
    elif ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]):
        want = [
            "link-arg=bazel-out/x64_windows-fastbuild/bin/test/unit/native_deps/native_dep.lib",
            "link-arg=/WHOLEARCHIVE:bazel-out/x64_windows-fastbuild/bin/test/unit/native_deps/alwayslink.lo.lib",
        ]
    else:
        want = [
            "link-arg=bazel-out/k8-fastbuild/bin/test/unit/native_deps/libnative_dep.a",
            "link-arg=-Wl,--whole-archive",
            "link-arg=bazel-out/k8-fastbuild/bin/test/unit/native_deps/libalwayslink.lo",
            "link-arg=-Wl,--no-whole-archive",
        ]
    individual_link_args = [
        arg
        for arg in _extract_linker_args(action.argv)
        if arg.startswith("link-arg=")
    ]
    asserts.equals(env, want, individual_link_args)
    return analysistest.end(env)

def _cdylib_has_native_dep_and_alwayslink_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    action = actions[0]

    if ctx.target_platform_has_constraint(ctx.attr._macos_constraint[platform_common.ConstraintValueInfo]):
        want = [
            "-lstatic=native_dep",
            "link-arg=-Wl,-force_load,bazel-out/darwin-fastbuild/bin/test/unit/native_deps/libalwayslink.lo",
        ]
    elif ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]):
        want = [
            "-lstatic=native_dep",
            "link-arg=/WHOLEARCHIVE:bazel-out/x64_windows-fastbuild/bin/test/unit/native_deps/alwayslink.lo.lib",
        ]
    else:
        want = [
            "link-arg=bazel-out/k8-fastbuild/bin/test/unit/native_deps/libnative_dep.a",
            "link-arg=-Wl,--whole-archive",
            "link-arg=bazel-out/k8-fastbuild/bin/test/unit/native_deps/libalwayslink.lo",
            "link-arg=-Wl,--no-whole-archive",
        ]
    asserts.equals(env, want, _extract_linker_args(action.argv))
    return analysistest.end(env)

rlib_has_no_native_libs_test = analysistest.make(_rlib_has_no_native_libs_test_impl)
staticlib_has_native_libs_test = analysistest.make(_staticlib_has_native_libs_test_impl, attrs = {
    "_macos_constraint": attr.label(default = Label("@platforms//os:macos")),
    "_windows_constraint": attr.label(default = Label("@platforms//os:windows")),
})
cdylib_has_native_libs_test = analysistest.make(_cdylib_has_native_libs_test_impl, attrs = {
    "_macos_constraint": attr.label(default = Label("@platforms//os:macos")),
    "_windows_constraint": attr.label(default = Label("@platforms//os:windows")),
})
proc_macro_has_native_libs_test = analysistest.make(_proc_macro_has_native_libs_test_impl, attrs = {
    "_macos_constraint": attr.label(default = Label("@platforms//os:macos")),
    "_windows_constraint": attr.label(default = Label("@platforms//os:windows")),
})
bin_has_native_libs_test = analysistest.make(_bin_has_native_libs_test_impl, attrs = {
    "_macos_constraint": attr.label(default = Label("@platforms//os:macos")),
    "_windows_constraint": attr.label(default = Label("@platforms//os:windows")),
})
bin_has_native_dep_and_alwayslink_test = analysistest.make(_bin_has_native_dep_and_alwayslink_test_impl, attrs = {
    "_macos_constraint": attr.label(default = Label("@platforms//os:macos")),
    "_windows_constraint": attr.label(default = Label("@platforms//os:windows")),
})
cdylib_has_native_dep_and_alwayslink_test = analysistest.make(_cdylib_has_native_libs_test_impl, attrs = {
    "_macos_constraint": attr.label(default = Label("@platforms//os:macos")),
    "_windows_constraint": attr.label(default = Label("@platforms//os:windows")),
})

def _native_dep_test():
    rust_library(
        name = "rlib_has_no_native_dep",
        srcs = ["lib_using_native_dep.rs"],
        deps = [":native_dep"],
    )

    rust_static_library(
        name = "staticlib_has_native_dep",
        srcs = ["lib_using_native_dep.rs"],
        deps = [":native_dep"],
    )

    rust_shared_library(
        name = "cdylib_has_native_dep",
        srcs = ["lib_using_native_dep.rs"],
        deps = [":native_dep"],
    )

    rust_proc_macro(
        name = "proc_macro_has_native_dep",
        srcs = ["proc_macro_using_native_dep.rs"],
        deps = [":native_dep"],
        edition = "2018",
    )

    rust_binary(
        name = "bin_has_native_dep",
        srcs = ["bin_using_native_dep.rs"],
        deps = [":native_dep"],
    )

    rust_binary(
        name = "bin_has_native_dep_and_alwayslink",
        srcs = ["bin_using_native_dep.rs"],
        deps = [":native_dep", ":alwayslink"],
    )

    cc_library(
        name = "native_dep",
        srcs = ["native_dep.cc"],
        visibility = ["//test/unit:__subpackages__"],
    )

    cc_library(
        name = "alwayslink",
        srcs = ["alwayslink.cc"],
        alwayslink = 1,
    )

    rust_shared_library(
        name = "cdylib_has_native_dep_and_alwayslink",
        srcs = ["lib_using_native_dep.rs"],
        deps = [":native_dep", ":alwayslink"],
    )

    rlib_has_no_native_libs_test(
        name = "rlib_has_no_native_libs_test",
        target_under_test = ":rlib_has_no_native_dep",
    )
    staticlib_has_native_libs_test(
        name = "staticlib_has_native_libs_test",
        target_under_test = ":staticlib_has_native_dep",
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
    bin_has_native_dep_and_alwayslink_test(
        name = "bin_has_native_dep_and_alwayslink_test",
        target_under_test = ":bin_has_native_dep_and_alwayslink",
    )
    cdylib_has_native_dep_and_alwayslink_test(
        name = "cdylib_has_native_dep_and_alwayslink_test",
        target_under_test = ":cdylib_has_native_dep_and_alwayslink",
    )

def _linkopts_propagate_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    action = actions[0]

    # Ensure linkopts from direct (-Llinkoptdep1) and transitive
    # (-Llinkoptdep2) dependencies are propagated.
    linkopt_1_found = False
    linkopt_2_found = False
    for arg in _extract_linker_args(action.argv):
        linkopt_1_found = linkopt_1_found or ("-Llinkoptdep1" in arg)
        linkopt_2_found = linkopt_2_found or ("-Llinkoptdep2" in arg)
    asserts.true(env, linkopt_1_found and linkopt_2_found)
    return analysistest.end(env)

linkopts_propagate_test = analysistest.make(_linkopts_propagate_test_impl)

def _linkopts_test():
    rust_binary(
        name = "linkopts_rust_bin",
        srcs = ["bin_using_native_dep.rs"],
        deps = [":linkopts_native_dep_a"],
    )

    cc_library(
        name = "linkopts_native_dep_a",
        srcs = ["native_dep.cc"],
        linkopts = ["-Llinkoptdep1"],
        deps = [":linkopts_native_dep_b"],
    )

    cc_library(
        name = "linkopts_native_dep_b",
        linkopts = ["-Llinkoptdep2"],
    )

    linkopts_propagate_test(
        name = "native_linkopts_propagate_test",
        target_under_test = ":linkopts_rust_bin",
    )

def native_deps_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _native_dep_test()
    _linkopts_test()

    native.test_suite(
        name = name,
        tests = [
            ":rlib_has_no_native_libs_test",
            ":staticlib_has_native_libs_test",
            ":cdylib_has_native_libs_test",
            ":proc_macro_has_native_libs_test",
            ":bin_has_native_libs_test",
            ":bin_has_native_dep_and_alwayslink_test",
            ":cdylib_has_native_dep_and_alwayslink_test",
            ":native_linkopts_propagate_test",
        ],
    )

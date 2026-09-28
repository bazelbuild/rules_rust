"""Unittests for ambiguous native dependencies."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load(
    "//rust:defs.bzl",
    "rust_binary",
    "rust_common",
    "rust_library",
    "rust_proc_macro",
    "rust_shared_library",
    "rust_static_library",
)

def _get_crate_info(target):
    return target[rust_common.crate_info] if rust_common.crate_info in target else target[rust_common.test_crate_info].crate

def _get_pic_suffix(ctx, for_shared_library):
    if ctx.target_platform_has_constraint(
        ctx.attr._windows_constraint[platform_common.ConstraintValueInfo],
    ) or ctx.target_platform_has_constraint(
        ctx.attr._macos_constraint[platform_common.ConstraintValueInfo],
    ):
        return ""
    else:
        compilation_mode = ctx.var["COMPILATION_MODE"]
        return ".pic" if compilation_mode == "opt" and for_shared_library else ""

# The same impl is shared among all tests in this file.
def _ambiguous_deps_test_impl(env, target):
    for_shared_library = _get_crate_info(target).type in ("dylib", "cdylib", "proc-macro")
    extension = _get_pic_suffix(env.ctx, for_shared_library)

    # We depend on two C++ libraries named "native_dep", which we need to pass to the command line
    # in the form of "-lstatic=native-dep-{hash}.pic".
    expect_link_args = env.expect.that_target(target).action_named("Rustc").argv().transform(
        desc = "keep only native deps",
        filter = lambda arg: arg.startswith("-lstatic=native_dep-"),
    )
    expect_link_args.has_size(2)

    # TODO: CollectionSubject.contains_no_duplicates is available at HEAD rules_testing, but not in
    # any released version yet. So we need to get both elements and compare them manually.
    arg0 = expect_link_args.offset(0, lambda x, meta: x)
    arg1 = expect_link_args.offset(1, lambda x, meta: x)
    if arg0 == arg1:
        env.fail("Expected two different '-lstatic=native_dep-' arguments, found two instances of '{}'".format(arg0))

    # There's no CollectionSubject method to check that all elements match a predicate, but there's
    # not_contains_predicate, so we do this weird double negation.
    expect_link_args.not_contains_predicate(
        matching.custom("does not end with the desired extension", lambda arg: not arg.endswith(extension)),
    )


def _bin_with_ambiguous_deps_test(name):
    rust_library(
        name = name + "_rlib_with_ambiguous_deps",
        srcs = ["foo.rs"],
        edition = "2018",
        link_deps = [
            "//test/unit/ambiguous_libs/first_dep:native_dep",
            "//test/unit/ambiguous_libs/second_dep:native_dep",
        ],
        tags = ["manual"],
    )
    rust_binary(
        name = name + "_binary",
        srcs = ["bin.rs"],
        edition = "2018",
        deps = [name + "_rlib_with_ambiguous_deps"],
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        target = name + "_binary",
        attrs = {
            "_macos_constraint": attr.label(default = Label("@platforms//os:macos")),
            "_windows_constraint": attr.label(default = Label("@platforms//os:windows")),
        },
        impl = _ambiguous_deps_test_impl,
    )

def _staticlib_with_ambiguous_deps_test(name):
    rust_library(
        name = name + "_rlib_with_ambiguous_deps",
        srcs = ["foo.rs"],
        edition = "2018",
        link_deps = [
            "//test/unit/ambiguous_libs/first_dep:native_dep",
            "//test/unit/ambiguous_libs/second_dep:native_dep",
        ],
        tags = ["manual"],
    )
    rust_static_library(
        name = name + "_static_library",
        srcs = ["foo.rs"],
        edition = "2018",
        deps = [name + "_rlib_with_ambiguous_deps"],
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        target = name + "_static_library",
        attrs = {
            "_macos_constraint": attr.label(default = Label("@platforms//os:macos")),
            "_windows_constraint": attr.label(default = Label("@platforms//os:windows")),
        },
        impl = _ambiguous_deps_test_impl,
    )

def _proc_macro_with_ambiguous_deps_test(name):
    rust_library(
        name = name + "_rlib_with_ambiguous_deps",
        srcs = ["foo.rs"],
        edition = "2018",
        link_deps = [
            "//test/unit/ambiguous_libs/first_dep:native_dep",
            "//test/unit/ambiguous_libs/second_dep:native_dep",
        ],
        tags = ["manual"],
    )
    rust_proc_macro(
        name = name + "_proc_macro",
        srcs = ["foo.rs"],
        edition = "2018",
        deps = [name + "_rlib_with_ambiguous_deps"],
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        target = name + "_proc_macro",
        attrs = {
            "_macos_constraint": attr.label(default = Label("@platforms//os:macos")),
            "_windows_constraint": attr.label(default = Label("@platforms//os:windows")),
        },
        impl = _ambiguous_deps_test_impl,
    )

def _cdylib_with_ambiguous_deps_test(name):
    rust_library(
        name = name + "_rlib_with_ambiguous_deps",
        srcs = ["foo.rs"],
        edition = "2018",
        link_deps = [
            "//test/unit/ambiguous_libs/first_dep:native_dep",
            "//test/unit/ambiguous_libs/second_dep:native_dep",
        ],
        tags = ["manual"],
    )
    rust_shared_library(
        name = name + "_shared_library",
        srcs = ["foo.rs"],
        edition = "2018",
        deps = [name + "_rlib_with_ambiguous_deps"],
        tags = ["manual"],
    )
    analysis_test(
        name = name,
        target = name + "_shared_library",
        attrs = {
            "_macos_constraint": attr.label(default = Label("@platforms//os:macos")),
            "_windows_constraint": attr.label(default = Label("@platforms//os:windows")),
        },
        impl = _ambiguous_deps_test_impl,
    )

def ambiguous_libs_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    test_suite(
        name = name,
        tests = [
            _bin_with_ambiguous_deps_test,
            _staticlib_with_ambiguous_deps_test,
            _proc_macro_with_ambiguous_deps_test,
            _cdylib_with_ambiguous_deps_test,
        ],
    )

"""Unit tests for rust_library_group."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load(
    "//rust:defs.bzl",
    "rust_common",
    "rust_library",
    "rust_library_group",
    "rust_proc_macro",
    "rust_test",
)

def _crate_group_info_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    asserts.true(
        env,
        rust_common.crate_group_info in target,
        "{} should provide CrateGroupInfo".format(target.label),
    )

    dep_variant_infos = target[rust_common.crate_group_info].dep_variant_infos.to_list()
    crate_names = []
    for dep_variant_info in dep_variant_infos:
        asserts.true(env, dep_variant_info.crate_info != None)
        asserts.true(env, dep_variant_info.dep_info != None)
        asserts.equals(env, None, dep_variant_info.crate_group_info)
        crate_names.append(dep_variant_info.crate_info.name)

    asserts.equals(env, sorted(ctx.attr.expected_crate_names), sorted(crate_names))
    return analysistest.end(env)

crate_group_info_test = analysistest.make(
    _crate_group_info_test_impl,
    attrs = {
        "expected_crate_names": attr.string_list(),
    },
)

def rust_library_group_test_suite(name):
    """Defines tests for rust_library_group.

    Args:
        name: The test suite name.
    """
    rust_proc_macro(
        name = "proc_dep1",
        srcs = ["proc_dep1.rs"],
        edition = "2021",
    )

    rust_library_group(
        name = "proc_group",
        deps = [":proc_dep1"],
    )

    rust_library(
        name = "dep1",
        srcs = ["dep1.rs"],
        edition = "2021",
    )

    rust_library(
        name = "dep2",
        srcs = ["dep2.rs"],
        edition = "2021",
    )

    rust_library_group(
        name = "dep1_and_2",
        deps = [
            ":dep1",
            ":dep2",
        ],
    )

    rust_library_group(
        name = "nested_group",
        deps = [":dep1_and_2"],
    )

    rust_library(
        name = "library",
        srcs = ["lib.rs"],
        edition = "2021",
        proc_macro_deps = [":proc_group"],
        deps = [":dep1_and_2"],
    )

    rust_test(
        name = "test",
        srcs = ["test.rs"],
        edition = "2021",
        proc_macro_deps = [":proc_group"],
        deps = [":dep1_and_2"],
    )

    crate_group_info_test(
        name = "nested_group_info_test",
        target_under_test = ":nested_group",
        expected_crate_names = ["dep1", "dep2"],
    )

    crate_group_info_test(
        name = "proc_group_info_test",
        target_under_test = ":proc_group",
        expected_crate_names = ["proc_dep1"],
    )

    native.test_suite(
        name = name,
        tests = [
            ":nested_group_info_test",
            ":proc_group_info_test",
            ":test",
        ],
    )

"""Unittests for rust rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_proc_macro", "rust_test")

_TARGETS = [
    struct(name = "bin", rule = rust_binary, srcs = ["bin.rs"]),
    struct(name = "lib", rule = rust_library, srcs = ["lib.rs"]),
    struct(name = "macro", rule = rust_proc_macro, srcs = ["macro.rs"]),
    struct(name = "unit", rule = rust_test, srcs = ["unit.rs"]),
]

def _metadata_output_groups_present_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    output_groups = tut[OutputGroupInfo]
    build_metadata = output_groups.build_metadata.to_list()
    rustc_rmeta_output = output_groups.rustc_rmeta_output.to_list()

    asserts.equals(env, 1, len(build_metadata), "Expected 1 build_metadata file")
    asserts.true(
        env,
        build_metadata[0].basename.endswith("_meta.rlib"),
        "Expected %s to end with _meta.rlib" % build_metadata[0],
    )

    asserts.equals(env, 1, len(rustc_rmeta_output), "Expected 1 rustc_rmeta_output file")
    asserts.true(
        env,
        rustc_rmeta_output[0].basename.endswith(".rustc-output"),
        "Expected %s to end with .rustc-output" % rustc_rmeta_output[0],
    )

    return analysistest.end(env)

def _metadata_output_groups_missing_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    output_groups = tut[OutputGroupInfo]
    asserts.false(env, hasattr(output_groups, "build_metadata"), "Expected no build_metadata output group")
    asserts.false(env, hasattr(output_groups, "rustc_rmeta_output"), "Expected no rustc_rmeta_output output group")

    return analysistest.end(env)

metadata_output_groups_present_test = analysistest.make(
    _metadata_output_groups_present_test_impl,
    config_settings = {
        str(Label("//rust/settings:always_enable_metadata_output_groups")): True,
        str(Label("//rust/settings:rustc_output_diagnostics")): True,
    },
)

metadata_output_groups_missing_test = analysistest.make(
    _metadata_output_groups_missing_test_impl,
)

def _output_groups_test(*, always_enable, suffix, present_test = None):
    test = present_test if always_enable else metadata_output_groups_missing_test

    for target in _TARGETS:
        target.rule(
            name = target.name + suffix,
            srcs = target.srcs,
            edition = "2021",
        )

        test(
            name = target.name + "_test" + suffix,
            target_under_test = ":" + target.name + suffix,
        )

    return [
        ":" + target.name + "_test" + suffix
        for target in _TARGETS
    ]

def metadata_output_groups_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    tests = []
    tests.extend(_output_groups_test(
        always_enable = True,
        suffix = "_with_metadata",
        present_test = metadata_output_groups_present_test,
    ))
    tests.extend(_output_groups_test(
        always_enable = False,
        suffix = "_without_metadata",
    ))

    native.test_suite(
        name = name,
        tests = tests,
    )

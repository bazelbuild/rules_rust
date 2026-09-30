"""Unittests for the `aliases` attribute, including aliases produced by custom alias rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//rust:defs.bzl", "rust_common", "rust_library")

def _forwarding_alias_impl(ctx):
    actual = ctx.attr.actual
    providers = []
    if rust_common.crate_info in actual:
        providers.append(actual[rust_common.crate_info])
    if rust_common.dep_info in actual:
        providers.append(actual[rust_common.dep_info])
    if CcInfo in actual:
        providers.append(actual[CcInfo])
    if DefaultInfo in actual:
        providers.append(actual[DefaultInfo])
    return providers

# A custom alias rule that forwards a Rust crate's providers without adjusting
# `CrateInfo.owner`. The rule's own label differs from `CrateInfo.owner`, which
# is what previously broke lookup in `collect_deps`.
_forwarding_alias = rule(
    implementation = _forwarding_alias_impl,
    attrs = {
        "actual": attr.label(
            mandatory = True,
            providers = [rust_common.crate_info],
        ),
    },
)

def _assert_extern(env, action, expected):
    for arg in action.argv:
        if arg.startswith("--extern=") and arg.split("=", 2)[1] == expected:
            return
    asserts.true(
        env,
        False,
        "Expected an `--extern={}=...` flag in {}".format(expected, action.argv),
    )

def _aliases_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    rustc_action = [action for action in tut.actions if action.mnemonic == "Rustc"][0]

    # Both the direct `rust_library` dep and the dep going through a custom
    # alias rule should be renamed according to the `aliases` attribute.
    _assert_extern(env, rustc_action, "renamed_foo")
    _assert_extern(env, rustc_action, "renamed_bar")

    return analysistest.end(env)

_aliases_test = analysistest.make(_aliases_test_impl)

def aliases_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): The name of the test suite.
    """
    rust_library(
        name = "foo",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    rust_library(
        name = "bar",
        srcs = ["bar.rs"],
        edition = "2018",
    )

    _forwarding_alias(
        name = "bar_alias",
        actual = ":bar",
    )

    rust_library(
        name = "consumer",
        srcs = ["consumer.rs"],
        edition = "2018",
        deps = [
            ":foo",
            ":bar_alias",
        ],
        aliases = {
            ":bar_alias": "renamed_bar",
            ":foo": "renamed_foo",
        },
    )

    _aliases_test(
        name = "aliases_test",
        target_under_test = ":consumer",
    )

    native.test_suite(
        name = name,
        tests = [
            ":aliases_test",
        ],
    )

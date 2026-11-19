"""Unittests for the `aliases` attribute, including aliases produced by custom alias rules."""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")
load("@rules_testing//lib:util.bzl", "util")
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

def _aliases_test_impl(env, target):
    rustc_action = [action for action in target.actions if action.mnemonic == "Rustc"][0]

    # Both the direct `rust_library` dep and the dep going through a custom
    # alias rule should be renamed according to the `aliases` attribute.
    env.expect.that_action(rustc_action).argv().contains_predicate(
        matching.str_startswith("--extern=renamed_foo="),
    )
    env.expect.that_action(rustc_action).argv().contains_predicate(
        matching.str_startswith("--extern=renamed_bar="),
    )

def _aliases_test(name):
    util.helper_target(
        rust_library,
        name = name + "_foo",
        srcs = ["foo.rs"],
        edition = "2018",
    )

    util.helper_target(
        rust_library,
        name = name + "_bar",
        srcs = ["bar.rs"],
        edition = "2018",
    )

    util.helper_target(
        _forwarding_alias,
        name = name + "_bar_alias",
        actual = ":" + name + "_bar",
    )

    util.helper_target(
        rust_library,
        name = name + "_consumer",
        srcs = ["consumer.rs"],
        edition = "2018",
        deps = [
            ":" + name + "_foo",
            ":" + name + "_bar_alias",
        ],
        aliases = {
            ":" + name + "_bar_alias": "renamed_bar",
            ":" + name + "_foo": "renamed_foo",
        },
    )

    analysis_test(
        name = name,
        target = ":" + name + "_consumer",
        impl = _aliases_test_impl,
    )

def aliases_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): The name of the test suite.
    """
    test_suite(
        name = name,
        tests = [
            _aliases_test,
        ],
    )

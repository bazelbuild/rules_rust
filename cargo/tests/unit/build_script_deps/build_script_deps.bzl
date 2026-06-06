"""Analysis tests for cargo_build_script."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("//cargo:defs.bzl", "cargo_build_script")
load("//rust:defs.bzl", "rust_library")

_USE_LIBTOOL_ON_MACOS = "@rules_cc//cc/toolchains/args/archiver_flags:use_libtool_on_macos"

DepActionsInfo = provider(
    "Contains information about dependencies' actions.",
    fields = {"actions": "List[Action]"},
)

def _collect_dep_actions_aspect_impl(target, ctx):
    actions = []
    actions.extend(target.actions)
    for attr_name in ("deps", "script"):
        if not hasattr(ctx.rule.attr, attr_name):
            continue
        deps = getattr(ctx.rule.attr, attr_name)
        if type(deps) != "list":
            deps = [deps]
        for dep in deps:
            if DepActionsInfo in dep:
                actions.extend(dep[DepActionsInfo].actions)
    return [DepActionsInfo(actions = actions)]

collect_dep_actions_aspect = aspect(
    implementation = _collect_dep_actions_aspect_impl,
    attr_aspects = ["deps", "script"],
)

def _outputs_contain(outputs, substring):
    for output in outputs.to_list():
        if substring in output.path:
            return True
    return False

def _build_script_deps_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    build_script_deps_action = [
        action
        for action in target[DepActionsInfo].actions
        if _outputs_contain(action.outputs, "dep_of_a_build_script")
    ][0]

    rlib_output = [
        output
        for output in build_script_deps_action.outputs.to_list()
        if output.path.endswith(".rlib")
    ][0]

    asserts.true(
        env,
        ("-exec-" in rlib_output.path) or ("-exec/bin/" in rlib_output.path),
        "Expected rlib output to be in an exec configuration, but got: {}".format(rlib_output.path),
    )
    asserts.true(
        env,
        "--codegen=opt-level=0" in build_script_deps_action.argv,
        "Expected build script dependencies to use the incoming fastbuild compilation mode, but got: {}".format(
            build_script_deps_action.argv,
        ),
    )
    return analysistest.end(env)

build_script_deps_test = analysistest.make(
    _build_script_deps_test_impl,
    extra_target_under_test_aspects = [collect_dep_actions_aspect],
)

def _disable_use_libtool_on_macos_transition_impl(_settings, _attr):
    return {_USE_LIBTOOL_ON_MACOS: False}

_disable_use_libtool_on_macos_transition = transition(
    implementation = _disable_use_libtool_on_macos_transition_impl,
    inputs = [],
    outputs = [_USE_LIBTOOL_ON_MACOS],
)

def _with_use_libtool_on_macos_disabled_impl(ctx):
    return [ctx.attr.target[0][DefaultInfo]]

with_use_libtool_on_macos_disabled = rule(
    implementation = _with_use_libtool_on_macos_disabled_impl,
    attrs = {
        "target": attr.label(cfg = _disable_use_libtool_on_macos_transition),
        "_allowlist_function_transition": attr.label(
            default = Label("//tools/allowlists/function_transition_allowlist"),
        ),
    },
)

def build_script_test_suite(name):
    """Build script analysis tests.

    Args:
        name: the test suite name
    """
    rust_library(
        name = "dep_of_a_build_script",
        srcs = ["lib.rs"],
        edition = "2021",
        rustc_flags = select({
            ":use_libtool_on_macos": ["--cfg=expected_use_libtool_on_macos"],
            "//conditions:default": [],
        }),
    )

    cargo_build_script(
        name = "build_script_deps_in_exec_mode",
        srcs = ["build.rs"],
        deps = [":dep_of_a_build_script"],
        edition = "2021",
    )

    build_script_deps_test(
        name = "build_script_deps_in_exec_mode_test",
        target_under_test = ":build_script_deps_in_exec_mode",
    )

    build_test(
        name = "build_script_restores_default_use_libtool_test",
        targets = [":build_script_deps_in_exec_mode"],
    )

    rust_library(
        name = "dep_of_a_build_script_without_libtool",
        srcs = ["lib_without_libtool.rs"],
        edition = "2021",
        rustc_flags = select({
            ":use_libtool_on_macos": [],
            "//conditions:default": ["--cfg=expected_use_libtool_on_macos"],
        }),
        tags = ["manual"],
    )

    cargo_build_script(
        name = "build_script_without_libtool",
        srcs = ["build.rs"],
        deps = [":dep_of_a_build_script_without_libtool"],
        edition = "2021",
        tags = ["manual"],
    )

    with_use_libtool_on_macos_disabled(
        name = "build_script_without_libtool_disabled",
        target = ":build_script_without_libtool",
        tags = ["manual"],
    )

    build_test(
        name = "build_script_restores_disabled_use_libtool_test",
        targets = [":build_script_without_libtool_disabled"],
    )

    native.test_suite(
        name = name,
        tests = [
            "build_script_deps_in_exec_mode_test",
            "build_script_restores_default_use_libtool_test",
            "build_script_restores_disabled_use_libtool_test",
        ],
    )

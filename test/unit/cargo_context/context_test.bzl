"""Preserve Cargo target identity across real compiler transitions (issue #4300)."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("//cargo:defs.bzl", "cargo_build_script")
load("//rust:defs.bzl", "rust_library", "rust_proc_macro")

# The unit test exercises the private transition directly.
# buildifier: disable=bzl-visibility
load("//rust/private:cargo_context.bzl", "CARGO_TARGET", "cargo_context")

_ContextInfo = provider("Cargo context observed on configured dependencies.", fields = {"values": "Cargo context for each configured Rust target"})

def _aspect_impl(_target, ctx):
    values = {ctx.label.name: ctx.attr._context[BuildSettingInfo].value}
    for attr_name in ["deps", "proc_macro_deps", "script"]:
        deps = getattr(ctx.rule.attr, attr_name, [])
        if type(deps) != "list":
            deps = [deps] if deps else []
        for dep in deps:
            if _ContextInfo in dep:
                values.update(dep[_ContextInfo].values)
    return [_ContextInfo(values = values)]

_context_aspect = aspect(
    implementation = _aspect_impl,
    attr_aspects = ["deps", "proc_macro_deps", "script"],
    attrs = {"_context": attr.label(default = CARGO_TARGET)},
)

def _probe_impl(ctx):
    return [
        _ContextInfo(values = ctx.attr.dep[_ContextInfo].values),
        DefaultInfo(files = depset()),
    ]

_probe = rule(implementation = _probe_impl, attrs = {"dep": attr.label(aspects = [_context_aspect])})

def _check_impl(ctx):
    env = analysistest.begin(ctx)
    values = analysistest.target_under_test(env)[_ContextInfo].values
    asserts.equals(env, ctx.attr.expected_target, values["lib"])
    asserts.equals(env, ctx.attr.expected_exec, values["macro"])
    asserts.equals(env, ctx.attr.expected_exec, values["host_dep"])
    asserts.equals(env, ctx.attr.expected_exec, values["build_script_"])
    return analysistest.end(env)

_check_attrs = {"expected_exec": attr.string(), "expected_target": attr.string()}
_default_test = analysistest.make(_check_impl, attrs = _check_attrs)
_native_test = analysistest.make(_check_impl, attrs = _check_attrs, config_settings = {CARGO_TARGET: "target/aarch64-apple-darwin"})
_cross_test = analysistest.make(_check_impl, attrs = _check_attrs, config_settings = {CARGO_TARGET: "target/x86_64-unknown-linux-gnu", "//command_line_option:extra_toolchains": [str(Label("//test/unit/cargo_context:linux_cc"))], "//command_line_option:platforms": str(Label("//test/unit/cargo_context:linux"))})

def _mapping_impl(ctx):
    env = unittest.begin(ctx)
    attr = struct(cargo_target_triple_map = {"": "must-not-enable", "x86_64-unknown-linux-gnu": "shared"})
    for is_exec, value, expected in [
        (False, "target/x86_64-unknown-linux-gnu", "target/x86_64-unknown-linux-gnu"),
        (True, "target/x86_64-unknown-linux-gnu", "shared"),
        (True, "shared", "shared"),
        (True, "", ""),
    ]:
        asserts.equals(env, {CARGO_TARGET: expected}, cargo_context({CARGO_TARGET: value, "//command_line_option:is exec configuration": is_exec}, attr))
    return unittest.end(env)

_mapping_test = unittest.make(_mapping_impl)

def cargo_context_tests(name):
    """Declare target and execution context regression tests.

    Args:
        name: Name of the test suite.
    """
    mapping = {"aarch64-apple-darwin": "shared", "x86_64-unknown-linux-gnu": "shared"}
    rust_library(name = "host_dep", srcs = ["lib.rs"], cargo_target_triple_map = mapping, tags = ["manual"])
    rust_proc_macro(name = "macro", srcs = ["macro.rs"], cargo_target_triple_map = mapping, deps = [":host_dep"], tags = ["manual"])
    cargo_build_script(name = "build_script", srcs = ["build.rs"], cargo_target_triple_map = mapping, tags = ["manual"])
    rust_library(name = "lib", srcs = ["lib.rs"], proc_macro_deps = [":macro"], deps = [":build_script"], cargo_target_triple_map = mapping, tags = ["manual"])
    _probe(name = "probe", dep = ":lib", tags = ["manual"])
    _default_test(name = "default_test", target_under_test = ":probe")
    _native_test(name = "native_test", target_under_test = ":probe", expected_target = "target/aarch64-apple-darwin", expected_exec = "shared")
    _cross_test(name = "cross_test", target_under_test = ":probe", expected_target = "target/x86_64-unknown-linux-gnu", expected_exec = "shared")
    _mapping_test(name = "mapping_test")

    native.test_suite(name = name, tests = [":default_test", ":native_test", ":cross_test", ":mapping_test"])

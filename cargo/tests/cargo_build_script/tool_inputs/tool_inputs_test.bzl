"""Regression coverage for tools referenced by execution path (issue #4297)."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:rust_common.bzl", "rust_common")

def _tool_inputs_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [action for action in analysistest.target_actions(env) if action.mnemonic == "CargoBuildScriptRun"]
    asserts.equals(env, 1, len(actions))
    inputs = [file.path for file in actions[0].inputs.to_list()]
    tool = actions[0].env["CODEGEN"].removeprefix("${pwd}/")
    asserts.true(env, tool in inputs, "Tool execution path is missing: " + tool)

    # The execution tests check runtime data through the tool's own runfiles.
    return analysistest.end(env)

tool_inputs_test = analysistest.make(_tool_inputs_impl)

# Model a compiler incoming transition without depending on a Cargo resolver.
_CONTEXT = "//cargo/tests/cargo_build_script/tool_inputs:script_context"

def _script_context_impl(_settings, _attr):
    return {_CONTEXT: "script"}

_script_context = transition(implementation = _script_context_impl, inputs = [], outputs = [_CONTEXT])

def _transitioned_script_impl(ctx):
    source = ctx.attr.binary
    ext = "." + ctx.executable.binary.extension if ctx.executable.binary.extension else ""
    executable = ctx.actions.declare_file(ctx.label.name + ext)
    ctx.actions.symlink(output = executable, target_file = ctx.executable.binary, is_executable = True)
    return [
        DefaultInfo(executable = executable, runfiles = source[DefaultInfo].default_runfiles),
        source[rust_common.crate_info],
    ]

transitioned_script = rule(
    implementation = _transitioned_script_impl,
    executable = True,
    cfg = _script_context,
    attrs = {
        "binary": attr.label(executable = True, cfg = "target", mandatory = True),
        "_allowlist_function_transition": attr.label(default = "@bazel_tools//tools/allowlists/function_transition_allowlist"),
    },
)

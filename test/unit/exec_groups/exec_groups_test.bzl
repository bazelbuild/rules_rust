"""Rustc runs on the platform its tools are built for."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

_ProbeInfo = provider(
    "A Rust target and the output root of its compiler's execution platform.",
    fields = {"expected_root": "Output root for the compiler platform", "target": "The Rust target"},
)

def _exec_probe_impl(ctx):
    return [
        _ProbeInfo(expected_root = ctx.file.marker.root.path, target = ctx.attr.dep),
        DefaultInfo(files = depset()),
    ]

exec_probe = rule(
    implementation = _exec_probe_impl,
    attrs = {
        "dep": attr.label(),
        "marker": attr.label(allow_single_file = True, cfg = "exec"),
    },
)

def _platform_marker_impl(ctx):
    marker = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(marker, "")
    return [DefaultInfo(files = depset([marker]))]

platform_marker = rule(implementation = _platform_marker_impl)

def _process_wrapper_platform_test_impl(ctx):
    env = analysistest.begin(ctx)
    probe = analysistest.target_under_test(env)[_ProbeInfo]
    rustc = [action for action in probe.target.actions if action.mnemonic == "Rustc"]
    asserts.equals(env, 1, len(rustc))
    process_wrapper = rustc[0].argv[0]
    asserts.true(
        env,
        process_wrapper.startswith(probe.expected_root + "/"),
        "The process wrapper must be built for the platform Rustc runs on: {} (expected under {})".format(process_wrapper, probe.expected_root),
    )
    return analysistest.end(env)

def _proc_macro_platform_test_impl(ctx):
    env = analysistest.begin(ctx)
    probe = analysistest.target_under_test(env)[_ProbeInfo]
    rustc = [action for action in probe.target.actions if action.mnemonic == "Rustc"]
    asserts.equals(env, 1, len(rustc))
    proc_macros = [input.path for input in rustc[0].inputs.to_list() if "libanswer_macro-" in input.basename]
    asserts.equals(env, 1, len(proc_macros))
    asserts.true(
        env,
        proc_macros[0].startswith(probe.expected_root + "/"),
        "A proc-macro must be built for the platform Rustc runs on: {} (expected under {})".format(proc_macros[0], probe.expected_root),
    )
    return analysistest.end(env)

def _make_platform_test(impl, auto_exec_groups):
    return analysistest.make(
        impl,
        config_settings = {
            "//command_line_option:extra_execution_platforms": [
                str(Label(":toolless_platform")),
                str(Label(":compiler_platform")),
            ],
            "//command_line_option:incompatible_auto_exec_groups": auto_exec_groups,
        },
    )

process_wrapper_platform_test = _make_platform_test(_process_wrapper_platform_test_impl, False)

process_wrapper_platform_auto_exec_groups_test = _make_platform_test(_process_wrapper_platform_test_impl, True)

proc_macro_platform_test = _make_platform_test(_proc_macro_platform_test_impl, False)

proc_macro_platform_auto_exec_groups_test = _make_platform_test(_proc_macro_platform_test_impl, True)

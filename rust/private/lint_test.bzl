"""Shared helpers for `rust_clippy_test` and `rustfmt_test`.

Both rules follow the same shape: a thin wrapper aspect that walks
`deps`/`proc_macro_deps`/`crate` and collects the output-group markers
produced by the underlying real aspect (`rust_clippy_aspect` /
`rustfmt_aspect`), plus a rule impl that symlinks a shared runner binary
and hands it the collected marker rlocationpaths via `RUST_LINT_TEST_MARKERS`.

The pieces exposed here — `rlocationpath`, `platform_transition`,
`LINT_TEST_COMMON_ATTRS`, `lint_test_aspect_impl`, `lint_test_rule_impl` —
let each rule file supply only what actually differs (the provider type
and the output-group names it collects).
"""

def rlocationpath(file, workspace_name):
    """Compute the runfile rlocationpath for a File."""
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]
    return "{}/{}".format(workspace_name, file.short_path)

def _platform_transition_impl(_settings, attr):
    if not attr.platform:
        return {}
    platform = str(attr.platform)
    if not platform.startswith("@"):
        platform = "@" + platform
    return {"//command_line_option:platforms": platform}

platform_transition = transition(
    implementation = _platform_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

# Attrs every lint-test rule needs alongside its own `targets`. Callers
# merge this dict into their `attrs = {...}`.
LINT_TEST_COMMON_ATTRS = {
    "platform": attr.label(
        doc = "Optional platform to transition `targets` to before running the aspect. When set, `--platforms` is switched to this label for the duration of this rule's aspect actions.",
    ),
    "transitive": attr.bool(
        doc = "If True (default), lint `targets` and every crate reachable via `deps`, `proc_macro_deps`, and `crate`. If False, lint only the exact targets listed.",
        default = True,
    ),
    "_allowlist_function_transition": attr.label(
        default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
    ),
    "_runner": attr.label(
        doc = "The shared runner (prints/inspects collected marker paths).",
        cfg = "exec",
        executable = True,
        default = Label("//rust/private/lint_test_runner"),
    ),
}

def lint_test_aspect_impl(target, ctx, info_provider, output_group_names):
    """Thin collector: walk deps and roll up the markers the underlying aspect produced.

    Args:
        target: Aspect target.
        ctx: Aspect ctx.
        info_provider: Provider type to read from deps and return.
        output_group_names: List[str] of `OutputGroupInfo` field names to
            collect from the current target (e.g. `["clippy_checks", "clippy_output"]`
            or `["rustfmt_checks"]`).

    Returns:
        A single-element list with a `info_provider(direct_markers, checks)`.
    """
    transitive = []
    for attr_name in ("deps", "proc_macro_deps"):
        for dep in getattr(ctx.rule.attr, attr_name, []):
            if info_provider in dep:
                transitive.append(dep[info_provider].checks)
    crate_dep = getattr(ctx.rule.attr, "crate", None)
    if crate_dep and info_provider in crate_dep:
        transitive.append(crate_dep[info_provider].checks)

    direct = []
    if OutputGroupInfo in target:
        og = target[OutputGroupInfo]
        for name in output_group_names:
            if hasattr(og, name):
                direct = direct + getattr(og, name).to_list()

    return [info_provider(
        direct_markers = direct,
        checks = depset(direct, transitive = transitive),
    )]

def lint_test_rule_impl(ctx, info_provider):
    """Symlink the shared runner and hand it the collected marker rlocationpaths.

    Args:
        ctx: Rule ctx.
        info_provider: Provider carrying `direct_markers` / `checks`.

    Returns:
        DefaultInfo + RunEnvironmentInfo for the test.
    """
    is_windows = ctx.executable._runner.extension == ".exe"
    runner = ctx.actions.declare_file("{}{}".format(
        ctx.label.name,
        ".exe" if is_windows else "",
    ))
    ctx.actions.symlink(
        output = runner,
        target_file = ctx.executable._runner,
        is_executable = True,
    )

    marker_files = []
    check_depsets = []
    for target in ctx.attr.targets:
        if info_provider not in target:
            continue
        info = target[info_provider]
        if ctx.attr.transitive:
            check_depsets.append(info.checks)
        else:
            marker_files.extend(info.direct_markers)

    checks = depset(marker_files, transitive = check_depsets)
    runfiles = ctx.runfiles(transitive_files = checks).merge(
        ctx.attr._runner[DefaultInfo].default_runfiles,
    )

    markers_env = ctx.configuration.host_path_separator.join([
        rlocationpath(f, ctx.workspace_name)
        for f in checks.to_list()
    ])

    return [
        DefaultInfo(
            files = depset([runner]),
            runfiles = runfiles,
            executable = runner,
        ),
        RunEnvironmentInfo(environment = {
            "RUST_BACKTRACE": "1",
            "RUST_LINT_TEST_MARKERS": markers_env,
        }),
    ]

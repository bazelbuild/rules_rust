"""Provides a rule for running binaries with additional runfiles and environment variables."""

load("@aspect_bazel_lib//lib:expand_make_vars.bzl", "expand_variables")
load("@bazel_skylib//lib:dicts.bzl", "dicts")

def _binary_runner_impl(ctx):
    """Implementation of the binary_runner rule.

    This rule creates a symlink to the target binary and sets up the necessary
    runfiles and environment variables for execution.

    Args:
        ctx: The rule context.

    Returns:
        A list containing DefaultInfo and RunEnvironmentInfo providers.
    """
    target_binary = ctx.executable.binary

    runfiles = ctx.runfiles(files = ctx.files.data)
    for dep in ctx.attr.data:
        runfiles = runfiles.merge(dep[DefaultInfo].default_runfiles)

    runfiles = runfiles.merge(ctx.attr.binary[DefaultInfo].default_runfiles)

    # Create a symlink to the target binary
    symlink = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.symlink(
        output = symlink,
        target_file = target_binary,
        is_executable = True,
    )

    # Expand variables in environment values
    expanded_env = {
        key: ctx.expand_location(value, ctx.attr.data)
        for key, value in ctx.attr.env.items()
    }

    # Create RunEnvironmentInfo provider
    run_env = ctx.attr.binary[RunEnvironmentInfo] if RunEnvironmentInfo in ctx.attr.binary else None
    if run_env:
        env = dicts.add(run_env.environment, expanded_env)
    else:
        env = expanded_env

    return [
        DefaultInfo(
            runfiles = runfiles,
            executable = symlink,
        ),
        RunEnvironmentInfo(environment = env),
    ]

binary_runner = rule(
    implementation = _binary_runner_impl,
    attrs = {
        "binary": attr.label(
            mandatory = True,
            executable = True,
            cfg = "target",
            doc = "The binary target to be executed.",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Additional data files or targets to be added to the runfiles.",
        ),
        "env": attr.string_dict(
            doc = """
            A dictionary of environment variables to be set when running the binary.
            Values support '$(location)' expansion and make variable substitution.
            """,
        ),
    },
    executable = True,
    doc = """
    A rule that allows running a binary with additional runfiles and environment variables.

    This rule creates a new target that wraps the given binary, adding specified data
    files to its runfiles and setting additional environment variables for execution.
    Environment variable values support '$(location)' expansion and make variable substitution.

    Example:
        load(":binary_runner.bzl", "binary_runner")

        binary_runner(
            name = "run_my_binary",
            binary = ":my_binary",
            data = [":additional_data_file"],
            env = {
                "MY_ENV_VAR": "value",
                "DATA_PATH": "$(location :additional_data_file)",
                "GENDIR": "$(GENDIR)",
            },
        )
    """,
)

"""Rust executable launcher module"""

# buildifier: disable=bzl-visibility
load("//rust/private:utils.bzl", "expand_dict_value_locations")

def _write_environ(ctx, launcher_filename, env, data):
    file = ctx.actions.declare_file(launcher_filename + ".launchfiles/env")
    environ = expand_dict_value_locations(
        ctx,
        env,
        data,
    )

    # Convert the environment variables into a list to be written into a file.
    environ_list = []
    for key, value in sorted(environ.items()):
        environ_list.extend([key, value])

    ctx.actions.write(
        output = file,
        content = "\n".join(environ_list),
    )

    return file

def _write_args(ctx, launcher_filename, args, data):
    # Convert the arguments list into a dictionary so args can benefit from
    # the existing expand_dict_value_locations functionality
    args_dict = {"{}".format(i): args[i] for i in range(0, len(args))}

    file = ctx.actions.declare_file(launcher_filename + ".launchfiles/args")
    expanded_args = expand_dict_value_locations(
        ctx,
        args_dict,
        data,
    )

    ctx.actions.write(
        output = file,
        content = "\n".join(expanded_args.values()),
    )

    return file

def _write_executable(ctx, launcher_filename, executable = None):
    file = ctx.actions.declare_file(launcher_filename + ".launchfiles/exec")

    ctx.actions.write(
        output = file,
        content = executable.path if executable else "",
    )

    return file

def _merge_providers(ctx, providers, launcher, launcher_files, executable = None):
    # Replace the `DefaultInfo` provider in the returned list
    default_info = None
    for i in range(len(providers)):
        if type(providers[i]) == "DefaultInfo":
            default_info = providers[i]
            providers.pop(i)
            break

    if not default_info:
        fail("list must contain a `DefaultInfo` provider")

    # Additionally update the `OutputGroupInfo` provider
    output_group_info = None
    for i in range(len(providers)):
        if type(providers[i]) == "OutputGroupInfo":
            output_group_info = providers[i]
            providers.pop(i)
            break

    if output_group_info:
        output_group_info = OutputGroupInfo(
            launcher_files = depset(launcher_files),
            output = depset([executable or default_info.files_to_run.executable]),
            **output_group_info
        )
    else:
        output_group_info = OutputGroupInfo(
            launcher_files = depset(launcher_files),
            output = depset([executable or default_info.files_to_run.executable]),
        )

    # buildifier: disable=print
    print(ctx.label, default_info.default_runfiles.merge(
        # The original executable is now also considered a runfile
        ctx.runfiles(files = launcher_files + [
            executable or default_info.files_to_run.executable,
        ]),
    ).files)

    providers.extend([
        DefaultInfo(
            files = default_info.files,
            runfiles = default_info.default_runfiles.merge(
                # The original executable is now also considered a runfile
                ctx.runfiles(files = launcher_files + [
                    executable or default_info.files_to_run.executable,
                ]),
            ),
            executable = launcher,
        ),
        output_group_info,
    ])

    return providers

def create_launcher(ctx, toolchain, args = [], env = {}, data = [], providers = [], executable = None):
    """Create a process wrapper to ensure runtime environment variables are defined for the test binary

    Args:
        ctx (ctx): The rule's context object
        toolchain (rust_toolchain): The current rust toolchain
        args (list, optional): Optional arguments to include in the lancher
        env (dict, optional): Optional environment variables to include in the lancher
        data (list, optional): Targets to use when performing location expansion on `args` and `env`.
        providers (list, optional): Providers from a rust compile action. See `rustc_compile_action`
        executable (File, optional): An optional executable for the launcher to wrap

    Returns:
        list: A list of providers similar to `rustc_compile_action` but with modified default info
    """

    # TODO: It's unclear if the toolchain is in the same configuration as the `_launcher` attribute
    # This should be investigated but for now, we generally assume if the target environment is windows,
    # the execution environment is windows.
    if toolchain.os == "windows":
        launcher_filename = ctx.label.name + ".launcher.exe"
    else:
        launcher_filename = ctx.label.name + ".launcher"

    launcher = ctx.actions.declare_file(launcher_filename)

    # Because returned executables must be created from the same rule, the
    # launcher target is simply symlinked and exposed.
    ctx.actions.symlink(
        output = launcher,
        target_file = ctx.executable._launcher,
        is_executable = True,
    )

    # Expand the environment variables and write them to a file
    launcher_files = [
        _write_environ(ctx, launcher_filename, env, data),
        _write_args(ctx, launcher_filename, args, data),
        _write_executable(ctx, launcher_filename, executable),
    ]

    return _merge_providers(
        ctx = ctx,
        providers = providers,
        launcher = launcher,
        launcher_files = launcher_files,
        executable = executable,
    )

"""infer_test"""

def _rlocationpath(file, workspace_name):
    if file.short_path.startswith("../"):
        return file.short_path[len("../"):]

    return "{}/{}".format(workspace_name, file.short_path)

def _infer_test_impl(ctx):
    runner = ctx.executable._test_runner
    is_windows = runner.basename.endswith((".exe", ".bat", ".ps1"))
    executable = ctx.actions.declare_file("{}{}".format(ctx.label.name, ".exe" if is_windows else ""))
    ctx.actions.symlink(
        target_file = runner,
        output = executable,
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = executable,
            runfiles = ctx.runfiles(files = [ctx.file.file]),
        ),
        RunEnvironmentInfo(
            environment = {
                "INFER_TEST_EXPECTED_TYPE": ctx.attr.type,
                "INFER_TEST_FILE": _rlocationpath(ctx.file.file, ctx.workspace_name),
            },
        ),
    ]

infer_test = rule(
    doc = "A test that asserts on the file type of a given file.",
    implementation = _infer_test_impl,
    attrs = {
        "file": attr.label(
            doc = "The file to check.",
            allow_single_file = True,
            mandatory = True,
        ),
        "type": attr.string(
            doc = "The expected type.",
            mandatory = True,
        ),
        "_test_runner": attr.label(
            cfg = "exec",
            executable = True,
            default = Label("//tools:infer_tester"),
        ),
    },
    test = True,
)

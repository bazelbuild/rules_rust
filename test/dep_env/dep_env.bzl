"""Tests for passing configuration to cargo_build_script rules"""

def _create_dep_dir(ctx):
    out = ctx.actions.declare_directory("dep_dir")
    ctx.actions.run_shell(
        outputs = [out],
        arguments = [out.path],
        command = 'echo contents > "$@/a_file"',
    )
    return [DefaultInfo(files = depset(direct = [out]))]

create_dep_dir = rule(
    implementation = _create_dep_dir,
)

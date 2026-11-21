"""Tests for the `CARGO_MANIFEST_DIR` path of `cargo_build_script`."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//cargo:defs.bzl", "cargo_build_script")

def _manifest_dir_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    actions = [a for a in target.actions if a.mnemonic == "CargoBuildScriptRun"]
    asserts.equals(env, 1, len(actions), "Expected one CargoBuildScriptRun action")
    action = actions[0]

    runfiles_dirs = [o for o in action.outputs.to_list() if o.path.endswith(".cargo_runfiles")]
    asserts.equals(env, 1, len(runfiles_dirs), "Expected one runfiles directory output")

    asserts.equals(
        env,
        "{}/_/{}".format(runfiles_dirs[0].path, target.label.package),
        action.env["CARGO_MANIFEST_DIR"],
    )

    return analysistest.end(env)

manifest_dir_test = analysistest.make(_manifest_dir_test_impl)

def manifest_dir_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """
    write_file(
        name = "build_rs_src",
        out = "build.rs",
        content = ["fn main() {}", ""],
        newline = "unix",
    )

    write_file(
        name = "data_txt",
        out = "data.txt",
        content = ["data", ""],
        newline = "unix",
    )

    cargo_build_script(
        name = "build_script",
        srcs = [":build.rs"],
        data = [":data.txt"],
        edition = "2021",
    )

    manifest_dir_test(
        name = "manifest_dir_test",
        target_under_test = ":build_script",
    )

    native.test_suite(
        name = name,
        tests = [":manifest_dir_test"],
    )

"""Macro for running snapshot tests and updating snapshots in the source tree"""

load("@rules_rust//rust:defs.bzl", "rust_test")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

def rust_snapshot_test(name, snapshots_dir, **kwargs):
    """A rust_test with an accompanying executable rule to update insta snapshots in the source tree.

    Args:
        name: Name of the test rule. The update rule name becomes {name}_update_snapshots.
        snapshots_dir: Directory containing snapshot files.
        **kwargs: Additional args to pass to rust_test
    """
    snapshots = native.glob(["{}/**".format(snapshots_dir)], exclude_directories = 1, allow_empty = True)

    rust_test(
        name = name,
        rustc_env = {
            # Re-root what insta considers to be the workspace root to the runfiles
            # root where the test binary runs. Otherwise, insta gets confused and looks
            # for snapshots next to the test binary in the output tree.
            # https://insta.rs/docs/advanced/#workspace-root
            "INSTA_WORKSPACE_ROOT": ".",
        } | kwargs.pop("rustc_env", {}),
        env = {
            # Updating snapshots automatically requires escaping the sandbox.
            # This is not bazel idiomatic, so simply fail the test and report the
            # diffs. Leave actually updating snapshots to the "update" executable rule
            # below.
            "INSTA_OUTPUT": "diff",
            "INSTA_UPDATE": "no",
        } | kwargs.pop("env", {}),
        data = snapshots + kwargs.pop("data", []),
        **kwargs
    )

    sh_binary(
        name = "{}_update_snapshots".format(name),
        srcs = ["@//:update_snapshots.sh"],
        data = [":{}".format(name)],
        args = ["$(rootpath :{})".format(name), snapshots_dir],
        testonly = True,
    )

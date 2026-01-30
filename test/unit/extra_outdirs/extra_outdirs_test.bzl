"""Unittest to verify extra_outdirs attribute adds directories to action outputs."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//test/unit:common.bzl", "assert_action_mnemonic")

def _extra_outdirs_present_test(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    # Find the Rustc action
    rustc_action = [action for action in target.actions if action.mnemonic == "Rustc"][0]
    assert_action_mnemonic(env, rustc_action, "Rustc")

    # Get all outputs from the action
    outputs = rustc_action.outputs.to_list()

    # Check that the expected directories are in the outputs
    expected_dirs = sorted(ctx.attr.expected_outdirs)
    found_dirs = []

    for output in outputs:
        # Check if this output is a directory
        # and if its basename matches one of our expected directories
        if output.is_directory:
            if output.basename in expected_dirs:
                found_dirs.append(output.basename)

    # Sort found directories for consistent comparison
    found_dirs = sorted(found_dirs)

    # Verify all expected directories were found
    asserts.equals(
        env,
        found_dirs,
        expected_dirs,
        "Expected to find directories {expected} in action outputs, but found {found}".format(
            expected = expected_dirs,
            found = found_dirs,
        ),
    )

    return analysistest.end(env)

def _extra_outdirs_not_present_test(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    # Find the Rustc action
    rustc_action = [action for action in target.actions if action.mnemonic == "Rustc"][0]
    assert_action_mnemonic(env, rustc_action, "Rustc")

    # Get all outputs from the action
    outputs = rustc_action.outputs.to_list()

    # Check that no extra directories are present
    # We expect only the standard outputs (rlib, rmeta if pipelining, etc.)
    # but not any extra_outdirs directories
    unexpected_dirs = []
    for output in outputs:
        if output.is_directory:
            # Standard directories like .dSYM are okay, but we shouldn't have
            # any of the extra_outdirs we're testing for
            if output.basename in ["test_dir", "another_dir"]:
                unexpected_dirs.append(output.basename)

    asserts.equals(
        env,
        [],
        unexpected_dirs,
        "Expected no extra_outdirs directories, but found {found}".format(
            found = unexpected_dirs,
        ),
    )

    return analysistest.end(env)

extra_outdirs_present_test = analysistest.make(
    _extra_outdirs_present_test,
    attrs = {
        "expected_outdirs": attr.string_list(
            mandatory = True,
            doc = "List of expected output directory names",
        ),
    },
)

extra_outdirs_not_present_test = analysistest.make(_extra_outdirs_not_present_test)

def extra_outdirs_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """
    extra_outdirs_not_present_test(
        name = "extra_outdirs_not_present_test",
        target_under_test = ":lib",
    )

    extra_outdirs_present_test(
        name = "extra_outdirs_present_test",
        target_under_test = ":lib_with_outdirs",
        expected_outdirs = ["test_dir", "another_dir"],
    )

    native.test_suite(
        name = name,
        tests = [
            ":extra_outdirs_not_present_test",
            ":extra_outdirs_present_test",
        ],
    )

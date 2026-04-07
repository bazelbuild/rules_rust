"""Unittest to verify ordering of rust stdlib in rust_library() CcInfo"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_common", "rust_test")
load("//test/unit:common.bzl", "assert_action_mnemonic", "assert_argv_contains", "assert_argv_contains_not", "assert_list_contains_adjacent_elements", "assert_list_contains_adjacent_elements_not")

def _use_libtest_harness_rustc_flags_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = tut.actions[0]
    assert_action_mnemonic(env, action, "Rustc")
    assert_argv_contains(env, action, "test/unit/use_libtest_harness/mytest.rs")
    assert_argv_contains(env, action, "--test")
    assert_list_contains_adjacent_elements_not(env, action.argv, ["--cfg", "test"])
    return analysistest.end(env)

def _use_libtest_harness_rustc_noharness_flags_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = tut.actions[0]
    assert_action_mnemonic(env, action, "Rustc")
    assert_argv_contains(env, action, "test/unit/use_libtest_harness/mytest_noharness.rs")
    assert_argv_contains_not(env, action, "--test")
    assert_list_contains_adjacent_elements(env, action.argv, ["--cfg", "test"])
    return analysistest.end(env)

def _use_libtest_harness_rustc_noharness_main_flags_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = tut.actions[0]
    assert_action_mnemonic(env, action, "Rustc")
    assert_argv_contains(env, action, "test/unit/use_libtest_harness/main.rs")
    assert_argv_contains_not(env, action, "--test")
    assert_list_contains_adjacent_elements(env, action.argv, ["--cfg", "test"])
    return analysistest.end(env)

def _use_libtest_harness_executable_is_wrapped_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    executable = tut[DefaultInfo].files_to_run.executable
    default_outputs = tut[DefaultInfo].files.to_list()
    crate_output = tut[rust_common.crate_info].output
    run_environment = tut[RunEnvironmentInfo].environment

    asserts.true(
        env,
        executable.short_path != crate_output.short_path,
        "Expected bazel test to run a hidden launcher, got {}".format(executable.short_path),
    )
    asserts.equals(env, len(default_outputs), 1)
    asserts.equals(env, default_outputs[0].short_path, crate_output.short_path)
    asserts.true(
        env,
        "/_test_sharding_launcher/" in executable.short_path,
        "Expected launcher executable path to stay private, got {}".format(executable.short_path),
    )

    runfiles = [file.short_path for file in tut[DefaultInfo].default_runfiles.files.to_list()]
    asserts.true(
        env,
        crate_output.short_path in runfiles,
        "Expected public test binary to be present in runfiles, got {}".format(runfiles),
    )
    asserts.true(
        env,
        executable.short_path in runfiles,
        "Expected hidden launcher to be present in runfiles, got {}".format(runfiles),
    )
    asserts.true(
        env,
        crate_output.short_path + ".runfiles" in runfiles,
        "Expected public runfiles dir alias to be present in runfiles, got {}".format(runfiles),
    )
    asserts.true(
        env,
        crate_output.short_path + ".runfiles_manifest" in runfiles,
        "Expected public runfiles manifest alias to be present in runfiles, got {}".format(runfiles),
    )
    asserts.true(
        env,
        crate_output.short_path + ".repo_mapping" in runfiles,
        "Expected public repo mapping alias to be present in runfiles, got {}".format(runfiles),
    )
    asserts.true(
        env,
        len([path for path in runfiles if path.endswith("rust/private/test_sharding/launcher")]) > 0,
        "Expected sharding launcher to be present in runfiles, got {}".format(runfiles),
    )
    asserts.equals(
        env,
        len([path for path in runfiles if "/_test_sharding_bin/" in path]),
        0,
    )
    asserts.equals(
        env,
        run_environment.get("TEST_BINARY"),
        crate_output.short_path,
    )
    asserts.equals(
        env,
        run_environment.get("RULES_RUST_TEST_BINARY_RUNFILES_PATH"),
        crate_output.short_path,
    )

    return analysistest.end(env)

def _use_libtest_harness_noharness_executable_is_raw_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    executable = tut[DefaultInfo].files_to_run.executable
    crate_output = tut[rust_common.crate_info].output

    asserts.equals(env, executable.short_path, crate_output.short_path)

    return analysistest.end(env)

use_libtest_harness_rustc_flags_test = analysistest.make(_use_libtest_harness_rustc_flags_test_impl)
use_libtest_harness_rustc_noharness_flags_test = analysistest.make(_use_libtest_harness_rustc_noharness_flags_test_impl)
use_libtest_harness_rustc_noharness_main_flags_test = analysistest.make(_use_libtest_harness_rustc_noharness_main_flags_test_impl)
use_libtest_harness_executable_is_wrapped_test = analysistest.make(_use_libtest_harness_executable_is_wrapped_test_impl)
use_libtest_harness_noharness_executable_is_raw_test = analysistest.make(_use_libtest_harness_noharness_executable_is_raw_test_impl)

def _use_libtest_harness_test():
    rust_test(
        name = "mytest",
        srcs = ["mytest.rs"],
        edition = "2018",
    )

    rust_test(
        name = "mytest_noharness",
        srcs = ["mytest_noharness.rs"],
        edition = "2018",
        use_libtest_harness = False,
    )

    rust_test(
        name = "mytest_noharness_main",
        srcs = [
            "main.rs",
            "mytest.rs",
        ],
        edition = "2018",
        use_libtest_harness = False,
    )

    use_libtest_harness_rustc_flags_test(
        name = "use_libtest_harness_rustc_flags_test",
        target_under_test = ":mytest",
    )

    use_libtest_harness_rustc_noharness_flags_test(
        name = "use_libtest_harness_rustc_noharness_flags_test",
        target_under_test = ":mytest_noharness",
    )

    use_libtest_harness_rustc_noharness_main_flags_test(
        name = "use_libtest_harness_rustc_noharness_main_flags_test",
        target_under_test = ":mytest_noharness_main",
    )

    use_libtest_harness_executable_is_wrapped_test(
        name = "use_libtest_harness_executable_is_wrapped_test",
        target_under_test = ":mytest",
    )

    use_libtest_harness_noharness_executable_is_raw_test(
        name = "use_libtest_harness_noharness_executable_is_raw_test",
        target_under_test = ":mytest_noharness",
    )

def use_libtest_harness_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _use_libtest_harness_test()

    native.test_suite(
        name = name,
        tests = [
            ":use_libtest_harness_rustc_flags_test",
            ":use_libtest_harness_executable_is_wrapped_test",
            ":use_libtest_harness_noharness_executable_is_raw_test",
        ],
    )

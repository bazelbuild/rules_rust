"""Unittest to verify rustc flag ordering"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_test")

def assert_argv_order(env, action, expected_flags):
    """Checks that a set of flags appear in the given order.

    Checks that the flags in `expected_flags` are in the command line
    arguments for `action` in the given order (possibly with other arguments
    in between).

    Args:
      env: env from analysistest.begin(ctx).
      action: The action whose command line will be checked.
      expected_flags: The expected set of flags, in the expected order.
    """
    argv = action.argv
    last_idx = -1
    for flag in expected_flags:
        found_idx = -1
        for i in range(last_idx + 1, len(argv)):
            if argv[i] == flag:
                found_idx = i
                break

        asserts.true(
            env,
            found_idx > last_idx,
            "Expected flag '{}' to appear after previous flags in argv: {}".format(flag, argv),
        )
        last_idx = found_idx

def _rustc_flag_ordering_test(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    asserts.equals(env, "Rustc", action.mnemonic)

    # We expect:
    # 1. --edition=2018 (one of the flags added by default by construct_arguments)
    # 2. --test (added via rust_flags in rust_test, now moved right before authored flags)
    # 3. --cfg=my_authored_flag (added via rustc_flags attribute, added last in construct_arguments)
    assert_argv_order(
        env,
        action,
        [
            "--edition=2018",
            "--test",
            "--cfg=my_authored_flag",
        ],
    )

    return analysistest.end(env)

rustc_flag_ordering_test = analysistest.make(_rustc_flag_ordering_test)

def _define_test_targets():
    rust_test(
        name = "test_target",
        srcs = ["lib.rs"],
        edition = "2018",
        rustc_flags = ["--cfg=my_authored_flag"],
    )

def rustc_flag_ordering_test_suite(name):
    _define_test_targets()

    rustc_flag_ordering_test(
        name = "rustc_flag_ordering_test",
        target_under_test = ":test_target",
    )

    native.test_suite(
        name = name,
        tests = [
            ":rustc_flag_ordering_test",
        ],
    )

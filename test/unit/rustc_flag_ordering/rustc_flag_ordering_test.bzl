"""Unittest to verify rustc flag ordering"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_test")
load("//test/unit:common.bzl", "assert_argv_contains", "assert_argv_contains_not")

_TOOLCHAIN_LINK_OPTIONS = [
    "-Wl,--toolchain-option-before",
    "-L/toolchain/joined",
    "-L",
    "/toolchain/split",
    "-LIBPATH:C:/toolchain/windows",
    "-Wl,--toolchain-option-after",
]

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

def _toolchain_native_search_path_ordering_test(ctx):
    env = analysistest.begin(ctx)
    action = analysistest.target_under_test(env).actions[0]
    asserts.equals(env, "Rustc", action.mnemonic)

    assert_argv_order(
        env,
        action,
        [
            "-Lnative=/toolchain/joined",
            "-Lnative=/toolchain/split",
            "-Lnative=/crate/native",
        ],
    )

    for original_argument in [
        "--codegen=link-arg=-L/toolchain/joined",
        "--codegen=link-arg=-L",
        "--codegen=link-arg=/toolchain/split",
        "-Lnative=IBPATH:C:/toolchain/windows",
    ]:
        assert_argv_contains_not(env, action, original_argument)

    windows_link_argument = "--codegen=link-arg=-LIBPATH:C:/toolchain/windows"
    assert_argv_contains(env, action, windows_link_argument)

    if ctx.attr.expect_ordinary_linker_options:
        assert_argv_order(
            env,
            action,
            [
                "--codegen=link-arg=-Wl,--toolchain-option-before",
                windows_link_argument,
                "--codegen=link-arg=-Wl,--toolchain-option-after",
            ],
        )

    return analysistest.end(env)

toolchain_native_search_paths_cc_linker_test = analysistest.make(
    _toolchain_native_search_path_ordering_test,
    attrs = {"expect_ordinary_linker_options": attr.bool()},
    config_settings = {
        str(Label("//rust/settings:toolchain_linker_preference")): "cc",
        "//command_line_option:linkopt": _TOOLCHAIN_LINK_OPTIONS,
    },
)

toolchain_native_search_paths_rust_linker_test = analysistest.make(
    _toolchain_native_search_path_ordering_test,
    attrs = {"expect_ordinary_linker_options": attr.bool()},
    config_settings = {
        str(Label("//rust/settings:toolchain_linker_preference")): "rust",
        "//command_line_option:linkopt": _TOOLCHAIN_LINK_OPTIONS,
    },
)

def _hermetic_glibc_search_path_ordering_test(ctx):
    env = analysistest.begin(ctx)
    action = analysistest.target_under_test(env).actions[0]
    asserts.equals(env, "Rustc", action.mnemonic)

    glibc_search_paths = [
        arg
        for arg in action.argv
        if arg.startswith("-Lnative=") and "/glibc_library_search_directory" in arg
    ]
    asserts.equals(
        env,
        1,
        len(glibc_search_paths),
        "Expected hermetic-llvm glibc as a rustc -Lnative argument: {}".format(action.argv),
    )
    if glibc_search_paths:
        assert_argv_order(env, action, [glibc_search_paths[0], "-Lnative=/crate/native"])

    return analysistest.end(env)

hermetic_glibc_search_path_ordering_test = analysistest.make(
    _hermetic_glibc_search_path_ordering_test,
    config_settings = {
        str(Label("//rust/settings:toolchain_linker_preference")): "cc",
        "//command_line_option:extra_execution_platforms": [str(Label("@llvm//platforms:linux_x86_64"))],
        "//command_line_option:extra_toolchains": ["@llvm//toolchain:all"],
        "//command_line_option:platforms": [str(Label("@llvm//platforms:linux_x86_64"))],
    },
)

def _define_test_targets():
    rust_test(
        name = "test_target",
        srcs = ["lib.rs"],
        edition = "2018",
        rustc_flags = ["--cfg=my_authored_flag"],
    )

    rust_test(
        name = "toolchain_native_search_paths_target",
        srcs = ["lib.rs"],
        edition = "2018",
        rustc_flags = ["-Lnative=/crate/native"],
    )

def rustc_flag_ordering_test_suite(name):
    """Defines the rustc argument-ordering analysis tests.

    Args:
        name: Name of the generated test suite.
    """
    _define_test_targets()

    rustc_flag_ordering_test(
        name = "rustc_flag_ordering_test",
        target_under_test = ":test_target",
    )

    toolchain_native_search_paths_cc_linker_test(
        name = "toolchain_native_search_paths_cc_linker_test",
        target_under_test = ":toolchain_native_search_paths_target",
        expect_ordinary_linker_options = True,
    )

    toolchain_native_search_paths_rust_linker_test(
        name = "toolchain_native_search_paths_rust_linker_test",
        target_under_test = ":toolchain_native_search_paths_target",
    )

    hermetic_glibc_search_path_ordering_test(
        name = "hermetic_glibc_search_path_ordering_test",
        target_under_test = ":toolchain_native_search_paths_target",
    )

    native.test_suite(
        name = name,
        tests = [
            ":hermetic_glibc_search_path_ordering_test",
            ":rustc_flag_ordering_test",
            ":toolchain_native_search_paths_cc_linker_test",
            ":toolchain_native_search_paths_rust_linker_test",
        ],
    )

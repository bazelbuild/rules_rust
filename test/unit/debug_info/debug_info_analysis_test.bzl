"""Analysis tests for debug info in cdylib and bin targets."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//rust:defs.bzl", "rust_binary", "rust_shared_library", "rust_test")
load(
    "//test/unit:common.bzl",
    "assert_argv_contains",
    "assert_argv_contains_not",
    "assert_argv_contains_prefix",
    "assert_argv_contains_prefix_not",
)

def _pdb_file_test_impl(ctx, expect_pdb_file):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    files = target[DefaultInfo].files.to_list()

    if not expect_pdb_file:
        asserts.equals(env, len(files), 0)
        return analysistest.end(env)

    asserts.equals(env, len(files), 1)
    file = files[0]
    asserts.equals(env, file.extension, "pdb")
    return analysistest.end(env)

def _pdb_file_for_dbg_test_impl(ctx):
    """Test for dbg compilation mode."""
    return _pdb_file_test_impl(ctx, True)

pdb_file_dbg_test = analysistest.make(
    _pdb_file_for_dbg_test_impl,
    config_settings = {
        "//command_line_option:compilation_mode": "dbg",
    },
)

def _pdb_file_for_fastbuild_test_impl(ctx):
    """Test for fastbuild compilation mode."""
    return _pdb_file_test_impl(ctx, True)

pdb_file_fastbuild_test = analysistest.make(
    _pdb_file_for_fastbuild_test_impl,
    config_settings = {
        "//command_line_option:compilation_mode": "fastbuild",
    },
)

def _pdb_file_for_opt_test_impl(ctx):
    """Test for opt compilation mode."""
    return _pdb_file_test_impl(ctx, False)

pdb_file_opt_test = analysistest.make(
    _pdb_file_for_opt_test_impl,
    config_settings = {
        "//command_line_option:compilation_mode": "opt",
    },
)

# Mapping from compilation mode to pdb file test.
pdb_file_tests = {
    "dbg": pdb_file_dbg_test,
    "fastbuild": pdb_file_fastbuild_test,
    "opt": pdb_file_opt_test,
}

def _dsym_folder_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    files = target[DefaultInfo].files.to_list()
    asserts.equals(env, len(files), 1)
    file = files[0]
    asserts.equals(env, file.extension, "dSYM")

    return analysistest.end(env)

dsym_folder_test = analysistest.make(_dsym_folder_test_impl)

def _fission_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = None
    for a in target.actions:
        if a.mnemonic == "Rustc":
            action = a
            break
    asserts.true(env, action != None, "Expected to find Rustc action")

    assert_argv_contains(env, action, "--codegen=split-debuginfo=unpacked")
    assert_argv_contains(env, action, "--codegen=debuginfo=full")
    assert_argv_contains_prefix(env, action, "-Zsplit-dwarf-out-dir=")

    # Verify that the fission directory is in the action outputs.
    outputs = action.outputs.to_list()
    fission_dir_prefix = target.label.name + "_fission"
    found_fission_dir = False
    for out in outputs:
        if out.basename.startswith(fission_dir_prefix):
            found_fission_dir = True
            asserts.true(env, out.is_directory, "Expected fission output to be a directory")
            break
    asserts.true(env, found_fission_dir, "Expected to find fission directory in action outputs")

    # Verify CcInfo contains the debug_context with the dwo files (if CcInfo is provided).
    if CcInfo in target:
        cc_info = target[CcInfo]
        asserts.true(env, hasattr(cc_info, "_debug_context"), "Expected CcInfo to have _debug_context")
        debug_context = cc_info._debug_context
        asserts.true(env, debug_context != None, "Expected _debug_context to be not None")

        dwo_files = debug_context.files.to_list()
        asserts.equals(env, 1, len(dwo_files))
        asserts.true(
            env,
            dwo_files[0].basename.startswith(fission_dir_prefix),
            "Expected dwo file basename to start with %s, got %s" % (fission_dir_prefix, dwo_files[0].basename),
        )

        pic_dwo_files = debug_context.pic_files.to_list()
        asserts.equals(env, 1, len(pic_dwo_files))
        asserts.true(
            env,
            pic_dwo_files[0].basename.startswith(fission_dir_prefix),
            "Expected pic dwo file basename to start with %s, got %s" % (fission_dir_prefix, pic_dwo_files[0].basename),
        )

    return analysistest.end(env)

fission_test = analysistest.make(
    _fission_test_impl,
    config_settings = {
        "//command_line_option:features": ["per_object_debug_info"],
        "//command_line_option:fission": ["yes"],
    },
)

def _no_fission_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = None
    for a in target.actions:
        if a.mnemonic == "Rustc":
            action = a
            break
    asserts.true(env, action != None, "Expected to find Rustc action")

    assert_argv_contains_not(env, action, "--codegen=split-debuginfo=unpacked")
    assert_argv_contains_not(env, action, "--codegen=debuginfo=full")
    assert_argv_contains_prefix_not(env, action, "-Zsplit-dwarf-out-dir=")

    # Verify no fission directory in outputs.
    outputs = action.outputs.to_list()
    fission_dir_name = target.label.name + "_fission"
    for out in outputs:
        asserts.true(env, out.basename != fission_dir_name, "Did not expect fission directory in outputs")

    # CcInfo's debug_context should not contain dwo files.
    if CcInfo in target:
        cc_info = target[CcInfo]
        if hasattr(cc_info, "_debug_context") and cc_info._debug_context:
            asserts.equals(env, 0, len(cc_info._debug_context.files.to_list()))
            asserts.equals(env, 0, len(cc_info._debug_context.pic_files.to_list()))

    return analysistest.end(env)

no_fission_test = analysistest.make(
    _no_fission_test_impl,
    config_settings = {
        "//command_line_option:fission": ["no"],
    },
)

# Fission requires `-Zsplit-dwarf-out-dir` which is a nightly-only flag.
# Even though these are analysis tests (which normally don't execute actions),
# `bazel coverage` forces compilation of the `target_under_test`. To prevent
# compilation failures on the stable channel during coverage runs, we restrict
# Fission tests to the nightly channel.
_FISSION_COMPATIBILITY = ["@platforms//os:linux"] + select({
    "//rust/toolchain/channel:nightly": [],
    "//conditions:default": ["@platforms//:incompatible"],
})

def debug_info_analysis_test_suite(name):
    """Analysis tests for debug info in cdylib and bin targets.

    Args:
        name: the test suite name
    """
    rust_shared_library(
        name = "mylib",
        srcs = ["lib.rs"],
        edition = "2018",
    )

    native.filegroup(
        name = "mylib.pdb",
        srcs = [":mylib"],
        output_group = "pdb_file",
    )

    for compilation_mode, pdb_test in pdb_file_tests.items():
        pdb_test(
            name = "lib_pdb_test_{}".format(compilation_mode),
            target_under_test = ":mylib.pdb",
            target_compatible_with = ["@platforms//os:windows"],
        )

    native.filegroup(
        name = "mylib.dSYM",
        srcs = [":mylib"],
        output_group = "dsym_folder",
    )

    dsym_folder_test(
        name = "lib_dsym_test",
        target_under_test = ":mylib.dSYM",
        target_compatible_with = ["@platforms//os:macos"],
    )

    rust_binary(
        name = "myrustbin",
        srcs = ["main.rs"],
        edition = "2018",
    )

    native.filegroup(
        name = "mybin.pdb",
        srcs = [":myrustbin"],
        output_group = "pdb_file",
    )

    for compilation_mode, pdb_test in pdb_file_tests.items():
        pdb_test(
            name = "bin_pdb_test_{}".format(compilation_mode),
            target_under_test = ":mybin.pdb",
            target_compatible_with = ["@platforms//os:windows"],
        )

    native.filegroup(
        name = "mybin.dSYM",
        srcs = [":myrustbin"],
        output_group = "dsym_folder",
    )

    dsym_folder_test(
        name = "bin_dsym_test",
        target_under_test = ":mybin.dSYM",
        target_compatible_with = ["@platforms//os:macos"],
    )

    rust_test(
        name = "myrusttest",
        srcs = ["test.rs"],
        edition = "2018",
    )

    native.filegroup(
        name = "mytest.pdb",
        srcs = [":myrusttest"],
        output_group = "pdb_file",
        testonly = True,
    )

    for compilation_mode, pdb_test in pdb_file_tests.items():
        pdb_test(
            name = "test_pdb_test_{}".format(compilation_mode),
            target_under_test = ":mytest.pdb",
            target_compatible_with = ["@platforms//os:windows"],
        )

    native.filegroup(
        name = "mytest.dSYM",
        srcs = [":myrusttest"],
        output_group = "dsym_folder",
        testonly = True,
    )

    dsym_folder_test(
        name = "test_dsym_test",
        target_under_test = ":mytest.dSYM",
        target_compatible_with = ["@platforms//os:macos"],
    )

    # Fission tests
    fission_test(
        name = "lib_fission_test",
        target_under_test = ":mylib",
        target_compatible_with = _FISSION_COMPATIBILITY,
    )
    no_fission_test(
        name = "lib_no_fission_test",
        target_under_test = ":mylib",
    )

    fission_test(
        name = "bin_fission_test",
        target_under_test = ":myrustbin",
        target_compatible_with = _FISSION_COMPATIBILITY,
    )
    no_fission_test(
        name = "bin_no_fission_test",
        target_under_test = ":myrustbin",
    )

    fission_test(
        name = "test_fission_test",
        target_under_test = ":myrusttest",
        target_compatible_with = _FISSION_COMPATIBILITY,
    )
    no_fission_test(
        name = "test_no_fission_test",
        target_under_test = ":myrusttest",
    )

    native.test_suite(
        name = name,
        tests = [
            ":lib_dsym_test",
            ":bin_dsym_test",
            ":test_dsym_test",
            ":lib_fission_test",
            ":lib_no_fission_test",
            ":bin_fission_test",
            ":bin_no_fission_test",
            ":test_fission_test",
            ":test_no_fission_test",
        ] + [
            ":lib_pdb_test_{}".format(compilation_mode)
            for compilation_mode in pdb_file_tests
        ] + [
            ":bin_pdb_test_{}".format(compilation_mode)
            for compilation_mode in pdb_file_tests
        ] + [
            ":test_pdb_test_{}".format(compilation_mode)
            for compilation_mode in pdb_file_tests
        ],
    )

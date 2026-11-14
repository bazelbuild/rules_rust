"""Analysis tests for DebugPackageInfo and dwo_files on rust_binary."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_cc//cc:defs.bzl", "cc_library")
load("@rules_cc//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_ATTRS")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:debug_package_info.bzl", "DebugPackageInfo")
load("//rust:defs.bzl", "rust_binary", "rust_library")
load("//rust:toolchain.bzl", "rust_stdlib_filegroup", "rust_toolchain")

def _cc_toolchain_supports_strip_files(ctx):
    if cc_common.CcToolchainInfo not in ctx.attr._cc_toolchain:
        return False
    return hasattr(ctx.attr._cc_toolchain[cc_common.CcToolchainInfo], "_strip_files")

def _assert_strip_action(env, debug_package_info):
    strip_actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "CcStrip"]
    asserts.equals(env, 1, len(strip_actions))
    asserts.true(
        env,
        debug_package_info.unstripped_file in strip_actions[0].inputs.to_list(),
        "Expected CcStrip action inputs to include unstripped_file",
    )
    asserts.equals(
        env,
        [debug_package_info.stripped_file],
        strip_actions[0].outputs.to_list(),
    )

def _test_n_dwo_files(ctx, n, expect_cpp_link = False):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    if expect_cpp_link:
        cpp_link_actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "CppLink"]
        asserts.equals(env, 1, len(cpp_link_actions))

    if not _cc_toolchain_supports_strip_files(ctx):
        asserts.false(env, DebugPackageInfo in target_under_test)
        return analysistest.end(env)

    debug_package_info = target_under_test[DebugPackageInfo]
    asserts.equals(env, target_under_test.label.name + ".stripped", debug_package_info.stripped_file.basename)
    _assert_strip_action(env, debug_package_info)
    if hasattr(debug_package_info, "dwo_files") and debug_package_info.dwo_files != None:
        asserts.equals(env, n, len(debug_package_info.dwo_files.to_list()))
    elif n > 0:
        dwp_actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "CcGenerateDwp"]
        asserts.equals(env, 1, len(dwp_actions))
        fission_inputs = [f for f in dwp_actions[0].inputs.to_list() if "_fission" in f.basename]
        asserts.equals(env, n, len(fission_inputs))

    if n > 0:
        asserts.equals(env, target_under_test.label.name + ".dwp", debug_package_info.dwp_file.basename)
    else:
        asserts.equals(env, None, debug_package_info.dwp_file)

    return analysistest.end(env)

def _dwo_files_contents(ctx):
    # Expect one dwo entry per crate in the dependency chain (dwo_impl_lib, dwo_lib, dwo_main).
    return _test_n_dwo_files(ctx, 3)

def _dwo_files_no_contents(ctx):
    # Without fission, dwo_files should be empty and dwp_file should be None.
    return _test_n_dwo_files(ctx, 0)

def _dwo_files_cc_common_link(ctx):
    # With experimental_use_cc_common_link=True, verify CppLink, CcStrip, and DebugPackageInfo.
    return _test_n_dwo_files(ctx, 0, expect_cpp_link = True)

def _dwo_files_skip_rust_fission(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    if not _cc_toolchain_supports_strip_files(ctx):
        asserts.false(env, DebugPackageInfo in target_under_test)
        return analysistest.end(env)

    debug_package_info = target_under_test[DebugPackageInfo]
    asserts.equals(env, target_under_test.label.name + ".stripped", debug_package_info.stripped_file.basename)
    asserts.equals(env, target_under_test.label.name + ".dwp", debug_package_info.dwp_file.basename)
    _assert_strip_action(env, debug_package_info)
    if hasattr(debug_package_info, "dwo_files") and debug_package_info.dwo_files != None:
        asserts.equals(env, 1, len(debug_package_info.dwo_files.to_list()))
    else:
        dwp_actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "CcGenerateDwp"]
        asserts.equals(env, 1, len(dwp_actions))
        dwo_inputs = [f for f in dwp_actions[0].inputs.to_list() if f.extension == "dwo"]
        fission_inputs = [f for f in dwp_actions[0].inputs.to_list() if "_fission" in f.basename]
        asserts.equals(env, 1, len(dwo_inputs))
        asserts.equals(env, 0, len(fission_inputs))

    return analysistest.end(env)

def _dwo_files_implicit_outputs(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    basenames = sorted([f.basename for f in target_under_test[DefaultInfo].files.to_list()])
    asserts.equals(env, ["dwo_main.dwp", "dwo_main.stripped"], basenames)
    return analysistest.end(env)

def _no_cc_toolchain_fission_error(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "requires a configured `cc_toolchain`")
    return analysistest.end(env)

dwo_files_contents_test = analysistest.make(
    _dwo_files_contents,
    attrs = CC_TOOLCHAIN_ATTRS,
    config_settings = {
        "//command_line_option:features": ["per_object_debug_info"],
        "//command_line_option:fission": ["yes"],
    },
)

dwo_files_no_contents_test = analysistest.make(
    _dwo_files_no_contents,
    attrs = CC_TOOLCHAIN_ATTRS,
    config_settings = {
        "//command_line_option:fission": ["no"],
    },
)

dwo_files_cc_common_link_test = analysistest.make(
    _dwo_files_cc_common_link,
    attrs = CC_TOOLCHAIN_ATTRS,
    config_settings = {
        "//command_line_option:fission": ["no"],
        # Needed when `bazel coverage` links `target_under_test` under `cc_common.link`.
        str(Label("//rust/settings:experimental_use_allocator_libraries_with_mangled_symbols")): True,
        str(Label("//rust/settings:experimental_use_cc_common_link")): True,
    },
)

dwo_files_skip_rust_fission_test = analysistest.make(
    _dwo_files_skip_rust_fission,
    attrs = CC_TOOLCHAIN_ATTRS,
    config_settings = {
        "//command_line_option:features": ["per_object_debug_info"],
        "//command_line_option:fission": ["yes"],
        str(Label("//rust/settings:skip_fission_for_rust")): True,
    },
)

dwo_files_implicit_outputs_test = analysistest.make(
    _dwo_files_implicit_outputs,
)

no_cc_toolchain_fission_error_test = analysistest.make(
    _no_cc_toolchain_fission_error,
    expect_failure = True,
    config_settings = {
        "//command_line_option:extra_toolchains": [str(Label(":no_cc_mock_toolchain"))],
        "//command_line_option:fission": ["yes"],
        "//command_line_option:platforms": str(Label(":no_cc_toolchain_platform")),
    },
)

def _define_no_cc_toolchain():
    native.constraint_setting(
        name = "no_cc_toolchain_os",
    )

    native.constraint_value(
        name = "no_cc_toolchain_os_value",
        constraint_setting = ":no_cc_toolchain_os",
    )

    native.platform(
        name = "no_cc_toolchain_platform",
        constraint_values = [
            ":no_cc_toolchain_os_value",
        ],
    )

    rust_toolchain(
        name = "no_cc_mock_rust_toolchain",
        allocator_library = "//rust/private/cc:empty",
        binary_ext = "",
        dylib_ext = ".so",
        exec_triple = "x86_64-unknown-linux-gnu",
        rust_doc = ":no_cc_mock_tool",
        rust_std = ":no_cc_mock_std_libs",
        rustc = ":no_cc_mock_tool",
        staticlib_ext = ".a",
        stdlib_linkflags = [],
        target_triple = "x86_64-unknown-none",
    )

    native.toolchain(
        name = "no_cc_mock_toolchain",
        target_compatible_with = [":no_cc_toolchain_os_value"],
        toolchain = ":no_cc_mock_rust_toolchain",
        toolchain_type = "//rust:toolchain_type",
    )

    rust_stdlib_filegroup(
        name = "no_cc_mock_std_libs",
        srcs = [],
    )

    write_file(
        name = "gen_no_cc_mock_tool",
        out = "no_cc_mock_tool",
        content = [],
        is_executable = True,
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

def dwo_files_test_suite(name):
    """Analysis tests for DebugPackageInfo and dwo_files on rust_binary.

    Args:
        name: the test suite name
    """
    _define_no_cc_toolchain()

    rust_library(
        name = "dwo_impl_lib",
        srcs = ["lib.rs"],
        edition = "2018",
        target_compatible_with = ["@platforms//os:linux"],
    )

    rust_library(
        name = "dwo_lib",
        srcs = ["lib.rs"],
        edition = "2018",
        deps = [":dwo_impl_lib"],
        target_compatible_with = ["@platforms//os:linux"],
    )

    rust_binary(
        name = "dwo_main",
        srcs = ["main.rs"],
        edition = "2018",
        deps = [":dwo_lib"],
        target_compatible_with = ["@platforms//os:linux"],
    )

    native.filegroup(
        name = "dwo_main_outputs",
        srcs = [
            ":dwo_main.stripped",
            ":dwo_main.dwp",
        ],
        target_compatible_with = ["@platforms//os:linux"],
    )

    rust_binary(
        name = "dwo_no_cc_toolchain_main",
        srcs = ["main.rs"],
        edition = "2018",
        tags = ["manual"],
    )

    cc_library(
        name = "dwo_cc_lib",
        srcs = ["cc_lib.cc"],
        target_compatible_with = ["@platforms//os:linux"],
    )

    rust_binary(
        name = "dwo_with_cc_main",
        srcs = ["main.rs"],
        edition = "2018",
        link_deps = [":dwo_cc_lib"],
        target_compatible_with = ["@platforms//os:linux"],
    )

    dwo_files_contents_test(
        name = "dwo_files_content_test",
        target_under_test = ":dwo_main",
        target_compatible_with = _FISSION_COMPATIBILITY,
    )

    dwo_files_no_contents_test(
        name = "dwo_files_no_content_test",
        target_under_test = ":dwo_main",
        target_compatible_with = ["@platforms//os:linux"],
    )

    dwo_files_implicit_outputs_test(
        name = "dwo_files_implicit_outputs_test",
        target_under_test = ":dwo_main_outputs",
        target_compatible_with = ["@platforms//os:linux"],
    )

    dwo_files_cc_common_link_test(
        name = "dwo_files_cc_common_link_test",
        target_under_test = ":dwo_main",
        target_compatible_with = ["@platforms//os:linux"],
    )

    dwo_files_skip_rust_fission_test(
        name = "dwo_files_skip_rust_fission_test",
        target_under_test = ":dwo_with_cc_main",
        target_compatible_with = ["@platforms//os:linux"],
    )

    no_cc_toolchain_fission_error_test(
        name = "dwo_files_no_cc_toolchain_fission_error_test",
        target_under_test = ":dwo_no_cc_toolchain_main",
        target_compatible_with = ["@platforms//os:linux"],
    )

    native.test_suite(
        name = name,
        tests = [
            ":dwo_files_content_test",
            ":dwo_files_no_content_test",
            ":dwo_files_implicit_outputs_test",
            ":dwo_files_cc_common_link_test",
            ":dwo_files_skip_rust_fission_test",
            ":dwo_files_no_cc_toolchain_fission_error_test",
        ],
    )

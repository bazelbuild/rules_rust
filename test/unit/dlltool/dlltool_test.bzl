"""Analysis tests for `rust_toolchain.dlltool`."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//rust:defs.bzl", "rust_library")
load("//rust:toolchain.bzl", "rust_stdlib_filegroup", "rust_toolchain")

def _rustc_action(env):
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "Rustc"]
    asserts.equals(env, 1, len(actions))
    return actions[0]

def _dlltool_flags(action):
    return [arg for arg in action.argv if arg.startswith("--codegen=dlltool=")]

def _dlltool_used_test_impl(ctx):
    env = analysistest.begin(ctx)
    action = _rustc_action(env)

    dlltools = [f for f in action.inputs.to_list() if f.basename == "mock_dlltool.exe"]
    asserts.equals(env, 1, len(dlltools), "rust_toolchain.dlltool must be an input of the Rustc action")
    if dlltools:
        flags = _dlltool_flags(action)
        asserts.equals(env, 1, len(flags))
        asserts.true(
            env,
            flags[0].startswith("--codegen=dlltool=bazel-out/") and flags[0].endswith(dlltools[0].short_path),
            "Expected `--codegen=dlltool=bazel-out/<...>/{}` in {}".format(dlltools[0].short_path, flags),
        )

    return analysistest.end(env)

def _dlltool_not_used_test_impl(ctx):
    env = analysistest.begin(ctx)
    action = _rustc_action(env)

    asserts.equals(env, [], _dlltool_flags(action))

    return analysistest.end(env)

dlltool_used_test = analysistest.make(
    _dlltool_used_test_impl,
    config_settings = {
        "//command_line_option:extra_toolchains": [str(Label(":windows_gnu_toolchain"))],
        "//command_line_option:platforms": str(Label(":windows_gnu")),
    },
)

dlltool_not_used_msvc_test = analysistest.make(
    _dlltool_not_used_test_impl,
    config_settings = {
        "//command_line_option:extra_toolchains": [str(Label(":windows_msvc_toolchain"))],
        "//command_line_option:platforms": str(Label(":windows_msvc")),
    },
)

def _define_targets():
    native.constraint_setting(name = "abi")

    for abi in ["gnu", "msvc"]:
        native.constraint_value(
            name = abi,
            constraint_setting = ":abi",
        )

        native.platform(
            name = "windows_" + abi,
            constraint_values = [
                "@platforms//cpu:x86_64",
                "@platforms//os:windows",
                ":" + abi,
            ],
        )

        rust_toolchain(
            name = "windows_{}_rust_toolchain".format(abi),
            binary_ext = ".exe",
            dlltool = ":mock_dlltool",
            dylib_ext = ".dll",
            exec_triple = "x86_64-unknown-linux-gnu",
            rust_doc = ":mock_rustdoc",
            rust_std = ":std_libs",
            rustc = ":mock_rustc",
            staticlib_ext = ".a" if abi == "gnu" else ".lib",
            stdlib_linkflags = [],
            target_triple = "x86_64-pc-windows-" + abi,
        )

        native.toolchain(
            name = "windows_{}_toolchain".format(abi),
            target_compatible_with = [":" + abi],
            toolchain = ":windows_{}_rust_toolchain".format(abi),
            toolchain_type = "@rules_rust//rust:toolchain",
        )

    rust_stdlib_filegroup(
        name = "std_libs",
        srcs = [],
    )

    for tool in ["mock_dlltool", "mock_rustc", "mock_rustdoc"]:
        write_file(
            name = tool,
            out = tool + ".exe",
            content = [],
            is_executable = True,
        )

    rust_library(
        name = "lib",
        srcs = ["lib.rs"],
        edition = "2021",
        tags = ["manual"],
    )

def dlltool_test_suite(name):
    """Entry-point macro for `rust_toolchain.dlltool` tests.

    Args:
        name: test suite name
    """
    _define_targets()

    dlltool_used_test(
        name = "dlltool_used_test",
        target_under_test = ":lib",
    )
    dlltool_not_used_msvc_test(
        name = "dlltool_not_used_msvc_test",
        target_under_test = ":lib",
    )

    native.test_suite(
        name = name,
        tests = [
            ":dlltool_not_used_msvc_test",
            ":dlltool_used_test",
        ],
    )

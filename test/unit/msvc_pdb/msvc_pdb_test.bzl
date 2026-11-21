"""Analysis tests for the PDB output of MSVC binaries."""

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_cc//cc:defs.bzl", "cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/toolchains:cc_toolchain_config_info.bzl", "CcToolchainConfigInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//rust:defs.bzl", "rust_binary", "rust_shared_library")
load("//rust:toolchain.bzl", "rust_stdlib_filegroup", "rust_toolchain")

def _cc_config_impl(ctx):
    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        toolchain_identifier = "mock-msvc",
        host_system_name = "unknown",
        target_system_name = "unknown",
        target_cpu = "unknown",
        target_libc = "unknown",
        compiler = "unknown",
        abi_version = "unknown",
        abi_libc_version = "unknown",
    )

_cc_config = rule(
    implementation = _cc_config_impl,
    provides = [CcToolchainConfigInfo],
)

def _define_mock_toolchains():
    native.constraint_setting(name = "abi")
    native.constraint_value(name = "msvc", constraint_setting = ":abi")
    native.platform(
        name = "windows_msvc",
        constraint_values = [
            "@platforms//cpu:x86_64",
            "@platforms//os:windows",
            ":msvc",
        ],
    )

    _cc_config(name = "cc_config")
    native.filegroup(name = "empty")
    cc_toolchain(
        name = "cc_toolchain_impl",
        all_files = ":empty",
        compiler_files = ":empty",
        dwp_files = ":empty",
        linker_files = ":empty",
        objcopy_files = ":empty",
        strip_files = ":empty",
        supports_param_files = 0,
        toolchain_config = ":cc_config",
        toolchain_identifier = "mock-msvc",
    )
    native.toolchain(
        name = "cc_toolchain",
        target_compatible_with = [":msvc"],
        toolchain = ":cc_toolchain_impl",
        toolchain_type = "@rules_cc//cc:toolchain_type",
    )

    rust_toolchain(
        name = "rust_toolchain_impl",
        binary_ext = ".exe",
        dylib_ext = ".dll",
        exec_triple = "x86_64-unknown-linux-gnu",
        rust_doc = ":mock_rustdoc",
        rust_std = ":std_libs",
        rustc = ":mock_rustc",
        staticlib_ext = ".lib",
        stdlib_linkflags = [],
        target_triple = "x86_64-pc-windows-msvc",
    )
    native.toolchain(
        name = "rust_toolchain",
        target_compatible_with = [":msvc"],
        toolchain = ":rust_toolchain_impl",
        toolchain_type = "@rules_rust//rust:toolchain",
    )
    rust_stdlib_filegroup(name = "std_libs", srcs = [])
    for tool in ["mock_rustc", "mock_rustdoc"]:
        write_file(name = tool, out = tool + ".exe", content = [], is_executable = True)

def _pdb_test_impl(env, target):
    pdb_files = getattr(target[OutputGroupInfo], "pdb_file", depset()).to_list()
    env.expect.that_collection([f.basename for f in pdb_files]).contains_exactly([target.label.name + ".pdb"])

    rustc = [a for a in target.actions if a.mnemonic == "Rustc"]
    env.expect.that_int(len(rustc)).equals(1)
    env.expect.that_collection(rustc[0].outputs.to_list()).contains_at_least(pdb_files)

def _pdb_test(name, compilation_mode, rule = rust_binary, src = "main.rs"):
    util.helper_target(
        rule,
        name = name + "_target",
        srcs = [src],
        edition = "2021",
    )

    analysis_test(
        name = name,
        target = ":" + name + "_target",
        impl = _pdb_test_impl,
        config_settings = {
            # The mock toolchain cannot execute, so coverage must not build the binary.
            "//command_line_option:collect_code_coverage": False,
            "//command_line_option:compilation_mode": compilation_mode,
            "//command_line_option:extra_toolchains": [
                str(Label(":rust_toolchain")),
                str(Label(":cc_toolchain")),
            ],
            "//command_line_option:platforms": str(Label(":windows_msvc")),
        },
    )

def _pdb_dbg_test(name):
    _pdb_test(name, "dbg")

def _pdb_fastbuild_test(name):
    _pdb_test(name, "fastbuild")

def _pdb_opt_test(name):
    _pdb_test(name, "opt")

def _pdb_cdylib_opt_test(name):
    _pdb_test(name, "opt", rule = rust_shared_library, src = "lib.rs")

def msvc_pdb_test_suite(name):
    """Entry-point macro for the MSVC PDB output tests.

    Args:
        name: test suite name
    """
    _define_mock_toolchains()

    test_suite(
        name = name,
        tests = [
            _pdb_dbg_test,
            _pdb_fastbuild_test,
            _pdb_opt_test,
            _pdb_cdylib_opt_test,
        ],
    )

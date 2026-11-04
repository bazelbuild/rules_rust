"""Analysis test for for rust_bindgen_library rule."""

load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_cc//cc:action_names.bzl", "ALL_CPP_COMPILE_ACTION_NAMES")
load("@rules_cc//cc:cc_toolchain_config_lib.bzl", "feature", "flag_group", "flag_set")
load("@rules_cc//cc:defs.bzl", "cc_library", "cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/toolchains:cc_toolchain_config_info.bzl", "CcToolchainConfigInfo")
load("@rules_rust//cargo:defs.bzl", "cargo_toolchain")
load("@rules_rust//rust:defs.bzl", "rust_binary")
load("@rules_rust//rust:toolchain.bzl", "rust_stdlib_filegroup", "rust_toolchain")
load("@rules_rust_bindgen//:defs.bzl", "rust_bindgen_library")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching")

def _fake_cc_toolchain_config_impl(ctx):
    xclang_flags_feature = feature(
        name = "xclang_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = ALL_CPP_COMPILE_ACTION_NAMES,
                flag_groups = [
                    flag_group(flags = [
                        "-Xclang",
                        "-fexperimental-optimized-noescape",
                        "-Xclang",
                        "-fcolor-diagnostics",
                        "--target=here",
                        "-target",
                        "there",
                        "-notarget",
                        "idbeholdi",
                    ]),
                ],
            ),
        ],
    )

    # Bazel automatically enables the feature named after the current compilation mode, so this only
    # applies to `-c opt` builds. The flags mirror the default opt flags in
    # @rules_cc//cc/private/toolchain/unix_cc_configure.bzl, which include both an optimization
    # level and `-D_FORTIFY_SOURCE` (`_FORTIFY_SOURCE` requires optimization).
    opt_feature = feature(
        name = "opt",
        flag_sets = [
            flag_set(
                actions = ALL_CPP_COMPILE_ACTION_NAMES,
                flag_groups = [
                    flag_group(flags = [
                        "-O2",
                        "-D_FORTIFY_SOURCE=1",
                    ]),
                ],
            ),
        ],
    )

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        toolchain_identifier = "fake-toolchain",
        host_system_name = "unknown",
        target_system_name = "unknown",
        target_cpu = "unknown",
        target_libc = "unknown",
        compiler = "unknown",
        abi_version = "unknown",
        abi_libc_version = "unknown",
        features = [xclang_flags_feature, opt_feature],
        # Add a known include directory to ensure that it is not removed by bindgen.
        cxx_builtin_include_directories = ["/fake/builtin/sys/include"],
    )

_fake_cc_toolchain_config = rule(
    implementation = _fake_cc_toolchain_config_impl,
    attrs = {},
    provides = [CcToolchainConfigInfo],
)

def _fake_cc_toolchain(name):
    _fake_cc_toolchain_config(name = name + "_toolchain_config")

    empty_filegroup = name + "_empty_filegroup"
    native.filegroup(name = empty_filegroup)

    stdbool_file = name + "_stdbool"
    write_file(
        name = stdbool_file,
        content = [],
        out = name + "/resource/dir/include/stdbool.h",
    )

    all_files = name + "_all_files"
    native.filegroup(name = all_files, srcs = [stdbool_file])

    cc_toolchain(
        name = name + "_cc_toolchain",
        toolchain_config = name + "_toolchain_config",
        all_files = all_files,
        dwp_files = empty_filegroup,
        compiler_files = empty_filegroup,
        linker_files = empty_filegroup,
        objcopy_files = empty_filegroup,
        strip_files = empty_filegroup,
    )

    native.toolchain(
        name = name,
        toolchain = name + "_cc_toolchain",
        toolchain_type = "@rules_cc//cc:toolchain_type",
    )

def _create_simple_rust_bindgen_library(test_name):
    cc_library(
        name = test_name + "_cc",
        hdrs = ["simple.h"],
        srcs = ["simple.cc"],
    )

    rust_bindgen_library(
        name = test_name + "_rust_bindgen",
        cc_lib = test_name + "_cc",
        header = "simple.h",
        tags = ["manual"],
        edition = "2021",
    )

def _test_cc_linkopt_impl(env, target):
    # Assert
    env.expect.that_action(target.actions[0]) \
        .contains_at_least_args(["--codegen=link-arg=-shared"])

def _test_cc_linkopt(name):
    # Arrange
    cc_library(
        name = name + "_cc",
        srcs = ["simple.cc"],
        hdrs = ["simple.h"],
        linkopts = ["-shared"],
        tags = ["manual"],
    )
    rust_bindgen_library(
        name = name + "_rust_bindgen",
        cc_lib = name + "_cc",
        header = "simple.h",
        tags = ["manual"],
        edition = "2021",
    )
    rust_binary(
        name = name + "_rust_binary",
        srcs = ["main.rs"],
        deps = [name + "_rust_bindgen"],
        tags = ["manual"],
        edition = "2021",
    )

    # Act
    # TODO: Use targets attr to also verify `rust_bindgen_library` not having
    # the linkopt after https://github.com/bazelbuild/rules_testing/issues/67
    # is released
    analysis_test(
        name = name,
        target = name + "_rust_binary",
        impl = _test_cc_linkopt_impl,
    )

def _test_cc_lib_object_merging_impl(env, target):
    env.expect.that_int(len(target.actions)).is_greater_than(2)
    env.expect.that_action(target.actions[0]).mnemonic().contains("RustBindgen")
    env.expect.that_action(target.actions[1]).mnemonic().contains("FileWrite")
    env.expect.that_action(target.actions[1]).content().contains("-lstatic=test_cc_lib_object_merging_cc")
    env.expect.that_action(target.actions[2]).mnemonic().contains("FileWrite")
    env.expect.that_action(target.actions[2]).content().contains("-Lnative=")

def _test_cc_lib_object_merging_disabled_impl(env, target):
    # no FileWrite actions writing arg files registered
    env.expect.that_int(len(target.actions)).is_greater_than(0)
    env.expect.that_action(target.actions[0]).mnemonic().contains("RustBindgen")

def _test_cc_lib_object_merging(name):
    cc_library(
        name = name + "_cc",
        hdrs = ["simple.h"],
        srcs = ["simple.cc"],
    )

    rust_bindgen_library(
        name = name + "_rust_bindgen",
        cc_lib = name + "_cc",
        header = "simple.h",
        tags = ["manual"],
        edition = "2021",
    )

    analysis_test(
        name = name,
        target = name + "_rust_bindgen__bindgen",
        impl = _test_cc_lib_object_merging_impl,
    )

def _test_cc_lib_object_merging_disabled(name):
    cc_library(
        name = name + "_cc",
        hdrs = ["simple.h"],
        srcs = ["simple.cc"],
    )

    rust_bindgen_library(
        name = name + "_rust_bindgen",
        cc_lib = name + "_cc",
        header = "simple.h",
        tags = ["manual"],
        merge_cc_lib_objects_into_rlib = False,
        edition = "2021",
    )

    analysis_test(
        name = name,
        target = name + "_rust_bindgen__bindgen",
        impl = _test_cc_lib_object_merging_disabled_impl,
    )

def _test_resource_dir_impl(env, target):
    env.expect.that_int(len(target.actions)).is_greater_than(0)
    env.expect.that_action(target.actions[0]).mnemonic().contains("RustBindgen")
    env.expect.that_action(target.actions[0]).contains_at_least_args(
        ["-isystem", "/fake/builtin/sys/include"],
    )
    env.expect.that_action(target.actions[0]).argv().contains_predicate(
        matching.all(
            matching.str_startswith("-resource-dir="),
            matching.str_endswith("/resource/dir"),
        ),
    )

def _test_resource_dir(name):
    _fake_cc_toolchain(name + "_toolchain")

    _create_simple_rust_bindgen_library(name)

    analysis_test(
        name = name,
        target = name + "_rust_bindgen__bindgen",
        impl = _test_resource_dir_impl,
        config_settings = {
            "//command_line_option:extra_toolchains": [str(native.package_relative_label(name + "_toolchain"))],
        },
    )

def _test_strip_xclang_impl(env, target):
    env.expect.that_int(len(target.actions)).is_greater_than(0)
    env.expect.that_action(target.actions[0]).mnemonic().contains("RustBindgen")
    env.expect.that_action(target.actions[0]).contains_at_least_args(
        ["-isystem", "/fake/builtin/sys/include"],
    )
    env.expect.that_action(target.actions[0]).not_contains_arg(
        "-fexperimental-optimized-noescape",
    )
    env.expect.that_action(target.actions[0]).not_contains_arg(
        "-notarget",
    )
    env.expect.that_action(target.actions[0]).not_contains_arg(
        "idbeholdi",
    )
    env.expect.that_action(target.actions[0]).contains_at_least_args(
        ["-Xclang", "-fcolor-diagnostics", "--target=here", "-target", "there"],
    )

def _test_strip_xclang(name):
    # Test that we strip certain `-Xclang` flags defined by forks of Clang
    # that upstream Clang doesn't know about, such as
    # `-fexperimental-optimized-noescape`. (This is added by the toolchain.)

    _fake_cc_toolchain(name + "_toolchain")

    _create_simple_rust_bindgen_library(name)

    analysis_test(
        name = name,
        target = name + "_rust_bindgen__bindgen",
        impl = _test_strip_xclang_impl,
        config_settings = {
            "//command_line_option:extra_toolchains": [str(native.package_relative_label(name + "_toolchain"))],
        },
    )

def _test_isystem_preservation_impl(env, target):
    env.expect.that_int(len(target.actions)).is_greater_than(0)
    env.expect.that_action(target.actions[0]).mnemonic().contains("RustBindgen")
    env.expect.that_action(target.actions[0]).contains_at_least_args(
        ["-isystem", "/fake/builtin/sys/include"],
    )
    env.expect.that_action(target.actions[0]).contains_at_least_args(
        ["-isystem", "third_party/custom_sys/include"],
    )

def _test_isystem_preservation(name):
    # Test that specifying and `-isystem` flag in `clang_flags`:
    # 1) Gets passed through the bindgen invocation
    # 2) Does not cause other `-isystem` flags that come from the toolchain to
    #    be overwritten.

    _fake_cc_toolchain(name + "_toolchain")

    cc_library(
        name = name + "_cc",
        hdrs = ["simple.h"],
        srcs = ["simple.cc"],
    )

    rust_bindgen_library(
        name = name + "_rust_bindgen",
        cc_lib = name + "_cc",
        header = "simple.h",
        clang_flags = [
            "-isystem",
            "third_party/custom_sys/include",
        ],
        tags = ["manual"],
        edition = "2021",
    )

    analysis_test(
        name = name,
        target = name + "_rust_bindgen__bindgen",
        impl = _test_isystem_preservation_impl,
        config_settings = {
            "//command_line_option:extra_toolchains": [str(native.package_relative_label(name + "_toolchain"))],
        },
    )

def _test_optimization_flags_impl(env, target):
    env.expect.that_int(len(target.actions)).is_greater_than(0)
    env.expect.that_action(target.actions[0]).mnemonic().contains("RustBindgen")

    # The optimization level from the CC toolchain has to reach Clang. Without it, Clang
    # predefines neither `__OPTIMIZE__` nor `__NO_INLINE__`, so headers guarded on those parse
    # differently than they do for the rest of the build. Here that shows up via
    # `-D_FORTIFY_SOURCE=1`, which reaches Clang as a plain `-D` and warns without `-O`.
    env.expect.that_action(target.actions[0]).contains_at_least_args(
        ["-O2", "-D_FORTIFY_SOURCE=1"],
    )

def _test_optimization_flags(name):
    _fake_cc_toolchain(name + "_toolchain")

    _create_simple_rust_bindgen_library(name)

    analysis_test(
        name = name,
        target = name + "_rust_bindgen__bindgen",
        impl = _test_optimization_flags_impl,
        config_settings = {
            "//command_line_option:compilation_mode": "opt",
            "//command_line_option:extra_toolchains": [str(native.package_relative_label(name + "_toolchain"))],
        },
    )

def _fake_rust_toolchain(name, version):
    """Registers mock `rust_toolchain` and `cargo_toolchain`s that declare `version`.

    The toolchains are only ever used for analysis (the tests never execute
    `rustc` or `cargo`), so empty executables and an arbitrary file standing in
    for the standard library are sufficient.

    `--extra_toolchains` applies to every configuration, including the exec
    configuration that builds the bindgen CLI and its crates. Their
    `cargo_build_script` targets fail analysis when the `rust_toolchain` and
    `cargo_toolchain` they resolve disagree on `version`, so a `cargo_toolchain`
    stating the same `version` is registered together with the `rust_toolchain`.

    Returns:
        list: The labels of the `toolchain` targets, to be passed to
            `--extra_toolchains` together.
    """
    mock_rustc = name + "_mock_rustc"
    write_file(
        name = mock_rustc,
        out = name + "/mock_rustc.exe",
        content = [],
        is_executable = True,
    )

    mock_rustdoc = name + "_mock_rustdoc"
    write_file(
        name = mock_rustdoc,
        out = name + "/mock_rustdoc.exe",
        content = [],
        is_executable = True,
    )

    mock_cargo = name + "_mock_cargo"
    write_file(
        name = mock_cargo,
        out = name + "/mock_cargo.exe",
        content = [],
        is_executable = True,
    )

    std_libs = name + "_std_libs"
    rust_stdlib_filegroup(
        name = std_libs,
        srcs = [mock_rustc],
    )

    rust_toolchain(
        name = name + "_rust_toolchain",
        binary_ext = "",
        default_edition = "2021",
        dylib_ext = ".so",
        exec_triple = "x86_64-unknown-linux-gnu",
        rust_doc = mock_rustdoc,
        rust_std = std_libs,
        rustc = mock_rustc,
        staticlib_ext = ".a",
        stdlib_linkflags = [],
        target_triple = "x86_64-unknown-linux-gnu",
        version = version,
    )

    native.toolchain(
        name = name,
        toolchain = name + "_rust_toolchain",
        toolchain_type = "@rules_rust//rust:toolchain_type",
    )

    cargo_toolchain(
        name = name + "_cargo_toolchain",
        cargo = mock_cargo,
        version = version,
    )

    native.toolchain(
        name = name + "_cargo",
        toolchain = name + "_cargo_toolchain",
        toolchain_type = "@rules_rust//cargo:toolchain_type",
    )

    return [
        str(native.package_relative_label(name)),
        str(native.package_relative_label(name + "_cargo")),
    ]

def _test_rust_target_from_prerelease_version_impl(env, target):
    env.expect.that_int(len(target.actions)).is_greater_than(0)
    env.expect.that_action(target.actions[0]).mnemonic().contains("RustBindgen")

    # bindgen only accepts `MAJOR.MINOR[.PATCH]` (or the literal `nightly`) for
    # `--rust-target`; a pre-release suffix such as `-nightly` makes it fail with
    # "the patch version number must be an unsigned 64-bit integer".
    env.expect.that_action(target.actions[0]).contains_at_least_args(
        ["--rust-target=1.87.0"],
    )
    env.expect.that_action(target.actions[0]).not_contains_arg(
        "--rust-target=1.87.0-nightly",
    )

def _test_rust_target_from_prerelease_version(name):
    # Test that a `rust_toolchain` declaring a pre-release `version` (as
    # toolchains built from a nightly commit do) results in a plain
    # `MAJOR.MINOR.PATCH` `--rust-target`.

    toolchains = _fake_rust_toolchain(name + "_toolchain", version = "1.87.0-nightly")

    _create_simple_rust_bindgen_library(name)

    analysis_test(
        name = name,
        target = name + "_rust_bindgen__bindgen",
        impl = _test_rust_target_from_prerelease_version_impl,
        config_settings = {
            "//command_line_option:extra_toolchains": toolchains,
        },
    )

def _test_no_rust_target_for_channel_label_impl(env, target):
    env.expect.that_int(len(target.actions)).is_greater_than(0)
    env.expect.that_action(target.actions[0]).mnemonic().contains("RustBindgen")
    env.expect.that_action(target.actions[0]).argv().not_contains_predicate(
        matching.str_startswith("--rust-target="),
    )

def _test_no_rust_target_for_channel_label(name):
    # Test that a `rust_toolchain` whose `version` is a bare channel label
    # (`nightly`, `beta`) does not produce a `--rust-target` flag, leaving
    # bindgen on its built-in default.

    toolchains = _fake_rust_toolchain(name + "_toolchain", version = "nightly")

    _create_simple_rust_bindgen_library(name)

    analysis_test(
        name = name,
        target = name + "_rust_bindgen__bindgen",
        impl = _test_no_rust_target_for_channel_label_impl,
        config_settings = {
            "//command_line_option:extra_toolchains": toolchains,
        },
    )

def bindgen_test_suite(name):
    test_suite(
        name = name,
        tests = [
            _test_cc_linkopt,
            _test_cc_lib_object_merging,
            _test_cc_lib_object_merging_disabled,
            _test_resource_dir,
            _test_strip_xclang,
            _test_isystem_preservation,
            _test_optimization_flags,
            _test_rust_target_from_prerelease_version,
            _test_no_rust_target_for_channel_label,
        ],
    )

"""Unittest to verify properties of rustdoc rules"""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_cc//cc:defs.bzl", "cc_library")
load("//cargo:defs.bzl", "cargo_build_script")
load(
    "//rust:defs.bzl",
    "rust_binary",
    "rust_doc",
    "rust_doc_test",
    "rust_library",
    "rust_proc_macro",
    "rust_test",
)
load(
    "//test/unit:common.bzl",
    "assert_action_mnemonic",
    "assert_argv_contains",
    "assert_argv_contains_prefix_not",
)

# TODO: `rust_doc_test` currently does not work on Windows.
# https://github.com/bazelbuild/rules_rust/issues/1156
NOT_WINDOWS = select({
    "@platforms//os:windows": ["@platforms//:incompatible"],
    "//conditions:default": [],
})

def _get_rustdoc_action(env, tut):
    actions = tut.actions
    action = actions[0]
    assert_action_mnemonic(env, action, "Rustdoc")

    return action

def _common_rustdoc_checks(env, tut):
    action = _get_rustdoc_action(env, tut)

    # These flags, while required for `Rustc` actions, should be omitted for
    # `Rustdoc` actions
    assert_argv_contains_prefix_not(env, action, "--remap-path-prefix")
    assert_argv_contains_prefix_not(env, action, "--emit")

def _rustdoc_for_lib_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    _common_rustdoc_checks(env, tut)

    return analysistest.end(env)

def _rustdoc_for_bin_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    _common_rustdoc_checks(env, tut)

    return analysistest.end(env)

def _rustdoc_for_bin_with_cc_lib_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    _common_rustdoc_checks(env, tut)

    return analysistest.end(env)

def _rustdoc_for_bin_with_transitive_cc_lib_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    _common_rustdoc_checks(env, tut)

    return analysistest.end(env)

def _rustdoc_for_proc_macro_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    _common_rustdoc_checks(env, tut)

    return analysistest.end(env)

def _rustdoc_for_lib_with_proc_macro_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    _common_rustdoc_checks(env, tut)

    return analysistest.end(env)

def _rustdoc_for_lib_with_proc_macro_in_docs_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    _common_rustdoc_checks(env, tut)

    return analysistest.end(env)

def _rustdoc_for_bin_with_transitive_proc_macro_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    _common_rustdoc_checks(env, tut)

    return analysistest.end(env)

def _rustdoc_for_lib_with_cc_lib_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    _common_rustdoc_checks(env, tut)

    return analysistest.end(env)

def _rustdoc_with_args_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    _common_rustdoc_checks(env, tut)

    action = _get_rustdoc_action(env, tut)

    assert_argv_contains(env, action, "--allow=rustdoc::broken_intra_doc_links")

    return analysistest.end(env)

def _rustdoc_zip_output_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    files = tut[DefaultInfo].files.to_list()
    asserts.equals(
        env,
        len(files),
        1,
        "The target under this test should have 1 DefaultInfo file but has {}".format(
            len(files),
        ),
    )

    zip_file = files[0]
    asserts.true(
        env,
        zip_file.basename.endswith(".zip"),
        "{} did not end with `.zip`".format(
            zip_file.path,
        ),
    )

    return analysistest.end(env)

def _rustdoc_with_json_error_format_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    _common_rustdoc_checks(env, tut)

    action = _get_rustdoc_action(env, tut)

    assert_argv_contains(env, action, "--error-format=json")

    return analysistest.end(env)

def _rustdoc_test_uses_cc_library_native_lib_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = tut.actions[0]

    asserts.true(
        env,
        action.mnemonic in ["RustdocTestWriter", "RustdocTestCompile"],
        "Expected RustdocTestWriter or RustdocTestCompile, got {}".format(action.mnemonic),
    )
    asserts.true(
        env,
        "-Clink-arg=-lrustdoc_cc_library" in action.argv or "-Clink-arg=-lrustdoc_cc_library.pic" in action.argv,
        "Expected {} to contain a rustdoc_cc_library native link arg".format(action.argv),
    )

    return analysistest.end(env)

rustdoc_for_lib_test = analysistest.make(_rustdoc_for_lib_test_impl)
rustdoc_for_bin_test = analysistest.make(_rustdoc_for_bin_test_impl)
rustdoc_for_bin_with_cc_lib_test = analysistest.make(_rustdoc_for_bin_with_cc_lib_test_impl)
rustdoc_for_bin_with_transitive_cc_lib_test = analysistest.make(_rustdoc_for_bin_with_transitive_cc_lib_test_impl)
rustdoc_for_proc_macro_test = analysistest.make(_rustdoc_for_proc_macro_test_impl)
rustdoc_for_lib_with_proc_macro_test = analysistest.make(_rustdoc_for_lib_with_proc_macro_test_impl)
rustdoc_for_lib_with_proc_macro_in_docs_test = analysistest.make(_rustdoc_for_lib_with_proc_macro_in_docs_test_impl)
rustdoc_for_bin_with_transitive_proc_macro_test = analysistest.make(_rustdoc_for_bin_with_transitive_proc_macro_test_impl)
rustdoc_for_lib_with_cc_lib_test = analysistest.make(_rustdoc_for_lib_with_cc_lib_test_impl)
rustdoc_with_args_test = analysistest.make(_rustdoc_with_args_test_impl)
rustdoc_zip_output_test = analysistest.make(_rustdoc_zip_output_test_impl)
rustdoc_with_json_error_format_test = analysistest.make(_rustdoc_with_json_error_format_test_impl, config_settings = {
    str(Label("//rust/settings:error_format")): "json",
})
rustdoc_test_uses_cc_library_native_lib_test = analysistest.make(_rustdoc_test_uses_cc_library_native_lib_test_impl)

def _compiled_runner_file(target):
    executable = target[DefaultInfo].files_to_run.executable
    action = [action for action in target.actions if executable in action.outputs.to_list()][0]
    return action.inputs.to_list()[0]

def _compiled_runner_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    runner = _compiled_runner_file(target)
    executable = target[DefaultInfo].files_to_run.executable

    asserts.true(env, any([action.mnemonic == "RustdocTestCompile" for action in target.actions]))
    asserts.equals(env, runner.extension, executable.extension)
    return analysistest.end(env)

compiled_runner_test = analysistest.make(
    _compiled_runner_test_impl,
)

def _compiled_runner_platform_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    runner = _compiled_runner_file(target)
    asserts.true(
        env,
        runner.path.startswith("bazel-out/macos_x86_64-"),
        "Expected the test-platform runner, got {}".format(runner.path),
    )
    return analysistest.end(env)

compiled_runner_platform_test = analysistest.make(
    _compiled_runner_platform_test_impl,
    config_settings = {
        "//command_line_option:extra_execution_platforms": [
            str(Label(":macos_aarch64")),
            str(Label(":macos_x86_64")),
        ],
        "//command_line_option:platforms": str(Label(":macos_x86_64")),
    },
)

def _legacy_cross_build_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "Cross-built doctests require experimental_compile_rustdoc_tests")
    return analysistest.end(env)

legacy_cross_build_test = analysistest.make(
    _legacy_cross_build_test_impl,
    expect_failure = True,
    config_settings = {
        "//command_line_option:extra_execution_platforms": [
            str(Label(":macos_aarch64")),
            str(Label(":macos_x86_64")),
        ],
        "//command_line_option:platforms": str(Label(":macos_x86_64")),
        str(Label("//rust/settings:experimental_compile_rustdoc_tests")): False,
    },
)

def _target_maker(rule_fn, name, rustdoc_deps = [], rustdoc_proc_macro_deps = [], **kwargs):
    rule_fn(
        name = name,
        edition = "2018",
        **kwargs
    )

    rust_test(
        name = "{}_test".format(name),
        crate = ":{}".format(name),
        edition = "2018",
    )

    rust_doc(
        name = "{}_doc".format(name),
        crate = ":{}".format(name),
    )

    rust_doc_test(
        name = "{}_doctest".format(name),
        crate = ":{}".format(name),
        deps = rustdoc_deps,
        proc_macro_deps = rustdoc_proc_macro_deps,
        target_compatible_with = NOT_WINDOWS,
    )

def _rustdoc_for_generated_root_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    _common_rustdoc_checks(env, tut)

    return analysistest.end(env)

rustdoc_for_generated_root_test = analysistest.make(_rustdoc_for_generated_root_test_impl)

def _define_targets():
    rust_library(
        name = "adder",
        srcs = ["adder.rs"],
        edition = "2018",
    )

    write_file(
        name = "gen_lib_src",
        out = "gen_lib.rs",
        content = [
            "/// One.",
            "/// ```",
            "/// assert_eq!(1, 1);",
            "/// ```",
            "pub fn one() -> u32 { 1 }",
            "",
        ],
    )

    rust_library(
        name = "gen_lib",
        srcs = [":gen_lib.rs"],
        edition = "2021",
    )

    rust_doc(
        name = "gen_lib_doc",
        crate = ":gen_lib",
    )

    rust_doc_test(
        name = "gen_lib_doc_test",
        crate = ":gen_lib",
        target_compatible_with = NOT_WINDOWS,
    )

    _target_maker(
        rust_binary,
        name = "bin",
        srcs = ["rustdoc_bin.rs"],
    )

    _target_maker(
        rust_binary,
        name = "bin_with_cc",
        srcs = ["rustdoc_bin.rs"],
        crate_features = ["with_cc"],
        deps = [":cc_lib"],
    )

    _target_maker(
        rust_binary,
        name = "bin_with_transitive_cc",
        srcs = ["rustdoc_bin.rs"],
        crate_features = ["with_cc"],
        deps = [":transitive_cc_lib"],
    )

    _target_maker(
        rust_library,
        name = "lib",
        srcs = ["rustdoc_lib.rs"],
        rustdoc_deps = [":adder"],
    )

    _target_maker(
        rust_library,
        name = "nodep_lib",
        srcs = ["rustdoc_nodep_lib.rs"],
    )

    _target_maker(
        rust_proc_macro,
        name = "rustdoc_proc_macro",
        srcs = ["rustdoc_proc_macro.rs"],
    )

    _target_maker(
        rust_library,
        name = "lib_with_proc_macro",
        srcs = ["rustdoc_lib.rs"],
        rustdoc_deps = [":adder"],
        proc_macro_deps = [":rustdoc_proc_macro"],
        crate_features = ["with_proc_macro"],
    )

    _target_maker(
        rust_library,
        name = "lib_with_proc_macro_in_docs",
        srcs = ["procmacro_in_rustdoc.rs"],
        proc_macro_deps = [":rustdoc_proc_macro"],
    )

    _target_maker(
        rust_library,
        name = "lib_with_proc_macro_only_in_docs",
        srcs = ["procmacro_in_rustdoc.rs"],
        rustdoc_proc_macro_deps = [":rustdoc_proc_macro"],
    )

    _target_maker(
        rust_library,
        name = "lib_nodep_with_proc_macro",
        srcs = ["rustdoc_nodep_lib.rs"],
        proc_macro_deps = [":rustdoc_proc_macro"],
        crate_features = ["with_proc_macro"],
    )

    _target_maker(
        rust_binary,
        name = "bin_with_transitive_proc_macro",
        srcs = ["rustdoc_bin.rs"],
        deps = [":lib_with_proc_macro"],
        proc_macro_deps = [":rustdoc_proc_macro"],
        crate_features = ["with_proc_macro"],
    )

    cc_library(
        name = "cc_lib",
        hdrs = ["rustdoc.h"],
        srcs = ["rustdoc.cc"],
    )

    cc_library(
        name = "transitive_cc_lib",
        hdrs = ["rustdoc.h"],
        srcs = ["rustdoc.cc"],
        deps = [":cc_lib"],
        # Exercises propagation of system-library `-l` linkopts. Picks a
        # library guaranteed to exist on each platform so the `-l` flag
        # resolves without depending on any cc_library artifact name (which
        # would gain a `.pic` suffix when consumers request PIC).
        linkopts = select({
            "@platforms//os:windows": ["-luser32"],
            "//conditions:default": ["-lm"],
        }),
        linkstatic = True,
    )

    _target_maker(
        rust_library,
        name = "lib_with_cc",
        srcs = ["rustdoc_lib.rs"],
        rustdoc_deps = [":adder"],
        crate_features = ["with_cc"],
        deps = [":cc_lib"],
    )

    _target_maker(
        rust_library,
        name = "lib_nodep_with_cc",
        srcs = ["rustdoc_nodep_lib.rs"],
        crate_features = ["with_cc"],
        deps = [":cc_lib"],
    )

    _target_maker(
        rust_library,
        name = "lib_depends_on_native",
        srcs = ["rustdoc_depends_on_native.rs"],
        deps = [":lib_nodep_with_cc"],
    )

    cc_library(
        name = "rustdoc_cc_library",
        hdrs = ["rustdoc.h"],
        srcs = ["rustdoc.cc"],
    )

    _target_maker(
        rust_library,
        name = "lib_with_cc_library",
        srcs = ["rustdoc_nodep_lib.rs"],
        crate_features = ["with_cc"],
        deps = [":rustdoc_cc_library"],
    )

    cargo_build_script(
        name = "lib_build_script",
        srcs = ["rustdoc_build.rs"],
        edition = "2018",
    )

    _target_maker(
        rust_library,
        name = "lib_with_build_script",
        srcs = ["rustdoc_lib.rs"],
        rustdoc_deps = [":adder"],
        crate_features = ["with_build_script"],
        deps = [":lib_build_script"],
    )

    _target_maker(
        rust_library,
        name = "lib_nodep_with_build_script",
        srcs = ["rustdoc_nodep_lib.rs"],
        crate_features = ["with_build_script"],
        deps = [":lib_build_script"],
    )

    rust_library(
        name = "lib_requires_args",
        srcs = ["rustdoc_requires_args.rs"],
        edition = "2018",
    )

    rust_doc(
        name = "rustdoc_with_args",
        crate = ":lib_requires_args",
        rustdoc_flags = [
            "--allow=rustdoc::broken_intra_doc_links",
        ],
    )

    rust_library(
        name = "lib_dep_with_alias",
        srcs = ["rustdoc_test_dep_with_alias.rs"],
        edition = "2018",
        deps = [":adder"],
        aliases = {
            ":adder": "aliased_adder",
        },
    )

    rust_doc_test(
        name = "rustdoc_test_with_alias_test",
        crate = ":lib_dep_with_alias",
        target_compatible_with = NOT_WINDOWS,
    )

    rust_doc_test(
        name = "compiled_runner_fixture",
        crate = ":lib",
        deps = [":adder"],
        tags = ["manual"],
    )

def rustdoc_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """

    _define_targets()

    rustdoc_for_lib_test(
        name = "rustdoc_for_lib_test",
        target_under_test = ":lib_doc",
    )

    rustdoc_for_bin_test(
        name = "rustdoc_for_bin_test",
        target_under_test = ":bin_doc",
    )

    rustdoc_for_bin_with_cc_lib_test(
        name = "rustdoc_for_bin_with_cc_lib_test",
        target_under_test = ":bin_with_cc_doc",
    )

    rustdoc_for_bin_with_transitive_cc_lib_test(
        name = "rustdoc_for_bin_with_transitive_cc_lib_test",
        target_under_test = ":bin_with_transitive_cc_doc",
    )

    rustdoc_for_proc_macro_test(
        name = "rustdoc_for_proc_macro_test",
        target_under_test = ":rustdoc_proc_macro_doc",
    )

    rustdoc_for_lib_with_proc_macro_in_docs_test(
        name = "rustdoc_for_lib_with_proc_macro_in_docs_test",
        target_under_test = ":lib_with_proc_macro_in_docs_doc",
    )

    rustdoc_for_lib_with_proc_macro_test(
        name = "rustdoc_for_lib_with_proc_macro_test",
        target_under_test = ":lib_with_proc_macro_doc",
    )

    rustdoc_for_bin_with_transitive_proc_macro_test(
        name = "rustdoc_for_bin_with_transitive_proc_macro_test",
        target_under_test = ":bin_with_transitive_proc_macro_doc",
    )

    rustdoc_for_lib_with_cc_lib_test(
        name = "rustdoc_for_lib_with_cc_lib_test",
        target_under_test = ":lib_with_cc_doc",
    )

    rustdoc_with_args_test(
        name = "rustdoc_with_args_test",
        target_under_test = ":rustdoc_with_args",
    )

    rustdoc_with_json_error_format_test(
        name = "rustdoc_with_json_error_format_test",
        target_under_test = ":lib_doc",
    )

    rustdoc_test_uses_cc_library_native_lib_test(
        name = "rustdoc_test_uses_cc_library_native_lib_test",
        target_under_test = ":lib_with_cc_library_doctest",
    )

    compiled_runner_test(
        name = "compiled_runner_test",
        target_compatible_with = select({
            ":compiled_doctests": [],
            "//conditions:default": ["@platforms//:incompatible"],
        }),
        target_under_test = ":compiled_runner_fixture",
    )

    compiled_runner_platform_test(
        name = "compiled_runner_platform_test",
        target_under_test = ":compiled_runner_fixture",
        target_compatible_with = [
            "@platforms//cpu:aarch64",
            "@platforms//os:macos",
        ] + ([] if bazel_features.toolchains.has_default_test_toolchain_type else ["@platforms//:incompatible"]) + select({
            ":compiled_doctests": [],
            "//conditions:default": ["@platforms//:incompatible"],
        }),
    )

    legacy_cross_build_test(
        name = "legacy_cross_build_test",
        target_under_test = ":lib_doctest",
        target_compatible_with = [
            "@platforms//cpu:aarch64",
            "@platforms//os:macos",
        ],
    )

    rustdoc_for_generated_root_test(
        name = "rustdoc_for_generated_root_test",
        target_under_test = ":gen_lib_doc",
    )

    native.filegroup(
        name = "lib_doc_zip",
        srcs = [":lib_doc.zip"],
    )

    rustdoc_zip_output_test(
        name = "rustdoc_zip_output_test",
        target_under_test = ":lib_doc_zip",
    )

    native.test_suite(
        name = name,
        tests = [
            ":rustdoc_for_lib_test",
            ":rustdoc_for_bin_test",
            ":rustdoc_for_bin_with_cc_lib_test",
            ":rustdoc_for_bin_with_transitive_cc_lib_test",
            ":rustdoc_for_proc_macro_test",
            ":rustdoc_for_lib_with_proc_macro_in_docs_test",
            ":rustdoc_for_lib_with_proc_macro_test",
            ":rustdoc_for_lib_with_cc_lib_test",
            ":rustdoc_with_args_test",
            ":rustdoc_with_json_error_format_test",
            ":rustdoc_test_uses_cc_library_native_lib_test",
            ":compiled_runner_test",
            ":compiled_runner_platform_test",
            ":legacy_cross_build_test",
            ":rustdoc_for_generated_root_test",
            ":rustdoc_zip_output_test",
        ],
    )

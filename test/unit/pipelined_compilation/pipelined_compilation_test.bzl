"""Unittests for rust rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_proc_macro")
load("//test/unit:common.bzl", "assert_argv_contains", "assert_list_contains_adjacent_elements", "assert_list_contains_adjacent_elements_not")

def _second_lib_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    rlib_action = [act for act in tut.actions if act.mnemonic == "Rustc"][0]
    metadata_action = [act for act in tut.actions if act.mnemonic == "RustcMetadata"][0]

    # Both actions should use the same --emit=
    assert_argv_contains(env, rlib_action, "--emit=dep-info,link,metadata")
    assert_argv_contains(env, metadata_action, "--emit=dep-info,link,metadata")

    # The metadata action should have a .rmeta as output and the rlib action a .rlib
    path = rlib_action.outputs.to_list()[0].path
    asserts.true(
        env,
        path.endswith(".rlib"),
        "expected Rustc to output .rlib, got " + path,
    )
    path = metadata_action.outputs.to_list()[0].path
    asserts.true(
        env,
        path.endswith(".rmeta"),
        "expected RustcMetadata to output .rmeta, got " + path,
    )

    # Only the action building metadata should contain --rustc-quit-on-rmeta
    assert_list_contains_adjacent_elements_not(env, rlib_action.argv, ["--rustc-quit-on-rmeta", "true"])
    assert_list_contains_adjacent_elements(env, metadata_action.argv, ["--rustc-quit-on-rmeta", "true"])

    # Check that both actions refer to the metadata of :first, not the rlib
    extern_metadata = [arg for arg in metadata_action.argv if arg.startswith("--extern=first=") and "libfirst" in arg and arg.endswith(".rmeta")]
    asserts.true(
        env,
        len(extern_metadata) == 1,
        "did not find a --extern=first=*.rmeta but expected one",
    )
    extern_rlib = [arg for arg in rlib_action.argv if arg.startswith("--extern=first=") and "libfirst" in arg and arg.endswith(".rmeta")]
    asserts.true(
        env,
        len(extern_rlib) == 1,
        "did not find a --extern=first=*.rlib but expected one",
    )

    # Check that the input to both actions is the metadata of :first
    input_metadata = [i for i in metadata_action.inputs.to_list() if i.basename.startswith("libfirst")]
    asserts.true(env, len(input_metadata) == 1, "expected only one libfirst input, found " + str([i.path for i in input_metadata]))
    asserts.true(env, input_metadata[0].extension == "rmeta", "expected libfirst dependency to be rmeta, found " + input_metadata[0].path)
    input_rlib = [i for i in rlib_action.inputs.to_list() if i.basename.startswith("libfirst")]
    asserts.true(env, len(input_rlib) == 1, "expected only one libfirst input, found " + str([i.path for i in input_rlib]))
    asserts.true(env, input_rlib[0].extension == "rmeta", "expected libfirst dependency to be rmeta, found " + input_rlib[0].path)

    return analysistest.end(env)

def _bin_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    bin_action = [act for act in tut.actions if act.mnemonic == "Rustc"][0]

    # Check that no inputs to this binary are .rmeta files.
    metadata_inputs = [i.path for i in bin_action.inputs.to_list() if i.path.endswith(".rmeta")]
    asserts.false(env, metadata_inputs, "expected no metadata inputs, found " + str(metadata_inputs))

    return analysistest.end(env)

ENABLE_PIPELINING = {
    "@//rust/settings:pipelined_compilation": True,
}
bin_test = analysistest.make(_bin_test_impl, config_settings = ENABLE_PIPELINING)
second_lib_test = analysistest.make(_second_lib_test_impl, config_settings = ENABLE_PIPELINING)

def _pipelined_compilation_test():
    rust_proc_macro(
        name = "my_macro",
        edition = "2021",
        srcs = ["my_macro.rs"],
    )

    rust_library(
        name = "first",
        edition = "2021",
        srcs = ["first.rs"],
    )

    rust_library(
        name = "second",
        edition = "2021",
        srcs = ["second.rs"],
        deps = [":first"],
        proc_macro_deps = [":my_macro"],
    )

    rust_binary(
        name = "bin",
        edition = "2021",
        srcs = ["bin.rs"],
        deps = [":second"],
    )

    NOT_WINDOWS = select({
        "@platforms//os:linux": [],
        "@platforms//os:macos": [],
        "//conditions:default": ["@platforms//:incompatible"],
    })
    second_lib_test(name = "second_lib_test", target_under_test = ":second", target_compatible_with = NOT_WINDOWS)
    bin_test(name = "bin_test", target_under_test = ":bin", target_compatible_with = NOT_WINDOWS)

def pipelined_compilation_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _pipelined_compilation_test()

    native.test_suite(
        name = name,
        tests = [
            ":bin_test",
            ":second_lib_test",
        ],
    )

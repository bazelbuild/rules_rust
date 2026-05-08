"""Tests for cargo_build_script `data` propagation into Rustc compile actions.

See https://github.com/bazelbuild/rules_rust/issues/3609 for context."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//cargo:defs.bzl", "cargo_build_script")
load("//rust:defs.bzl", "rust_library")

def _cbs_data_in_rustc_inputs_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    rustc_action = None
    for action in target.actions:
        if action.mnemonic == "Rustc":
            rustc_action = action
            break

    asserts.false(env, rustc_action == None, "Expected a Rustc action")

    data_inputs = [i for i in rustc_action.inputs.to_list() if "cbs_data_dep.txt" in i.path]
    asserts.equals(
        env,
        ctx.attr.expected_present,
        len(data_inputs) > 0,
    )

    return analysistest.end(env)

cbs_data_in_rustc_inputs_test = analysistest.make(
    _cbs_data_in_rustc_inputs_impl,
    attrs = {
        "expected_present": attr.bool(),
    },
)

def _define_test_targets():
    write_file(
        name = "cbs_data_dep_file",
        out = "cbs_data_dep.txt",
        content = ["data for build script", ""],
        newline = "unix",
    )

    write_file(
        name = "build_rs_src",
        out = "build.rs",
        content = ["fn main() {}", ""],
        newline = "unix",
    )

    cargo_build_script(
        name = "build_script",
        srcs = [":build.rs"],
        data = [":cbs_data_dep.txt"],
        edition = "2021",
    )

    write_file(
        name = "lib_src",
        out = "lib.rs",
        content = ["pub fn hello() {}", ""],
        newline = "unix",
    )

    rust_library(
        name = "lib",
        srcs = [":lib.rs"],
        deps = [":build_script"],
        edition = "2021",
    )

    write_file(
        name = "bin_src",
        out = "bin.rs",
        content = ["extern crate lib;", ""],
        newline = "unix",
    )

    rust_library(
        name = "bin",
        srcs = [":bin.rs"],
        deps = [":lib"],
        edition = "2021",
    )

def transitive_cbs_data_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """
    _define_test_targets()

    cbs_data_in_rustc_inputs_test(
        name = "cbs_data_in_lib_compile_inputs_test",
        expected_present = True,
        target_under_test = ":lib",
    )

    cbs_data_in_rustc_inputs_test(
        name = "cbs_data_in_bin_compile_inputs_test",
        expected_present = False,
        target_under_test = ":bin",
    )

    native.test_suite(
        name = name,
        tests = [
            ":cbs_data_in_lib_compile_inputs_test",
            ":cbs_data_in_bin_compile_inputs_test",
        ],
    )

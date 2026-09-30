"""Unittests for `rust_wasm_bindgen` runfiles propagation."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_rust//rust:defs.bzl", "rust_binary", "rust_shared_library")
load("//:defs.bzl", "rust_wasm_bindgen")

def _is_in_runfiles(name, runfiles):
    for file in runfiles:
        if file.basename == name:
            return True
    return False

def _runfiles_propagated_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    runfiles = tut[DefaultInfo].default_runfiles.files.to_list()

    asserts.true(
        env,
        _is_in_runfiles("runfile_data.txt", runfiles),
        "Expected `runfile_data.txt` in the default runfiles of `{}`. Got: {}".format(
            tut.label,
            [f.short_path for f in runfiles],
        ),
    )

    return analysistest.end(env)

runfiles_propagated_test = analysistest.make(_runfiles_propagated_test_impl)

def runfiles_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    rust_binary(
        name = "runfiles_bin_wasm",
        srcs = ["//test:main.rs"],
        data = ["runfile_data.txt"],
        edition = "2018",
        target_compatible_with = ["@platforms//cpu:wasm32"],
        deps = [
            "@rules_rust_wasm_bindgen//3rdparty:wasm_bindgen",
        ],
    )

    rust_shared_library(
        name = "runfiles_lib_wasm",
        srcs = ["//test:main.rs"],
        data = ["runfile_data.txt"],
        edition = "2018",
        target_compatible_with = ["@platforms//cpu:wasm32"],
        deps = [
            "@rules_rust_wasm_bindgen//3rdparty:wasm_bindgen",
        ],
    )

    rust_wasm_bindgen(
        name = "runfiles_bin_bindgen",
        wasm_file = ":runfiles_bin_wasm",
    )

    rust_wasm_bindgen(
        name = "runfiles_lib_bindgen",
        target = "web",
        wasm_file = ":runfiles_lib_wasm",
    )

    runfiles_propagated_test(
        name = "runfiles_bin_propagation_test",
        target_under_test = ":runfiles_bin_bindgen",
    )

    runfiles_propagated_test(
        name = "runfiles_lib_propagation_test",
        target_under_test = ":runfiles_lib_bindgen",
    )

    native.test_suite(
        name = name,
        tests = [
            ":runfiles_bin_propagation_test",
            ":runfiles_lib_propagation_test",
        ],
    )

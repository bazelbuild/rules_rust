"""Analysis tests for the pyo3_toolchain rule."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc:defs.bzl", "cc_import", "cc_library")
load("@rules_python//python:py_runtime.bzl", "py_runtime")
load("@rules_python//python:py_runtime_pair.bzl", "py_runtime_pair")
load("@rules_python//python/cc:py_cc_toolchain.bzl", "py_cc_toolchain")
load("//:defs.bzl", "pyo3_toolchain")

def _interface_library_only_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    python_libs = target[platform_common.ToolchainInfo].python_libs.to_list()
    asserts.equals(env, ["python3.lib"], [lib.basename for lib in python_libs])
    asserts.equals(
        env,
        python_libs[0].dirname,
        target[platform_common.TemplateVariableInfo].variables["PYO3_CROSS_LIB_DIR"],
    )

    return analysistest.end(env)

interface_library_only_test = analysistest.make(
    _interface_library_only_test_impl,
    config_settings = {
        "//command_line_option:extra_toolchains": [
            str(Label("//test/toolchain:interface_library_only_py_cc_toolchain")),
            str(Label("//test/toolchain:py_toolchain")),
        ],
    },
)

def pyo3_toolchain_test_suite(name):
    """Analysis tests for the pyo3_toolchain rule.

    Args:
        name: the test suite name
    """

    # Windows Python distributions expose only the import library for linking.
    cc_import(
        name = "python_import_library",
        interface_library = "python3.lib",
        system_provided = True,
    )

    cc_library(
        name = "python_headers",
    )

    py_cc_toolchain(
        name = "interface_library_only_py_cc_toolchain_impl",
        headers = ":python_headers",
        libs = ":python_import_library",
        python_version = "3.11",
    )

    native.toolchain(
        name = "interface_library_only_py_cc_toolchain",
        toolchain = ":interface_library_only_py_cc_toolchain_impl",
        toolchain_type = "@rules_python//python/cc:toolchain_type",
    )

    py_runtime(
        name = "py_runtime",
        interpreter_path = "/usr/bin/python3",
        interpreter_version_info = {
            "major": "3",
            "minor": "11",
        },
        python_version = "PY3",
    )

    py_runtime_pair(
        name = "py_runtime_pair",
        py3_runtime = ":py_runtime",
    )

    native.toolchain(
        name = "py_toolchain",
        toolchain = ":py_runtime_pair",
        toolchain_type = "@rules_python//python:toolchain_type",
    )

    pyo3_toolchain(
        name = "interface_library_only_pyo3_toolchain",
        tags = ["manual"],
    )

    interface_library_only_test(
        name = "interface_library_only_test",
        target_under_test = ":interface_library_only_pyo3_toolchain",
    )

    native.test_suite(
        name = name,
        tests = [
            ":interface_library_only_test",
        ],
    )

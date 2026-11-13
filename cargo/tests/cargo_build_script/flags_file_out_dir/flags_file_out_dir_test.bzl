"""Tests for `OUT_DIR` paths emitted through `cargo:rustc-flags` and `cargo:rustc-link-arg`.

These directives are serialized into the build script's `.flags` file rather
than `.linksearchpaths` / `.linkflags`. The consuming `Rustc` action runs in
its own sandbox (and, under `--experimental_output_paths=strip`, with inputs
staged at `bazel-out/cfg/bin/...`), so any `OUT_DIR` path in that file must be
rewritten to a token that `process_wrapper` resolves at execution time.
Analysis cannot observe file contents, so the only meaningful check is that
the consumer actually links.
"""

load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("//cargo:defs.bzl", "cargo_build_script")
load("//rust:defs.bzl", "rust_binary")

def flags_file_out_dir_test_suite(name):
    """Build a binary whose build script references `OUT_DIR` from the `.flags` file.

    Args:
        name: Name of the test suite.
    """
    cargo_build_script(
        name = "flags_file_build_script",
        srcs = ["build.rs"],
        deps = ["//cargo/tests/cargo_build_script/build_script_native_libs"],
        tags = ["manual"],
    )

    rust_binary(
        name = "flags_file_bin",
        srcs = ["main.rs"],
        deps = [":flags_file_build_script"],
        tags = ["manual"],
    )

    build_test(
        name = "flags_file_out_dir_build_test",
        targets = [":flags_file_bin"],
    )

    native.test_suite(
        name = name,
        tests = [":flags_file_out_dir_build_test"],
    )

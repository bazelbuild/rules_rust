"""Tests for build scripts that forward another build script's `OUT_DIR` paths.

A path to a *dependency's* `OUT_DIR`, received through a `DEP_*` variable
and re-emitted as `cargo:rustc-env` or `cargo:rustc-link-search`, is
serialized by `cargo_build_script_runner` as `${pwd}/${out_dir:<root
relative path>}` and resolved in the consuming `Rustc` action from a
`--subst` entry sourced from the dependency's `out_dir` `File`. The
consumer has that directory as an input, so under
`--experimental_output_paths=strip` it is staged at `bazel-out/cfg/bin/...`;
a path serialized as `${pwd}/bazel-out/<config>/bin/...` would not exist
there. Analysis cannot observe file contents, so the real check is that the
consumers compile and link.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("//cargo:defs.bzl", "cargo_build_script")
load("//rust:defs.bzl", "rust_binary", "rust_library")
load("//test/unit:common.bzl", "assert_action_mnemonic")

def _dep_out_dir_subst_test_impl(ctx):
    """Verify the producer's `out_dir` is resolvable through a configuration independent key."""
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    action = tut.actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    key = "out_dir:{}/producer_build_script.out_dir".format(ctx.label.package)
    found = False
    for i in range(len(action.argv) - 1):
        if action.argv[i] != "--subst":
            continue
        subst_key, _, value = action.argv[i + 1].partition("=")
        if subst_key == key:
            found = True
            asserts.true(
                env,
                value.endswith("/producer_build_script.out_dir"),
                "Expected `--subst {}` to resolve to the producer out_dir, got '{}'".format(key, value),
            )
    asserts.true(env, found, "Expected a `--subst {}=...` entry".format(key))

    return analysistest.end(env)

_dep_out_dir_subst_test = analysistest.make(_dep_out_dir_subst_test_impl)

def transitive_out_dir_paths_test_suite(name):
    """Build consumers of a build script that forwards a dependency's `OUT_DIR` paths.

    Args:
        name: Name of the test suite.
    """
    cargo_build_script(
        name = "producer_build_script",
        srcs = ["producer_build.rs"],
        deps = ["//cargo/tests/cargo_build_script/build_script_native_libs"],
        links = "transitive_producer",
        tags = ["manual"],
    )

    rust_library(
        name = "producer_lib",
        srcs = ["producer_lib.rs"],
        deps = [":producer_build_script"],
        tags = ["manual"],
    )

    cargo_build_script(
        name = "consumer_build_script",
        srcs = ["consumer_build.rs"],
        link_deps = [":producer_lib"],
        tags = ["manual"],
    )

    # `include_str!` through the forwarded `rustc-env` path.
    rust_library(
        name = "transitive_out_dir_paths_lib",
        srcs = ["lib.rs"],
        deps = [
            ":consumer_build_script",
            ":producer_lib",
        ],
        tags = ["manual"],
    )

    # `-l static` through the forwarded `rustc-link-search` path.
    rust_binary(
        name = "transitive_out_dir_paths_bin",
        srcs = ["main.rs"],
        deps = [
            ":consumer_build_script",
            ":producer_lib",
            ":transitive_out_dir_paths_lib",
        ],
        tags = ["manual"],
    )

    _dep_out_dir_subst_test(
        name = "dep_out_dir_subst_test",
        target_under_test = ":transitive_out_dir_paths_lib",
    )

    build_test(
        name = "transitive_out_dir_env_build_test",
        targets = [":transitive_out_dir_paths_lib"],
    )

    build_test(
        name = "transitive_out_dir_link_search_build_test",
        targets = [":transitive_out_dir_paths_bin"],
    )

    native.test_suite(
        name = name,
        tests = [
            ":dep_out_dir_subst_test",
            ":transitive_out_dir_env_build_test",
            ":transitive_out_dir_link_search_build_test",
        ],
    )

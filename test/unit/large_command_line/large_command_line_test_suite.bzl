"""Test that large commands produce outputs and that argv is well-formed."""

load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//rust:defs.bzl", "rust_library")

_DEP_COUNT = 100

def _rustc_large_argv_test_impl(env, target):
    rustc_action = [a for a in target.actions if a.mnemonic == "Rustc"][0]

    # Every dependency must appear as an --extern flag.
    extern_args = [a for a in rustc_action.argv if a.startswith("--extern=dep_")]
    env.expect.that_int(len(extern_args)).equals(_DEP_COUNT)

    # Compute the total byte length of the argv.  On Windows the
    # output-path configuration prefix is much longer
    # (x86_64-pc-windows-msvc-fastbuild vs k8-fastbuild), so the real
    # command line is even larger than what we see here.  Asserting a
    # minimum size documents that param-file routing (use_param_file
    # with use_always) is necessary to keep the CreateProcessW /
    # cmd.exe command line within OS limits.
    argv_bytes = 0
    for a in rustc_action.argv:
        argv_bytes += len(a)
    env.expect.that_int(argv_bytes).is_greater_than(8192)

def _define_many_deps_lib(name):
    deps = []

    for i in range(_DEP_COUNT):
        crate_name = "dep_{}".format(i)
        lib_name = "{}_{}".format(name, crate_name)
        util.helper_target(
            rust_library,
            name = lib_name,
            srcs = ["dep.rs"],
            crate_name = crate_name,
            edition = "2021",
            tags = ["no-clippy", "no-unpretty", "no-rustfmt"],
        )
        deps.append(":{}".format(lib_name))

    many_deps_lib = name + "_many_deps_lib"
    util.helper_target(
        rust_library,
        name = many_deps_lib,
        srcs = ["lib.rs"],
        edition = "2021",
        deps = deps,
        tags = ["no-clippy", "no-unpretty", "no-rustfmt"],
    )
    return ":" + many_deps_lib

def _rustc_large_argv_test(name):
    many_deps_lib = _define_many_deps_lib(name)

    # Analysis test: verify all --extern flags are present and that
    # the total argv size is large enough to require param-file routing.
    analysis_test(
        name = name,
        target = many_deps_lib,
        impl = _rustc_large_argv_test_impl,
    )

def _build_test(name):
    many_deps_lib = _define_many_deps_lib(name)

    # Build test: verify the compilation actually succeeds end-to-end.
    build_test(
        name = name,
        targets = [many_deps_lib],
    )

def large_command_line_test_suite(name):
    """Generate a large number of deps and verify the Rustc action.

    Args:
        name: Name of the enclosing test-suite target.
    """
    test_suite(
        name = name,
        tests = [
            _rustc_large_argv_test,
            _build_test,
        ],
    )

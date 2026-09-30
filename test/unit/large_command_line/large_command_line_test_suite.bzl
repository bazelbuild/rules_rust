"""Test that large commands produce outputs and that argv is well-formed."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("//rust:defs.bzl", "rust_library")

_DEP_COUNT = 100

def _rustc_large_argv_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    rustc_action = [a for a in tut.actions if a.mnemonic == "Rustc"][0]

    # Every dependency must appear as an --extern flag.
    extern_args = [a for a in rustc_action.argv if a.startswith("--extern=dep_")]
    asserts.equals(
        env,
        _DEP_COUNT,
        len(extern_args),
        "expected {} --extern=dep_* flags in the Rustc action argv".format(_DEP_COUNT),
    )

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
    asserts.true(
        env,
        argv_bytes > 8192,
        "Expected total argv byte length > 8192 to prove param-file " +
        "routing is needed, but got {} bytes".format(argv_bytes),
    )

    return analysistest.end(env)

_rustc_large_argv_test = analysistest.make(_rustc_large_argv_test_impl)

def large_command_line_test_suite(name):
    """Generate a large number of deps and verify the Rustc action.

    Args:
        name: Name of the enclosing test-suite target.
    """
    deps = []

    for i in range(_DEP_COUNT):
        lib_name = "dep_{}".format(i)
        rust_library(
            name = lib_name,
            srcs = ["dep.rs"],
            crate_name = lib_name,
            edition = "2021",
            tags = ["no-clippy", "no-unpretty", "no-rustfmt"],
        )
        deps.append(":{}".format(lib_name))

    rust_library(
        name = "many_deps_lib",
        srcs = ["lib.rs"],
        edition = "2021",
        deps = deps,
        tags = ["no-clippy", "no-unpretty", "no-rustfmt"],
    )

    # Analysis test: verify all --extern flags are present and that
    # the total argv size is large enough to require param-file routing.
    _rustc_large_argv_test(
        name = "rustc_large_argv_test",
        target_under_test = ":many_deps_lib",
    )

    # Build test: verify the compilation actually succeeds end-to-end.
    build_test(
        name = "build_test",
        targets = [":many_deps_lib"],
    )

    native.test_suite(
        name = name,
        tests = [
            ":rustc_large_argv_test",
            ":build_test",
        ],
    )

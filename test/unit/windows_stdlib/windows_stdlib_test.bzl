"""Analysistests covering Windows-specific stdlib link flags."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust/platform:triple.bzl", "triple")
load("//rust/platform:triple_mappings.bzl", "system_to_stdlib_linkflags")

# buildifier: disable=bzl-visibility
load("//rust/private:repository_utils.bzl", "BUILD_for_rust_toolchain")

def _stdlib_linkflags_windows_test_impl(ctx):
    env = analysistest.begin(ctx)
    analysistest.target_under_test(env)  # Ensure target is configured.

    msvc_flags = system_to_stdlib_linkflags(triple("x86_64-pc-windows-msvc"))
    gnu_flags = system_to_stdlib_linkflags(triple("x86_64-pc-windows-gnu"))
    gnullvm_flags = system_to_stdlib_linkflags(triple("aarch64-pc-windows-gnullvm"))

    asserts.equals(
        env,
        ["advapi32.lib", "ws2_32.lib", "userenv.lib", "Bcrypt.lib"],
        msvc_flags,
    )
    asserts.equals(
        env,
        ["-ladvapi32", "-lws2_32", "-luserenv"],
        gnu_flags,
    )
    asserts.equals(env, gnu_flags, gnullvm_flags)

    return analysistest.end(env)

stdlib_linkflags_windows_test = analysistest.make(_stdlib_linkflags_windows_test_impl)

def _build_for_rust_toolchain_windows_flags_test_impl(ctx):
    env = analysistest.begin(ctx)
    analysistest.target_under_test(env)

    msvc_triple = triple("x86_64-pc-windows-msvc")
    gnu_triple = triple("x86_64-pc-windows-gnu")

    rendered_msvc = BUILD_for_rust_toolchain(
        name = "tc_msvc",
        exec_triple = msvc_triple,
        target_triple = msvc_triple,
        version = "1.75.0",
        allocator_library = None,
        global_allocator_library = None,
        default_edition = "2021",
        include_rustfmt = False,
        include_llvm_tools = False,
        include_linker = False,
        stdlib_linkflags = None,
        extra_rustc_flags = None,
        extra_exec_rustc_flags = None,
        opt_level = None,
        strip_level = None,
    )
    rendered_gnu = BUILD_for_rust_toolchain(
        name = "tc_gnu",
        exec_triple = gnu_triple,
        target_triple = gnu_triple,
        version = "1.75.0",
        allocator_library = None,
        global_allocator_library = None,
        default_edition = "2021",
        include_rustfmt = False,
        include_llvm_tools = False,
        include_linker = False,
        stdlib_linkflags = None,
        extra_rustc_flags = None,
        extra_exec_rustc_flags = None,
        opt_level = None,
        strip_level = None,
    )

    asserts.true(
        env,
        'stdlib_linkflags = ["advapi32.lib", "ws2_32.lib", "userenv.lib", "Bcrypt.lib"],' in rendered_msvc,
        "MSVC toolchain should render .lib stdlib linkflags:\n%s" % rendered_msvc,
    )
    asserts.true(
        env,
        'stdlib_linkflags = ["-ladvapi32", "-lws2_32", "-luserenv"],' in rendered_gnu,
        "GNU toolchain should render -l stdlib linkflags:\n%s" % rendered_gnu,
    )

    return analysistest.end(env)

build_for_rust_toolchain_windows_flags_test = analysistest.make(
    _build_for_rust_toolchain_windows_flags_test_impl,
)

def _define_targets():
    # Target under test is unused beyond satisfying analysistest requirements.
    native.filegroup(
        name = "dummy_target",
        srcs = [],
    )

def windows_stdlib_test_suite(name):
    """Entry-point macro for Windows stdlib linkflag tests.

    Args:
      name: test suite name"""
    _define_targets()

    stdlib_linkflags_windows_test(
        name = "stdlib_linkflags_windows_test",
        target_under_test = ":dummy_target",
    )
    build_for_rust_toolchain_windows_flags_test(
        name = "build_for_rust_toolchain_windows_flags_test",
        target_under_test = ":dummy_target",
    )

    native.test_suite(
        name = name,
        tests = [
            ":build_for_rust_toolchain_windows_flags_test",
            ":stdlib_linkflags_windows_test",
        ],
    )

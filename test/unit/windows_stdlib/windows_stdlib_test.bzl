"""Analysistests covering Windows-specific stdlib link flags."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust/platform:triple.bzl", "triple")
load("//rust/platform:triple_mappings.bzl", "system_to_stdlib_linkflags")

# buildifier: disable=bzl-visibility
load("//rust/private:repository_utils.bzl", "BUILD_for_rust_toolchain")

_MSVC_FLAGS_BEFORE_1_87 = ["ws2_32.lib", "userenv.lib", "advapi32.lib", "bcrypt.lib", "ntdll.lib", "synchronization.lib", "kernel32.lib"]
_MSVC_FLAGS_SINCE_1_87 = ["ws2_32.lib", "userenv.lib", "bcrypt.lib", "ntdll.lib", "synchronization.lib", "kernel32.lib"]
_GNU_FLAGS = ["-lws2_32", "-luserenv", "-lbcrypt", "-lntdll", "-lsynchronization"]

def _rendered(flags):
    """The `stdlib_linkflags` line `BUILD_for_rust_toolchain` renders for `flags`."""
    return "stdlib_linkflags = [{}],".format(", ".join(['"{}"'.format(flag) for flag in flags]))

def _stdlib_linkflags_windows_test_impl(ctx):
    env = analysistest.begin(ctx)
    analysistest.target_under_test(env)  # Ensure target is configured.

    msvc_triple = triple("x86_64-pc-windows-msvc")
    gnu_triple = triple("x86_64-pc-windows-gnu")
    gnullvm_triple = triple("aarch64-pc-windows-gnullvm")

    # Rust 1.87.0 stopped linking `advapi32` into `std` outside of `win7` targets.
    for version in ("1.85.0", "1.86.1"):
        asserts.equals(
            env,
            _MSVC_FLAGS_BEFORE_1_87,
            system_to_stdlib_linkflags(msvc_triple.system, msvc_triple.abi, version = version),
            "msvc flags for {}".format(version),
        )
    for version in ("1.87.0", "1.99.0", "nightly", "beta", None):
        asserts.equals(
            env,
            _MSVC_FLAGS_SINCE_1_87,
            system_to_stdlib_linkflags(msvc_triple.system, msvc_triple.abi, version = version),
            "msvc flags for {}".format(version),
        )

    # The gnu flavors have not changed across releases.
    for version in ("1.85.0", "1.87.0", None):
        gnu_flags = system_to_stdlib_linkflags(gnu_triple.system, gnu_triple.abi, version = version)
        asserts.equals(env, _GNU_FLAGS, gnu_flags, "gnu flags for {}".format(version))
        asserts.equals(
            env,
            gnu_flags,
            system_to_stdlib_linkflags(gnullvm_triple.system, gnullvm_triple.abi, version = version),
            "gnullvm flags for {}".format(version),
        )

    # Callers which do not know the release get the newest flags.
    asserts.equals(
        env,
        _MSVC_FLAGS_SINCE_1_87,
        system_to_stdlib_linkflags(msvc_triple.system, msvc_triple.abi),
    )

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
        version = "1.87.0",
        channel = "stable",
    )
    rendered_msvc_1_85 = BUILD_for_rust_toolchain(
        name = "tc_msvc",
        exec_triple = msvc_triple,
        target_triple = msvc_triple,
        version = "1.85.0",
        channel = "stable",
    )
    rendered_msvc_nightly = BUILD_for_rust_toolchain(
        name = "tc_msvc",
        exec_triple = msvc_triple,
        target_triple = msvc_triple,
        version = "nightly",
        channel = "nightly",
        iso_date = "2026-01-01",
    )
    rendered_gnu = BUILD_for_rust_toolchain(
        name = "tc_gnu",
        exec_triple = gnu_triple,
        target_triple = gnu_triple,
        version = "1.87.0",
        channel = "stable",
    )

    asserts.true(
        env,
        _rendered(_MSVC_FLAGS_SINCE_1_87) in rendered_msvc,
        "MSVC toolchain should render .lib stdlib linkflags:\n%s" % rendered_msvc,
    )
    asserts.true(
        env,
        _rendered(_MSVC_FLAGS_BEFORE_1_87) in rendered_msvc_1_85,
        "MSVC 1.85.0 toolchain should render the stdlib linkflags of its release:\n%s" % rendered_msvc_1_85,
    )
    asserts.true(
        env,
        _rendered(_MSVC_FLAGS_SINCE_1_87) in rendered_msvc_nightly,
        "MSVC nightly toolchain should render the newest stdlib linkflags:\n%s" % rendered_msvc_nightly,
    )
    asserts.true(
        env,
        'staticlib_ext = ".lib",' in rendered_msvc,
        "MSVC toolchain should render a .lib staticlib extension:\n%s" % rendered_msvc,
    )
    asserts.true(
        env,
        _rendered(_GNU_FLAGS) in rendered_gnu,
        "GNU toolchain should render -l stdlib linkflags:\n%s" % rendered_gnu,
    )
    asserts.true(
        env,
        'staticlib_ext = ".a",' in rendered_gnu,
        "GNU toolchain should render a .a staticlib extension:\n%s" % rendered_gnu,
    )

    return analysistest.end(env)

build_for_rust_toolchain_windows_flags_test = analysistest.make(
    _build_for_rust_toolchain_windows_flags_test_impl,
)

def _define_targets():
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

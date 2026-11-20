"""Unit tests covering Windows-specific stdlib link flags."""

load("@rules_testing//lib:analysis_test.bzl", "test_suite")
load("@rules_testing//lib:unit_test.bzl", "unit_test")
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

def _stdlib_linkflags_windows_test_impl(env):
    msvc_triple = triple("x86_64-pc-windows-msvc")
    gnu_triple = triple("x86_64-pc-windows-gnu")
    gnullvm_triple = triple("aarch64-pc-windows-gnullvm")

    # Rust 1.87.0 stopped linking `advapi32` into `std` outside of `win7` targets.
    for version in ("1.85.0", "1.86.1"):
        env.expect.that_collection(
            system_to_stdlib_linkflags(msvc_triple.system, msvc_triple.abi, version = version),
        ).contains_exactly(_MSVC_FLAGS_BEFORE_1_87).in_order()
    for version in ("1.87.0", "1.99.0", "nightly", "beta", None):
        env.expect.that_collection(
            system_to_stdlib_linkflags(msvc_triple.system, msvc_triple.abi, version = version),
        ).contains_exactly(_MSVC_FLAGS_SINCE_1_87).in_order()

    # The gnu flavors have not changed across releases.
    for version in ("1.85.0", "1.87.0", None):
        gnu_flags = system_to_stdlib_linkflags(gnu_triple.system, gnu_triple.abi, version = version)
        env.expect.that_collection(gnu_flags).contains_exactly(_GNU_FLAGS).in_order()
        env.expect.that_collection(
            system_to_stdlib_linkflags(gnullvm_triple.system, gnullvm_triple.abi, version = version),
        ).contains_exactly(gnu_flags).in_order()

    # Callers which do not know the release get the newest flags.
    env.expect.that_collection(
        system_to_stdlib_linkflags(msvc_triple.system, msvc_triple.abi),
    ).contains_exactly(_MSVC_FLAGS_SINCE_1_87).in_order()

def _stdlib_linkflags_windows_test(name):
    unit_test(
        name = name,
        impl = _stdlib_linkflags_windows_test_impl,
    )

def _build_for_rust_toolchain_windows_flags_test_impl(env):
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

    env.expect.that_str(rendered_msvc).contains(_rendered(_MSVC_FLAGS_SINCE_1_87))
    env.expect.that_str(rendered_msvc_1_85).contains(_rendered(_MSVC_FLAGS_BEFORE_1_87))
    env.expect.that_str(rendered_msvc_nightly).contains(_rendered(_MSVC_FLAGS_SINCE_1_87))
    env.expect.that_str(rendered_msvc).contains('staticlib_ext = ".lib",')
    env.expect.that_str(rendered_gnu).contains(_rendered(_GNU_FLAGS))
    env.expect.that_str(rendered_gnu).contains('staticlib_ext = ".a",')

def _build_for_rust_toolchain_windows_flags_test(name):
    unit_test(
        name = name,
        impl = _build_for_rust_toolchain_windows_flags_test_impl,
    )

def windows_stdlib_test_suite(name):
    """Entry-point macro for Windows stdlib linkflag tests.

    Args:
        name: test suite name
    """
    test_suite(
        name = name,
        tests = [
            _build_for_rust_toolchain_windows_flags_test,
            _stdlib_linkflags_windows_test,
        ],
    )

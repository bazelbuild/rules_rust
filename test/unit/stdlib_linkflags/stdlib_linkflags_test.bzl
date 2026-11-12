"""Unit tests for the Rust release history behind `system_to_stdlib_linkflags`."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//rust/platform:triple_mappings.bzl", "system_to_stdlib_linkflags")

_APPLE_WITH_RESOLV = ["-lSystem", "-lresolv"]
_APPLE = ["-lSystem"]

_IOS_1_30 = ["-lSystem", "-lobjc", "-Wl,-framework,Security", "-Wl,-framework,Foundation", "-lresolv"]
_IOS_1_66 = ["-lSystem", "-lobjc", "-Wl,-framework,Security", "-Wl,-framework,Foundation"]
_IOS_1_75 = ["-lSystem", "-lobjc", "-Wl,-framework,Foundation"]
_IOS_1_80 = ["-lSystem"]

_MSVC_1_30 = ["ws2_32.lib", "userenv.lib", "shell32.lib", "advapi32.lib", "kernel32.lib"]
_MSVC_1_33 = ["ws2_32.lib", "userenv.lib", "advapi32.lib", "kernel32.lib"]
_MSVC_1_57 = ["ws2_32.lib", "userenv.lib", "advapi32.lib", "bcrypt.lib", "kernel32.lib"]
_MSVC_1_70 = ["ws2_32.lib", "userenv.lib", "advapi32.lib", "bcrypt.lib", "ntdll.lib", "kernel32.lib"]
_MSVC_1_78 = ["ws2_32.lib", "userenv.lib", "advapi32.lib", "bcrypt.lib", "ntdll.lib", "synchronization.lib", "kernel32.lib"]
_MSVC_1_87 = ["ws2_32.lib", "userenv.lib", "bcrypt.lib", "ntdll.lib", "synchronization.lib", "kernel32.lib"]

_GNU_1_30 = ["-lws2_32", "-luserenv"]
_GNU_1_57 = ["-lws2_32", "-luserenv", "-lbcrypt"]
_GNU_1_70 = ["-lws2_32", "-luserenv", "-lbcrypt", "-lntdll"]
_GNU_1_78 = ["-lws2_32", "-luserenv", "-lbcrypt", "-lntdll", "-lsynchronization"]

# (system, abi, version, expected flags). Each boundary is checked from both sides.
_CASES = [
    # Releases older than the tracked history get the oldest entry.
    ("windows", "msvc", "1.20.0", _MSVC_1_30),
    ("windows", "msvc", "1.30.0", _MSVC_1_30),
    ("windows", "msvc", "1.32.0", _MSVC_1_30),
    ("windows", "msvc", "1.33.0", _MSVC_1_33),
    ("windows", "msvc", "1.56.1", _MSVC_1_33),
    ("windows", "msvc", "1.57.0", _MSVC_1_57),
    ("windows", "msvc", "1.69.0", _MSVC_1_57),
    ("windows", "msvc", "1.70.0", _MSVC_1_70),
    ("windows", "msvc", "1.77.2", _MSVC_1_70),
    ("windows", "msvc", "1.78.0", _MSVC_1_78),
    ("windows", "msvc", "1.86.0", _MSVC_1_78),
    ("windows", "msvc", "1.87.0", _MSVC_1_87),
    ("windows", "msvc", "1.99.0", _MSVC_1_87),
    ("windows", "msvc", "nightly", _MSVC_1_87),
    ("windows", "msvc", "beta", _MSVC_1_87),
    ("windows", "msvc", None, _MSVC_1_87),
    ("windows", "gnu", "1.30.0", _GNU_1_30),
    ("windows", "gnu", "1.56.0", _GNU_1_30),
    ("windows", "gnu", "1.57.0", _GNU_1_57),
    ("windows", "gnu", "1.69.0", _GNU_1_57),
    ("windows", "gnu", "1.70.0", _GNU_1_70),
    ("windows", "gnu", "1.77.0", _GNU_1_70),
    ("windows", "gnu", "1.78.0", _GNU_1_78),
    ("windows", "gnu", None, _GNU_1_78),
    ("windows", "gnullvm", "1.70.0", _GNU_1_70),
    ("windows", "gnullvm", None, _GNU_1_78),
    ("android", None, "1.30.0", ["-ldl", "-llog", "-lgcc"]),
    ("android", None, "1.74.1", ["-ldl", "-llog", "-lgcc"]),
    ("android", None, "1.75.0", ["-ldl", "-llog"]),
    ("android", None, None, ["-ldl", "-llog"]),
    ("darwin", None, "1.65.0", _APPLE_WITH_RESOLV),
    ("darwin", None, "1.66.0", _APPLE),
    ("macos", None, "1.65.0", _APPLE_WITH_RESOLV),
    ("macos", None, "1.66.0", _APPLE),
    ("macos", None, None, _APPLE),
    ("ios", None, "1.30.0", _IOS_1_30),
    ("ios", None, "1.65.0", _IOS_1_30),
    ("ios", None, "1.66.0", _IOS_1_66),
    ("ios", None, "1.74.0", _IOS_1_66),
    ("ios", None, "1.75.0", _IOS_1_75),
    ("ios", None, "1.79.0", _IOS_1_75),
    ("ios", None, "1.80.0", _IOS_1_80),
    ("ios", None, None, _IOS_1_80),
    ("netbsd", None, "1.31.0", ["-lpthread"]),
    ("netbsd", None, "1.32.0", ["-lpthread", "-lrt"]),
    ("netbsd", None, None, ["-lpthread", "-lrt"]),
    # Systems without a history ignore the release.
    ("linux", None, "1.30.0", ["-ldl", "-lpthread"]),
    ("linux", None, "1.99.0", ["-ldl", "-lpthread"]),
    ("linux", None, None, ["-ldl", "-lpthread"]),
    ("freebsd", None, "1.30.0", ["-lexecinfo", "-lpthread"]),
    ("wasip1", None, None, []),
]

def _stdlib_linkflags_history_test_impl(ctx):
    env = unittest.begin(ctx)

    for system, abi, version, expected in _CASES:
        asserts.equals(
            env,
            expected,
            system_to_stdlib_linkflags(system, abi, version = version),
            "stdlib linkflags for system={} abi={} version={}".format(system, abi, version),
        )

    return unittest.end(env)

stdlib_linkflags_history_test = unittest.make(_stdlib_linkflags_history_test_impl)

def stdlib_linkflags_test_suite(name):
    """Entry-point macro for the stdlib linkflags history tests.

    Args:
        name: test suite name
    """
    unittest.suite(
        name,
        stdlib_linkflags_history_test,
    )

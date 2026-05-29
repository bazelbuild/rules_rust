"""Unit tests for the PIE detection helpers in rustc.bzl."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//rust/platform:triple.bzl", "triple")

# buildifier: disable=bzl-visibility
load(
    "//rust/private:rustc.bzl",
    "parse_rustc_version",
    "produces_pie_binaries",
)

# buildifier: disable=bzl-visibility
load("//rust/private:semver.bzl", "semver")

_LATEST = (999, 0, 0)

def _parse_rustc_version_test_impl(ctx):
    env = unittest.begin(ctx)

    # A parsed semver struct collapses to its (major, minor, patch) tuple.
    asserts.equals(env, (1, 94, 1), parse_rustc_version(semver("1.94.1")))
    asserts.equals(env, (1, 0, 0), parse_rustc_version(semver("1.0.0")))
    asserts.equals(env, (10, 20, 30), parse_rustc_version(semver("10.20.30")))

    # Pre-release and build metadata don't affect the tuple — comparisons
    # operate on the (major, minor, patch) prefix only.
    asserts.equals(env, (1, 87, 0), parse_rustc_version(semver("1.87.0-nightly")))
    asserts.equals(env, (1, 87, 0), parse_rustc_version(semver("1.87.0-beta.1")))
    asserts.equals(env, (1, 0, 0), parse_rustc_version(semver("1.0.0+exp.sha")))

    # `None` (what `rust_toolchain.version_semver` is when the toolchain's
    # version is empty or a channel label like "nightly"/"beta") falls back to
    # the "latest" sentinel.
    asserts.equals(env, _LATEST, parse_rustc_version(None))

    return unittest.end(env)

def _produces_pie_binaries_always_test_impl(ctx):
    env = unittest.begin(ctx)
    v = _LATEST

    # Apple platforms are always PIE.
    asserts.equals(env, True, produces_pie_binaries(triple("x86_64-apple-darwin"), v))
    asserts.equals(env, True, produces_pie_binaries(triple("aarch64-apple-darwin"), v))
    asserts.equals(env, True, produces_pie_binaries(triple("aarch64-apple-ios"), v))
    asserts.equals(env, True, produces_pie_binaries(triple("x86_64-apple-tvos"), v))

    # Default linux-gnu falls through to True.
    asserts.equals(env, True, produces_pie_binaries(triple("x86_64-unknown-linux-gnu"), v))
    asserts.equals(env, True, produces_pie_binaries(triple("aarch64-unknown-linux-gnu"), v))

    # OS keywords that disable PIE.
    asserts.equals(env, False, produces_pie_binaries(triple("x86_64-pc-windows-msvc"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("x86_64-unknown-uefi"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("powerpc-wrs-vxworks"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("x86_64-pc-solaris"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("x86_64-unknown-illumos"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("x86_64-pc-cygwin"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("powerpc64-ibm-aix"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("nvptx64-nvidia-cuda"), v))

    # Arch prefixes that disable PIE.
    asserts.equals(env, False, produces_pie_binaries(triple("wasm32-unknown-unknown"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("xtensa-esp32-none-elf"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("msp430-none-elf"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("avr-unknown-gnu-atmega328"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("amdgcn-amd-amdhsa"), v))

    # Env keywords that disable PIE.
    asserts.equals(env, False, produces_pie_binaries(triple("riscv32imc-unknown-nuttx-elf"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("riscv32imc-esp-espidf"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("armv7-unknown-trappist-rtems-eabihf"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("riscv32im-risc0-zkvm-elf"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("mipsel-sony-psp"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("armv7-sony-vita-newlibeabihf"), v))
    asserts.equals(env, False, produces_pie_binaries(triple("armv6k-nintendo-3ds"), v))

    # `solid` substring match.
    asserts.equals(env, False, produces_pie_binaries(triple("aarch64-kmc-solid_asp3"), v))

    return unittest.end(env)

def _produces_pie_binaries_none_targets_test_impl(ctx):
    env = unittest.begin(ctx)

    # bpf is PIE starting at 1.75.0.
    asserts.equals(env, False, produces_pie_binaries(triple("bpfeb-unknown-none"), (1, 74, 0)))
    asserts.equals(env, True, produces_pie_binaries(triple("bpfeb-unknown-none"), (1, 75, 0)))
    asserts.equals(env, True, produces_pie_binaries(triple("bpfel-unknown-none"), (1, 75, 0)))

    # x86_64-unknown-none is always PIE.
    asserts.equals(env, True, produces_pie_binaries(triple("x86_64-unknown-none"), _LATEST))

    # Other bare-metal `none` targets are not PIE.
    asserts.equals(env, False, produces_pie_binaries(triple("aarch64-unknown-none"), _LATEST))
    asserts.equals(env, False, produces_pie_binaries(triple("thumbv7m-none-eabi"), _LATEST))
    asserts.equals(env, False, produces_pie_binaries(triple("riscv32i-unknown-none-elf"), _LATEST))

    return unittest.end(env)

def _produces_pie_binaries_version_thresholds_test_impl(ctx):
    env = unittest.begin(ctx)

    # x86_64-unknown-haiku: PIE starting at 1.29.0.
    asserts.equals(env, False, produces_pie_binaries(triple("x86_64-unknown-haiku"), (1, 28, 0)))
    asserts.equals(env, True, produces_pie_binaries(triple("x86_64-unknown-haiku"), (1, 29, 0)))

    # i686-unknown-haiku is always non-PIE.
    asserts.equals(env, False, produces_pie_binaries(triple("i686-unknown-haiku"), _LATEST))

    # arm-linux-androideabi: PIE starting at 1.1.0.
    asserts.equals(env, False, produces_pie_binaries(triple("arm-linux-androideabi"), (1, 0, 0)))
    asserts.equals(env, True, produces_pie_binaries(triple("arm-linux-androideabi"), (1, 1, 0)))

    # freebsd: PIE starting at 1.8.0.
    asserts.equals(env, False, produces_pie_binaries(triple("x86_64-unknown-freebsd"), (1, 7, 0)))
    asserts.equals(env, True, produces_pie_binaries(triple("x86_64-unknown-freebsd"), (1, 8, 0)))

    # hermit: PIE starting at 1.40.0.
    asserts.equals(env, False, produces_pie_binaries(triple("x86_64-unknown-hermit"), (1, 39, 0)))
    asserts.equals(env, True, produces_pie_binaries(triple("x86_64-unknown-hermit"), (1, 40, 0)))

    # redox: PIE starting at 1.38.0.
    asserts.equals(env, False, produces_pie_binaries(triple("x86_64-unknown-redox"), (1, 37, 0)))
    asserts.equals(env, True, produces_pie_binaries(triple("x86_64-unknown-redox"), (1, 38, 0)))

    # nto (QNX): PIE starting at 1.75.0.
    asserts.equals(env, False, produces_pie_binaries(triple("aarch64-unknown-nto-qnx710"), (1, 74, 0)))
    asserts.equals(env, True, produces_pie_binaries(triple("aarch64-unknown-nto-qnx710"), (1, 75, 0)))

    return unittest.end(env)

def _produces_pie_binaries_musl_test_impl(ctx):
    env = unittest.begin(ctx)

    # Standard musl: PIE starting at 1.21.0.
    asserts.equals(env, False, produces_pie_binaries(triple("x86_64-unknown-linux-musl"), (1, 20, 0)))
    asserts.equals(env, True, produces_pie_binaries(triple("x86_64-unknown-linux-musl"), (1, 21, 0)))
    asserts.equals(env, False, produces_pie_binaries(triple("aarch64-unknown-linux-musl"), (1, 20, 0)))
    asserts.equals(env, True, produces_pie_binaries(triple("aarch64-unknown-linux-musl"), (1, 21, 0)))

    # mips-musl is PIE at any version.
    asserts.equals(env, True, produces_pie_binaries(triple("mips-unknown-linux-musl"), (1, 0, 0)))
    asserts.equals(env, True, produces_pie_binaries(triple("mipsel-unknown-linux-musl"), (1, 0, 0)))

    # unikraft is always non-PIE.
    asserts.equals(env, False, produces_pie_binaries(triple("x86_64-unikraft-linux-musl"), _LATEST))

    return unittest.end(env)

parse_rustc_version_test = unittest.make(_parse_rustc_version_test_impl)
produces_pie_binaries_always_test = unittest.make(_produces_pie_binaries_always_test_impl)
produces_pie_binaries_none_targets_test = unittest.make(_produces_pie_binaries_none_targets_test_impl)
produces_pie_binaries_version_thresholds_test = unittest.make(_produces_pie_binaries_version_thresholds_test_impl)
produces_pie_binaries_musl_test = unittest.make(_produces_pie_binaries_musl_test_impl)

def rustc_pie_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the test suite.
    """
    unittest.suite(
        name,
        parse_rustc_version_test,
        produces_pie_binaries_always_test,
        produces_pie_binaries_none_targets_test,
        produces_pie_binaries_version_thresholds_test,
        produces_pie_binaries_musl_test,
    )

"""Helpers for constructing supported Rust platform triples"""

load("//rust/platform:triple.bzl", "triple")
load("//rust/private:semver.bzl", "semver")

def _support(*, std = False, host_tools = False):
    """Identify the type of support an associated platform triple has.

    The source of truth is:
    https://doc.rust-lang.org/nightly/rustc/platform-support.html

    Args:
        std (bool, optional): Whether or not platform has a standard library artifact.
        host_tools (bool, optional): Whether or not platform has host tools artifacts.

    Returns:
        struct: The parameters above.
    """
    return struct(
        std = std,
        host_tools = host_tools,
    )

# All T1 Platforms should be supported, but aren't, see inline notes.
SUPPORTED_T1_PLATFORM_TRIPLES = {
    "aarch64-apple-darwin": _support(std = True, host_tools = True),
    "aarch64-unknown-linux-gnu": _support(std = True, host_tools = True),
    "aarch64-unknown-nixos-gnu": _support(std = True, host_tools = True),  # Same as `aarch64-unknown-linux-gnu` but with `@platforms//os:nixos`.
    "i686-apple-darwin": _support(std = True, host_tools = True),
    "i686-pc-windows-msvc": _support(std = True, host_tools = True),
    "i686-unknown-linux-gnu": _support(std = True, host_tools = True),
    "x86_64-apple-darwin": _support(std = True, host_tools = True),
    "x86_64-pc-windows-msvc": _support(std = True, host_tools = True),
    "x86_64-unknown-linux-gnu": _support(std = True, host_tools = True),
    "x86_64-unknown-nixos-gnu": _support(std = True, host_tools = True),  # Same as `x86_64-unknown-linux-gnu` but with `@platforms//os:nixos`.
    # N.B. These "alternative" envs are not supported, as bazel cannot distinguish between them
    # and others using existing @platforms// config_values
    #
    #"i686-pc-windows-gnu",
    #"x86_64-pc-windows-gnu",
}

# Some T2 Platforms are supported, provided we have mappings to `@platforms//...` entries.
# See `@rules_rust//rust/platform:triple_mappings.bzl` for the complete list.
SUPPORTED_T2_PLATFORM_TRIPLES = {
    "aarch64-apple-ios": _support(std = True, host_tools = False),
    "aarch64-apple-ios-macabi": _support(std = True, host_tools = False),
    "aarch64-apple-ios-sim": _support(std = True, host_tools = False),
    "aarch64-linux-android": _support(std = True, host_tools = False),
    "aarch64-pc-windows-msvc": _support(std = True, host_tools = True),
    "aarch64-unknown-fuchsia": _support(std = True, host_tools = False),
    "aarch64-unknown-none": _support(std = True, host_tools = False),
    "aarch64-unknown-uefi": _support(std = True, host_tools = False),
    "arm-unknown-linux-gnueabi": _support(std = True, host_tools = True),
    "arm-unknown-linux-musleabi": _support(std = True, host_tools = True),
    "armv7-linux-androideabi": _support(std = True, host_tools = False),
    "armv7-unknown-linux-gnueabi": _support(std = True, host_tools = True),
    "i686-linux-android": _support(std = True, host_tools = False),
    "i686-unknown-freebsd": _support(std = True, host_tools = False),
    "loongarch64-unknown-linux-gnu": _support(std = True, host_tools = True),
    "powerpc-unknown-linux-gnu": _support(std = True, host_tools = True),
    "riscv32imac-unknown-none-elf": _support(std = True, host_tools = False),
    "riscv32imc-unknown-none-elf": _support(std = True, host_tools = False),
    "riscv64gc-unknown-fuchsia": _support(std = True, host_tools = False),
    "riscv64gc-unknown-linux-gnu": _support(std = True, host_tools = True),
    "riscv64gc-unknown-none-elf": _support(std = True, host_tools = False),
    "s390x-unknown-linux-gnu": _support(std = True, host_tools = True),
    "sparc64-unknown-linux-gnu": _support(std = True, host_tools = False),
    "thumbv6m-none-eabi": _support(std = True, host_tools = False),
    "thumbv7em-none-eabi": _support(std = True, host_tools = False),
    "thumbv7em-none-eabihf": _support(std = True, host_tools = False),
    "thumbv7m-none-eabi": _support(std = True, host_tools = False),
    "thumbv8m.main-none-eabi": _support(std = True, host_tools = False),
    "thumbv8m.main-none-eabihf": _support(std = True, host_tools = False),
    "wasm32-unknown-emscripten": _support(std = True, host_tools = False),
    "wasm32-unknown-unknown": _support(std = True, host_tools = False),
    "wasm32-wasip1": _support(std = True, host_tools = False),
    "wasm32-wasip1-threads": _support(std = True, host_tools = False),
    "wasm32-wasip2": _support(std = True, host_tools = False),
    "x86_64-apple-ios": _support(std = True, host_tools = False),
    "x86_64-apple-ios-macabi": _support(std = True, host_tools = False),
    "x86_64-linux-android": _support(std = True, host_tools = False),
    "x86_64-unknown-freebsd": _support(std = True, host_tools = True),
    "x86_64-unknown-fuchsia": _support(std = True, host_tools = False),
    "x86_64-unknown-none": _support(std = True, host_tools = False),
    "x86_64-unknown-uefi": _support(std = True, host_tools = False),
}

_T3_PLATFORM_TRIPLES = {
    "aarch64-unknown-nto-qnx710": _support(std = True, host_tools = False),
    "avr-none": _support(std = False, host_tools = False),
    "bpfeb-unknown-none": _support(std = False, host_tools = False),
    "bpfel-unknown-none": _support(std = False, host_tools = False),
    "mips-unknown-linux-gnu": _support(std = True, host_tools = True),
    "sparc64-unknown-netbsd": _support(std = True, host_tools = True),
    "sparc64-unknown-openbsd": _support(std = True, host_tools = True),
    "thumbv6-none-eabi": _support(std = False, host_tools = False),
    "wasm64-unknown-unknown": _support(std = False, host_tools = False),
}

# The only T3 triples that are supported are ones with at least a stdlib
# artifact. However, it can be useful to know of additional triples so
# this list exists separate from the full list above.
SUPPORTED_T3_PLATFORM_TRIPLES = {
    triple: support
    for triple, support in _T3_PLATFORM_TRIPLES.items()
    if support.std
}

SUPPORTED_PLATFORM_TRIPLES = sorted(
    list(SUPPORTED_T1_PLATFORM_TRIPLES.keys()) +
    list(SUPPORTED_T2_PLATFORM_TRIPLES.keys()) +
    list(SUPPORTED_T3_PLATFORM_TRIPLES.keys()),
)

# Represents all platform triples `rules_rust` is configured to handle in some way.
# Note that with T3 platforms some artifacts may not be available which can lead to
# failures in the analysis phase. This list should be used sparingly.
ALL_PLATFORM_TRIPLES = (
    list(SUPPORTED_T1_PLATFORM_TRIPLES.keys()) +
    list(SUPPORTED_T2_PLATFORM_TRIPLES.keys()) +
    list(_T3_PLATFORM_TRIPLES.keys())
)

# CPUs that map to a `@platforms//cpu` entry
_CPU_ARCH_TO_BUILTIN_PLAT_SUFFIX = {
    "aarch64": "aarch64",
    "arm": "arm",
    "arm64e": "arm64e",
    "armv7": "armv7",
    "armv7s": None,
    "asmjs": None,
    "avr": "avr",
    "bpfeb": "bpfeb",
    "bpfel": "bpfel",
    "hexagon": "hexagon",
    "i386": "i386",
    "i586": None,
    "i686": "x86_32",
    "le32": None,
    "loongarch64": "loongarch64",
    "mips": "mips32",
    "powerpc": "ppc32",
    "powerpc64": "ppc",
    "powerpc64le": "ppc64le",
    "riscv32": "riscv32",
    "riscv32imac": "riscv32",
    "riscv32imc": "riscv32",
    "riscv64": "riscv64",
    "riscv64gc": "riscv64",
    "s390": None,
    "s390x": "s390x",
    "sparc64": "sparc64",
    "thumbv6": "armv6",
    "thumbv6m": "armv6-m",
    "thumbv7em": "armv7e-m",
    "thumbv7m": "armv7-m",
    "thumbv8m.main": "armv8-m",
    "wasm32": "wasm32",
    "wasm64": "wasm64",
    "x86_64": "x86_64",
}

# Systems that map to a "@platforms//os entry
_SYSTEM_TO_BUILTIN_SYS_SUFFIX = {
    "android": "android",
    "bitrig": None,
    "darwin": "osx",
    "dragonfly": None,
    "eabi": "none",
    "eabihf": "none",
    "emscripten": "emscripten",
    "freebsd": "freebsd",
    "fuchsia": "fuchsia",
    "ios": "ios",
    "linux": "linux",
    "macos": "osx",
    "nacl": None,
    "netbsd": "netbsd",
    "nixos": "nixos",
    "none": "none",
    "nto": "qnx",
    "openbsd": "openbsd",
    "solaris": None,
    "uefi": "uefi",
    "unknown": None,
    "wasi": "wasi",
    "wasip1": "wasi",
    "wasip2": "wasi",
    "windows": "windows",
}

_SYSTEM_TO_BINARY_EXT = {
    "android": "",
    "darwin": "",
    "eabi": "",
    "eabihf": "",
    "emscripten": ".js",
    "freebsd": "",
    "fuchsia": "",
    "ios": "",
    "linux": "",
    "macos": "",
    "netbsd": "",
    "nixos": "",
    "none": "",
    "nto": "",
    "threads": ".wasm",
    "uefi": ".efi",
    # This is currently a hack allowing us to have the proper
    # generated extension for the wasm target, similarly to the
    # windows target
    "unknown": ".wasm",
    "wasi": ".wasm",
    "wasip1": ".wasm",
    "wasip2": ".wasm",
    "windows": ".exe",
}

_SYSTEM_TO_STATICLIB_EXT = {
    "android": ".a",
    "darwin": ".a",
    "eabi": ".a",
    "eabihf": ".a",
    "emscripten": ".js",
    "freebsd": ".a",
    "fuchsia": ".a",
    "ios": ".a",
    "linux": ".a",
    "macos": ".a",
    "netbsd": ".a",
    "nixos": ".a",
    "none": ".a",
    "nto": ".a",
    "threads": ".a",
    "uefi": ".lib",
    "unknown": ".a",
    "wasi": ".a",
    "wasip1": ".a",
    "wasip2": ".a",
    "windows": ".lib",
}

_SYSTEM_TO_DYLIB_EXT = {
    "android": ".so",
    "darwin": ".dylib",
    "eabi": ".so",
    "eabihf": ".so",
    "emscripten": ".js",
    "freebsd": ".so",
    "fuchsia": ".so",
    "ios": ".dylib",
    "linux": ".so",
    "macos": ".dylib",
    "netbsd": ".so",
    "nixos": ".so",
    "none": ".so",
    "nto": ".a",
    "threads": ".wasm",
    "uefi": "",  # UEFI doesn't have dynamic linking
    "unknown": ".wasm",
    "wasi": ".wasm",
    "wasip1": ".wasm",
    "wasip2": ".wasm",
    "windows": ".dll",
}

def _since(version, flags):
    """Marks `flags` as the stdlib linkflags of Rust releases starting at `version`."""
    return struct(since = version, flags = flags)

# System libraries the Rust standard library needs, for linkers which do not see
# the `#[link]` directives inside the rlibs (`cc_common.link` and `cc_binary`).
#
# Sources of truth:
# - https://github.com/rust-lang/rust/blob/1.99.0/library/windows_link/src/lib.rs
#   (`library/windows_targets` in releases up to at least 1.90.0): the import libraries `std` links on Windows.
# - https://github.com/rust-lang/rust/blob/1.99.0/src/tools/run-make-support/src/external_deps/c_cxx_compiler/extras.rs:
#   what the Rust test suite links C programs against per platform.
# - https://github.com/rust-lang/libc/blob/0.2.169/src/unix/mod.rs: the per-OS `#[link]` directives on unix.
#
# The libraries a release needs change over time; the history is tracked back to Rust 1.30.0. An
# entry is either a list of flags, which applies to every release, or a list of
# `_since(version, flags)` records in ascending `version` order: the record with the newest
# `version` not newer than the toolchain's release applies, the first record covers releases older
# than any listed and the last record covers `nightly` and `beta` toolchains whose release is not
# known.
#
# Up to 1.46 the directives lived in `src/libstd/build.rs`; by 1.60 they had moved to `#[link]`
# attributes in `library/std/src/sys/{,pal/}unix/mod.rs` and `library/unwind/src/lib.rs`.

_APPLE_STDLIB_LINKFLAGS = [
    _since("1.30.0", ["-lSystem", "-lresolv"]),
    # https://github.com/rust-lang/rust/pull/102766
    _since("1.66.0", ["-lSystem"]),
]

_WINDOWS_GNU_STDLIB_LINKFLAGS = [
    _since("1.30.0", ["-lws2_32", "-luserenv"]),
    # `BCryptGenRandom` replaced `RtlGenRandom`.
    _since("1.57.0", ["-lws2_32", "-luserenv", "-lbcrypt"]),
    # `std` started calling `Nt*` file APIs directly.
    _since("1.70.0", ["-lws2_32", "-luserenv", "-lbcrypt", "-lntdll"]),
    # `WaitOnAddress` based locks.
    _since("1.78.0", ["-lws2_32", "-luserenv", "-lbcrypt", "-lntdll", "-lsynchronization"]),
]

_SYSTEM_TO_STDLIB_LINKFLAGS = {
    # NOTE: Rust stdlib `build.rs` treats android as a subset of linux, rust rules treat android
    # as its own system.
    "android": [
        _since("1.30.0", ["-ldl", "-llog", "-lgcc"]),
        # The unwinder moved from `libgcc` to the `libunwind` the NDK's clang links by itself.
        _since("1.75.0", ["-ldl", "-llog"]),
    ],
    "bitrig": [],
    # TODO(gregbowyer): If rust stdlib is compiled for cloudabi with the backtrace feature it
    # includes `-lunwind` but this might not actually be required.
    # I am not sure which is the common configuration or how we encode it as a link flag.
    "cloudabi": ["-lunwind", "-lc", "-lcompiler_rt"],
    "darwin": _APPLE_STDLIB_LINKFLAGS,
    "dragonfly": ["-lpthread"],
    "eabi": [],
    "eabihf": [],
    "emscripten": [],
    # TODO(bazelbuild/rules_cc#75):
    #
    # Right now bazel cc rules does not specify the exact flag setup needed for calling out system
    # libs, that is we dont know given a toolchain if it should be, for example,
    # `-lxxx` or `/Lxxx` or `xxx.lib` etc.
    #
    # We include the flag setup as they are _commonly seen_ on various platforms with a cc_rules
    # style override for people doing things like gnu-mingw on windows.
    #
    # If you are reading this ... sorry! set the env var `BAZEL_RUST_STDLIB_LINKFLAGS` to
    # what you need for your specific setup, for example like so
    # `BAZEL_RUST_STDLIB_LINKFLAGS="-ladvapi32:-lws2_32:-luserenv"`
    "freebsd": ["-lexecinfo", "-lpthread"],
    "fuchsia": ["-lzircon", "-lfdio"],
    "illumos": ["-lsocket", "-lposix4", "-lpthread", "-lresolv", "-lnsl", "-lumem"],
    "ios": [
        _since("1.30.0", ["-lSystem", "-lobjc", "-Wl,-framework,Security", "-Wl,-framework,Foundation", "-lresolv"]),
        # https://github.com/rust-lang/rust/pull/102766
        _since("1.66.0", ["-lSystem", "-lobjc", "-Wl,-framework,Security", "-Wl,-framework,Foundation"]),
        _since("1.75.0", ["-lSystem", "-lobjc", "-Wl,-framework,Foundation"]),
        _since("1.80.0", ["-lSystem"]),
    ],
    # TODO: This ignores musl. Longer term what does Bazel think about musl?
    "linux": ["-ldl", "-lpthread"],
    "macos": _APPLE_STDLIB_LINKFLAGS,
    "nacl": [],
    "netbsd": [
        _since("1.30.0", ["-lpthread"]),
        _since("1.32.0", ["-lpthread", "-lrt"]),
    ],
    "nixos": ["-ldl", "-lpthread"],  # Same as `linux`.
    "none": [],
    "nto": [],
    "openbsd": ["-lpthread"],
    "solaris": ["-lsocket", "-lposix4", "-lpthread", "-lresolv"],
    "uefi": [],
    "unknown": [],
    "uwp": ["ws2_32.lib"],
    "wasi": [],
    "wasip1": [],
    "wasip2": [],
    "windows": {
        # Mirrors `EXTRACFLAGS` of the Rust test suite, e.g.
        # https://github.com/rust-lang/rust/blob/1.78.0/tests/run-make/tools.mk and since 1.81
        # https://github.com/rust-lang/rust/blob/1.87.0/src/tools/run-make-support/src/external_deps/c_cxx_compiler/extras.rs#L4-L19
        "gnu": _WINDOWS_GNU_STDLIB_LINKFLAGS,
        "gnullvm": _WINDOWS_GNU_STDLIB_LINKFLAGS,
        # `kernel32.lib` is not in `EXTRACFLAGS` because `link.exe` adds it by default; links with
        # `/NODEFAULTLIB` need it spelled out (https://github.com/bazelbuild/rules_rust/issues/4375).
        "msvc": [
            _since("1.30.0", ["ws2_32.lib", "userenv.lib", "shell32.lib", "advapi32.lib", "kernel32.lib"]),
            _since("1.33.0", ["ws2_32.lib", "userenv.lib", "advapi32.lib", "kernel32.lib"]),
            _since("1.57.0", ["ws2_32.lib", "userenv.lib", "advapi32.lib", "bcrypt.lib", "kernel32.lib"]),
            _since("1.70.0", ["ws2_32.lib", "userenv.lib", "advapi32.lib", "bcrypt.lib", "ntdll.lib", "kernel32.lib"]),
            _since("1.78.0", ["ws2_32.lib", "userenv.lib", "advapi32.lib", "bcrypt.lib", "ntdll.lib", "synchronization.lib", "kernel32.lib"]),
            # `std` only links `advapi32` for `*-win7-windows-msvc` targets from here on, see
            # https://github.com/rust-lang/rust/blob/1.87.0/library/windows_targets/src/lib.rs
            _since("1.87.0", ["ws2_32.lib", "userenv.lib", "bcrypt.lib", "ntdll.lib", "synchronization.lib", "kernel32.lib"]),
        ],
    },
}

def cpu_arch_to_constraints(cpu_arch, *, system = None, abi = None):
    """Returns a list of constraint values which represents a triple's CPU.

    Args:
        cpu_arch (str): The architecture to match constraints for
        system (str, optional): The system for the associated ABI value.
        abi (str, optional): The application binary interface required for the target platform

    Returns:
        List: A list of labels to constraint values
    """
    if cpu_arch not in _CPU_ARCH_TO_BUILTIN_PLAT_SUFFIX:
        fail("CPU architecture \"{}\" is not supported by rules_rust".format(cpu_arch))

    plat_suffix = _CPU_ARCH_TO_BUILTIN_PLAT_SUFFIX[cpu_arch]

    # Patch armv7e-m to mf if hardfloat abi is selected
    if plat_suffix == "armv7e-m" and (system == "eabihf" or abi == "eabihf"):
        plat_suffix = "armv7e-mf"

    return ["@platforms//cpu:{}".format(plat_suffix)]

def vendor_to_constraints(_vendor):
    # TODO(acmcarther): Review:
    #
    # My current understanding is that vendors can't have a material impact on
    # constraint sets.
    return []

def system_to_constraints(system):
    if system not in _SYSTEM_TO_BUILTIN_SYS_SUFFIX:
        fail("System \"{}\" is not supported by rules_rust".format(system))

    sys_suffix = _SYSTEM_TO_BUILTIN_SYS_SUFFIX[system]

    return ["@platforms//os:{}".format(sys_suffix)]

def abi_to_constraints(abi, *, arch = None, system = None):
    """Return a list of constraint values which represents a triple's ABI.

    Note that some ABI values require additional info to accurately match a set of constraints.

    Args:
        abi (str): The abi value to match constraints for
        arch (str, optional): The architecture for the associated ABI value.
        system (str, optional): The system for the associated ABI value.

    Returns:
        List: A list of labels to constraint values
    """

    all_abi_constraints = []

    # add constraints for MUSL static compilation and linking
    # to separate the MUSL from the non-MUSL toolchain on x86_64
    # if abi == "musl" and system == "linux" and arch == "x86_64":
    # all_abi_constraints.append("//rust/platform/constraints:musl_on")

    # add constraints for iOS + watchOS simulator and device triples
    if system in ["ios", "watchos"]:
        if arch == "x86_64" or abi == "sim":
            all_abi_constraints.append("@apple_support//constraints:simulator")
        else:
            all_abi_constraints.append("@apple_support//constraints:device")

    # TODO(bazelbuild/platforms#38): Implement when C++ toolchain is more mature and we
    # figure out how they're doing this
    return all_abi_constraints

def triple_to_system(target_triple):
    """Returns a system name for a given platform triple

    **Deprecated**: Use triple() from triple.bzl directly.

    Args:
        target_triple (str): A platform triple. eg: `x86_64-unknown-linux-gnu`

    Returns:
        str: A system name
    """
    if type(target_triple) == "string":
        target_triple = triple(target_triple)
    return target_triple.system

def triple_to_arch(target_triple):
    """Returns a system architecture name for a given platform triple

    **Deprecated**: Use triple() from triple.bzl directly.

    Args:
        target_triple (str): A platform triple. eg: `x86_64-unknown-linux-gnu`

    Returns:
        str: A cpu architecture
    """
    if type(target_triple) == "string":
        target_triple = triple(target_triple)
    return target_triple.arch

def triple_to_abi(target_triple):
    """Returns a system abi name for a given platform triple

    **Deprecated**: Use triple() from triple.bzl directly.

    Args:
        target_triple (str): A platform triple. eg: `x86_64-unknown-linux-gnu`

    Returns:
        str: The triple's abi
    """
    if type(target_triple) == "string":
        target_triple = triple(target_triple)
    return target_triple.abi

def system_to_dylib_ext(system):
    return _SYSTEM_TO_DYLIB_EXT[system]

def system_to_staticlib_ext(system, abi = None):
    if system == "windows" and abi in ("gnu", "gnullvm"):
        return ".a"
    return _SYSTEM_TO_STATICLIB_EXT[system]

def system_to_binary_ext(system):
    return _SYSTEM_TO_BINARY_EXT[system]

def _stdlib_linkflags_for_release(flags, version):
    """Picks the entry of a versioned `_SYSTEM_TO_STDLIB_LINKFLAGS` value matching a Rust release.

    Args:
        flags (list): Either plain flags or `_since` records in ascending version order.
        version (str, optional): The Rust release (e.g. `1.87.0`), `nightly`, `beta` or `None`.

    Returns:
        list: The flags applying to `version`.
    """
    if not flags or type(flags[0]) != "struct":
        return flags

    if version == None or version in ("nightly", "beta"):
        return flags[-1].flags

    release = semver(version)
    release = (release.major, release.minor, release.patch)

    selected = flags[0].flags
    for entry in flags:
        since = semver(entry.since)
        if (since.major, since.minor, since.patch) <= release:
            selected = entry.flags
    return selected

def system_to_stdlib_linkflags(system, abi = None, version = None):
    """Return the stdlib linker flags for the given system (and optional abi).

    Args:
        system (str): The system component of a Rust target triple (e.g. `linux`, `windows`, `darwin`).
        abi (str, optional): The ABI component of the triple, used to select flag variants on systems (like `windows`) whose stdlib flags depend on the ABI.
        version (str, optional): The Rust release of the toolchain (e.g. `1.87.0`). Where the libraries
            `std` needs have changed between releases this selects the matching flags. `None`,
            `nightly` and `beta` select the flags of the newest known release.

    Returns:
        list: A list of linker flag strings to pass to the linker for the given system/abi.
    """
    flags = _SYSTEM_TO_STDLIB_LINKFLAGS[system]
    if type(flags) == "dict":
        abi_flags = flags.get(None, [])
        if abi:
            for prefix, candidate in flags.items():
                if prefix and abi.startswith(prefix):
                    abi_flags = candidate
                    break
        flags = abi_flags
    return _stdlib_linkflags_for_release(flags, version)

def triple_to_constraint_set(target_triple):
    """Returns a set of constraints for a given platform triple

    Args:
        target_triple (str): A platform triple. eg: `x86_64-unknown-linux-gnu`

    Returns:
        list: A list of constraints (each represented by a list of strings)
    """
    if target_triple == "wasm32-wasi":
        return [
            "@platforms//cpu:wasm32",
            "@platforms//os:wasi",
            "@rules_rust//rust/platform:wasi_preview_1",
        ]
    if target_triple == "wasm32-wasip1":
        return [
            "@platforms//cpu:wasm32",
            "@platforms//os:wasi",
            "@rules_rust//rust/platform:wasi_preview_1",
        ]
    if target_triple == "wasm32-wasip2":
        return [
            "@platforms//cpu:wasm32",
            "@platforms//os:wasi",
            "@rules_rust//rust/platform:wasi_preview_2",
        ]
    if target_triple == "wasm32-unknown-unknown":
        return [
            "@platforms//cpu:wasm32",
            "@platforms//os:none",
        ]
    if target_triple == "wasm32-wasip1-threads":
        return [
            "@platforms//cpu:wasm32",
            "@platforms//os:wasi",
            "@rules_rust//rust/platform:wasi_preview_1",
        ]
    if target_triple == "wasm64-unknown-unknown":
        return [
            "@platforms//cpu:wasm64",
            "@platforms//os:none",
        ]
    if target_triple == "aarch64-apple-ios-macabi":
        return [
            "@platforms//cpu:aarch64",
            "@platforms//os:osx",
            "@apple_support//constraints:catalyst",
        ]
    if target_triple == "x86_64-apple-ios-macabi":
        return [
            "@platforms//cpu:x86_64",
            "@platforms//os:osx",
            "@apple_support//constraints:catalyst",
        ]

    triple_struct = triple(target_triple)

    constraint_set = []
    constraint_set += cpu_arch_to_constraints(
        triple_struct.arch,
        system = triple_struct.system,
        abi = triple_struct.abi,
    )
    constraint_set += vendor_to_constraints(triple_struct.vendor)
    constraint_set += system_to_constraints(triple_struct.system)
    constraint_set += abi_to_constraints(
        triple_struct.abi,
        arch = triple_struct.arch,
        system = triple_struct.system,
    )

    return constraint_set

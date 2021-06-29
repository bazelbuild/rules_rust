"""Helpers for constructing supported Rust platform triples"""

# All T1 Platforms should be supported, but aren't, see inline notes.
SUPPORTED_T1_PLATFORM_TRIPLES = [
    "i686-apple-darwin",
    "i686-pc-windows-msvc",
    "i686-unknown-linux-gnu",
    "x86_64-apple-darwin",
    "x86_64-pc-windows-msvc",
    "x86_64-unknown-linux-gnu",
    # N.B. These "alternative" envs are not supported, as bazel cannot distinguish between them
    # and others using existing @platforms// config_values
    #
    #"i686-pc-windows-gnu",
    #"x86_64-pc-windows-gnu",
]

# Some T2 Platforms are supported, provided we have mappings to @platforms// entries.
# See @rules_rust//rust/platform:triple_mappings.bzl for the complete list.
SUPPORTED_T2_PLATFORM_TRIPLES = [
    "aarch64-apple-darwin",
    "aarch64-apple-ios",
    "aarch64-linux-android",
    "aarch64-unknown-linux-gnu",
    "arm-unknown-linux-gnueabi",
    "i686-linux-android",
    "i686-unknown-freebsd",
    "powerpc-unknown-linux-gnu",
    "s390x-unknown-linux-gnu",
    "wasm32-unknown-unknown",
    "wasm32-wasi",
    "x86_64-apple-ios",
    "x86_64-linux-android",
    "x86_64-unknown-freebsd",
]

SUPPORTED_PLATFORM_TRIPLES = SUPPORTED_T1_PLATFORM_TRIPLES + SUPPORTED_T2_PLATFORM_TRIPLES

# CPUs that map to a "@platforms//cpu entry
_CPU_ARCH_TO_BUILTIN_PLAT_SUFFIX = {
    "aarch64": "aarch64",
    "arm": "arm",
    "armv7": "armv7",
    "armv7s": None,
    "asmjs": None,
    "i386": "i386",
    "i586": None,
    "i686": "x86_32",
    "le32": None,
    "mips": None,
    "mipsel": None,
    "powerpc": "ppc",
    "powerpc64": None,
    "powerpc64le": None,
    "s390": None,
    "s390x": "s390x",
    "wasm32": None,
    "x86_64": "x86_64",
}

# Systems that map to a "@platforms//os entry
_SYSTEM_TO_BUILTIN_SYS_SUFFIX = {
    "android": "android",
    "bitrig": None,
    "darwin": "osx",
    "dragonfly": None,
    "emscripten": None,
    "freebsd": "freebsd",
    "ios": "ios",
    "linux": "linux",
    "nacl": None,
    "netbsd": None,
    "openbsd": "openbsd",
    "solaris": None,
    "unknown": None,
    "wasi": None,
    "windows": "windows",
}

_SYSTEM_TO_BINARY_EXT = {
    "android": "",
    "darwin": "",
    "emscripten": ".js",
    "freebsd": "",
    "ios": "",
    "linux": "",
    # This is currently a hack allowing us to have the proper
    # generated extension for the wasm target, similarly to the
    # windows target
    "unknown": ".wasm",
    "wasi": ".wasm",
    "windows": ".exe",
}

_SYSTEM_TO_STATICLIB_EXT = {
    "android": ".a",
    "darwin": ".a",
    "emscripten": ".js",
    "freebsd": ".a",
    "ios": ".a",
    "linux": ".a",
    "unknown": "",
    "wasi": "",
    "windows": ".lib",
}

_SYSTEM_TO_DYLIB_EXT = {
    "android": ".so",
    "darwin": ".dylib",
    "emscripten": ".js",
    "freebsd": ".so",
    "ios": ".dylib",
    "linux": ".so",
    "unknown": ".wasm",
    "wasi": ".wasm",
    "windows": ".dll",
}

# See https://github.com/rust-lang/rust/blob/master/src/libstd/build.rs
_SYSTEM_TO_STDLIB_LINKFLAGS = {
    # NOTE: Rust stdlib `build.rs` treats android as a subset of linux, rust rules treat android
    # as its own system.
    "android": ["-ldl", "-llog", "-lgcc"],
    "bitrig": [],
    # TODO(gregbowyer): If rust stdlib is compiled for cloudabi with the backtrace feature it
    # includes `-lunwind` but this might not actually be required.
    # I am not sure which is the common configuration or how we encode it as a link flag.
    "cloudabi": ["-lunwind", "-lc", "-lcompiler_rt"],
    "darwin": ["-lSystem", "-lresolv"],
    "dragonfly": ["-lpthread"],
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
    "ios": ["-lSystem", "-lobjc", "-framework Security", "-framework Foundation", "-lresolv"],
    # TODO: This ignores musl. Longer term what does Bazel think about musl?
    "linux": ["-ldl", "-lpthread"],
    "nacl": [],
    "netbsd": ["-lpthread", "-lrt"],
    "openbsd": ["-lpthread"],
    "solaris": ["-lsocket", "-lposix4", "-lpthread", "-lresolv"],
    "unknown": [],
    "uwp": ["ws2_32.lib"],
    "wasi": [],
    "windows": ["advapi32.lib", "ws2_32.lib", "userenv.lib"],
}

def cpu_arch_to_constraints(cpu_arch):
    plat_suffix = _CPU_ARCH_TO_BUILTIN_PLAT_SUFFIX[cpu_arch]

    if not plat_suffix:
        fail("CPU architecture \"{}\" is not supported by rules_rust".format(cpu_arch))

    return ["@platforms//cpu:{}".format(plat_suffix)]

def vendor_to_constraints(vendor):
    # TODO(acmcarther): Review:
    #
    # My current understanding is that vendors can't have a material impact on
    # constraint sets.
    return []

def system_to_constraints(system):
    sys_suffix = _SYSTEM_TO_BUILTIN_SYS_SUFFIX[system]

    if not sys_suffix:
        fail("System \"{}\" is not supported by rules_rust".format(sys_suffix))

    return ["@platforms//os:{}".format(sys_suffix)]

def abi_to_constraints(abi):
    # TODO(acmcarther): Implement when C++ toolchain is more mature and we
    # figure out how they're doing this
    return []

def triple_to_system(triple):
    """Returns a system name for a given platform triple

    Args:
        triple (str): A platform triple. eg: `x86_64-unknown-linux-gnu`

    Returns:
        str: A system name
    """
    if triple == "wasm32-wasi":
        return "wasi"

    component_parts = triple.split("-")
    if len(component_parts) < 3:
        fail("Expected target triple to contain at least three sections separated by '-'")

    return component_parts[2]

def triple_to_arch(triple):
    """Returns a system architecture name for a given platform triple

    Args:
        triple (str): A platform triple. eg: `x86_64-unknown-linux-gnu`

    Returns:
        str: A cpu architecture
    """
    if triple == "wasm32-wasi":
        return "wasi"

    component_parts = triple.split("-")
    if len(component_parts) < 3:
        fail("Expected target triple to contain at least three sections separated by '-'")

    return component_parts[0]

def system_to_dylib_ext(system):
    return _SYSTEM_TO_DYLIB_EXT[system]

def system_to_staticlib_ext(system):
    return _SYSTEM_TO_STATICLIB_EXT[system]

def system_to_binary_ext(system):
    return _SYSTEM_TO_BINARY_EXT[system]

def system_to_stdlib_linkflags(system):
    return _SYSTEM_TO_STDLIB_LINKFLAGS[system]

def triple_to_constraint_set(triple):
    """Returns a set of constraints for a given platform triple

    Args:
        triple (str): A platform triple. eg: `x86_64-unknown-linux-gnu`

    Returns:
        list: A list of constraints (each represented by a list of strings)
    """
    if triple == "wasm32-wasi":
        return [
            "@rules_rust//rust/platform/cpu:wasm32",
            "@rules_rust//rust/platform/os:wasi",
        ]
    if triple == "wasm32-unknown-unknown":
        return [
            "@rules_rust//rust/platform/cpu:wasm32",
            "@rules_rust//rust/platform/os:unknown",
        ]

    component_parts = triple.split("-")
    if len(component_parts) < 3:
        fail("Expected target triple to contain at least three sections separated by '-'")

    cpu_arch = component_parts[0]
    vendor = component_parts[1]
    system = component_parts[2]
    abi = None

    if len(component_parts) == 4:
        abi = component_parts[3]

    constraint_set = []
    constraint_set += cpu_arch_to_constraints(cpu_arch)
    constraint_set += vendor_to_constraints(vendor)
    constraint_set += system_to_constraints(system)
    constraint_set += abi_to_constraints(abi)

    return constraint_set

# CPUs that map to a "@bazel_tools//platforms entry
_CPU_ARCH_TO_BUILTIN_PLAT_SUFFIX = {
    "x86_64": "x86_64",
    "powerpc": "ppc",
    "aarch64": "aarch64",
    "arm": "arm",
    "i686": "x86_32",
    "s390x": "s390x",
    "asmjs": None,
    "i386": None,
    "i586": None,
    "powerpc64": None,
    "powerpc64le": None,
    "armv7": None,
    "armv7s": None,
    "s390": None,
    "le32": None,
    "mips": None,
    "mipsel": None,
}

# Systems that map to a "@bazel_tools//platforms entry
_SYSTEM_TO_BUILTIN_SYS_SUFFIX = {
    "freebsd": "freebsd",
    "linux": "linux",
    "darwin": "osx",
    "windows": "windows",
    "ios": "ios",
    "android": "android",
    "emscripten": None,
    "nacl": None,
    "bitrig": None,
    "dragonfly": None,
    "netbsd": None,
    "openbsd": None,
    "solaris": None,
}

_SYSTEM_TO_BINARY_EXT = {
    "freebsd": "",
    "linux": "",
    # TODO(acmcarther): To be verified
    "darwin": "",
    "windows": ".exe",
    "emscripten": ".js",
}

_SYSTEM_TO_STATICLIB_EXT = {
    "freebsd": ".a",
    "linux": ".a",
    "darwin": ".a",
    # TODO(acmcarther): To be verified
    "windows": ".lib",
    "emscripten": ".js",
}

_SYSTEM_TO_DYLIB_EXT = {
    "freebsd": ".so",
    "linux": ".so",
    "darwin": ".dylib",
    # TODO(acmcarther): To be verified
    "windows": ".dll",
    "emscripten": ".js",
}

def cpu_arch_to_constraints(cpu_arch):
    plat_suffix = _CPU_ARCH_TO_BUILTIN_PLAT_SUFFIX[cpu_arch]

    if not plat_suffix:
        fail("CPU architecture \"{}\" is not supported by rules_rust".format(cpu_arch))

    return ["@bazel_tools//platforms:{}".format(plat_suffix)]

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

    return ["@bazel_tools//platforms:{}".format(sys_suffix)]

def abi_to_constraints(abi):
    # TODO(acmcarther): Implement when C++ toolchain is more mature and we
    # figure out how they're doing this
    return []

def triple_to_system(triple):
    component_parts = triple.split("-")
    if len(component_parts) < 3:
        fail("Expected target triple to contain at least three sections separated by '-'")

    return component_parts[2]

def system_to_dylib_ext(system):
    return _SYSTEM_TO_DYLIB_EXT[system]

def system_to_staticlib_ext(system):
    return _SYSTEM_TO_STATICLIB_EXT[system]

def system_to_binary_ext(system):
    return _SYSTEM_TO_BINARY_EXT[system]

def triple_to_constraint_set(triple):
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

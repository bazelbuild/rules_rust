"""Definitions for support config settings and platform definitions"""

load("@bazel_skylib//lib:selects.bzl", "selects")
load(
    ":triple_mappings.bzl",
    "cpu_arch_to_constraints",
    "system_to_constraints",
    "triple_to_constraint_set",
)

# All T1 Platforms should be supported, but aren't, see inline notes.
_SUPPORTED_T1_PLATFORM_TRIPLES = [
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
# See @io_bazel_rules_rust//rust/platform:triple_mappings.bzl for the complete list.
_SUPPORTED_T2_PLATFORM_TRIPLES = [
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

_SUPPORTED_CPU_ARCH = [
    "aarch64",
    "arm",
    "i686",
    "powerpc",
    "s390x",
    "x86_64",
]

_SUPPORTED_SYSTEMS = [
    "android",
    "darwin",
    "freebsd",
    "ios",
    "linux",
    "windows",
]

# buildifier: disable=unnamed-macro
def declare_config_settings():
    """Helper function for declaring `config_setting`s"""
    for cpu_arch in _SUPPORTED_CPU_ARCH:
        native.config_setting(
            name = cpu_arch,
            constraint_values = cpu_arch_to_constraints(cpu_arch),
        )

    for system in _SUPPORTED_SYSTEMS:
        native.config_setting(
            name = system,
            constraint_values = system_to_constraints(system),
        )

    # Add alias for OSX to "darwin" to match what users will be expecting.
    native.alias(
        name = "osx",
        actual = ":darwin",
    )

    all_supported_triples = _SUPPORTED_T1_PLATFORM_TRIPLES + _SUPPORTED_T2_PLATFORM_TRIPLES
    for triple in all_supported_triples:
        native.config_setting(
            name = triple,
            constraint_values = triple_to_constraint_set(triple),
        )

    native.platform(
        name = "wasm",
        constraint_values = [
            "@io_bazel_rules_rust//rust/platform/cpu:wasm32",
            "@io_bazel_rules_rust//rust/platform/os:unknown",
        ],
    )

    native.platform(
        name = "wasi",
        constraint_values = [
            "@io_bazel_rules_rust//rust/platform/cpu:wasm32",
            "@io_bazel_rules_rust//rust/platform/os:wasi",
        ],
    )

    selects.config_setting_group(
        name = "unix",
        match_any = [
            ":android",
            ":darwin",
            ":freebsd",
            ":linux",
        ],
    )

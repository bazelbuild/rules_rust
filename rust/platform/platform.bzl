load(":triple_mappings.bzl", "triple_to_constraint_set")

# All T1 Platforms should be supported
#
# TODO: Review: How to handle stdlib variants? There doesn't appear to be a way to distinguish between them based on the constraint values available in @bazel_tools//platforms
#
# Without a resolution to this issue, we'll need to enable only one of each
_T1_PLATFORM_TRIPLES = [
    "i686-apple-darwin",
    "i686-pc-windows-gnu",
    #"i686-pc-windows-msvc",
    "i686-unknown-linux-gnu",
    "x86_64-apple-darwin",
    "x86_64-pc-windows-gnu",
    #"x86_64-pc-windows-msvc",
    "x86_64-unknown-linux-gnu",
]

# Some T2 Platforms are supported, provided we have mappings to @bazel_tools//platforms entries.
# See @io_bazel_rules_rust//rust/platform:triple_mappings.bzl for the complete list.
_SUPPORTED_T2_PLATFORM_TRIPLES = [
    "aarch64-apple-ios",
    "aarch64-linux-android",
    "aarch64-unknown-linux-gnu",
    "powerpc-unknown-linux-gnu",
    "arm-unknown-linux-gnueabi",
    "s390x-unknown-linux-gnu",
    "i686-linux-android",
    "i686-unknown-freebsd",
    "x86_64-apple-ios",
    "x86_64-linux-android",
    "x86_64-unknown-freebsd",
]

def declare_config_settings():
    all_supported_triples = _T1_PLATFORM_TRIPLES + _SUPPORTED_T2_PLATFORM_TRIPLES

    for triple in all_supported_triples:
        native.config_setting(
            name = triple,
            constraint_values = triple_to_constraint_set(triple),
        )

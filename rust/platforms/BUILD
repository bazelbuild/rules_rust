# See https://forge.rust-lang.org/platform-support.html
# for the full set of triples
#
# The list of supported triples consists of triples that can be unambiguously identified using
# built in --cpu and --platform flags.
SUPPORTED_TRIPLES = [
    "aarch64-unknown-linux-gnu",
    "i686-apple-darwin",
    "i686-pc-windows-msvc",
    "i686-unknown-freebsd",
    "i686-unknown-linux-gnu",
    "powerpc-unknown-linux-gnu",
    "s390x-unknown-linux-gnu",
    "x86_64-apple-darwin",
    "x86_64-pc-windows-msvc",
    "x86_64-unknown-freebsd",
    "x86_64-unknown-linux-gnu",
]

load("@io_bazel_rules_rust//rust:triple_mappings.bzl", "triple_to_constraint_set")

[native.platform(
    name = target_triple,
    constraint_values = triple_to_constraint_set(target_triple),
) for target_triple in SUPPORTED_TRIPLES]

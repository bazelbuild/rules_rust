"""Dependencies for the auditable_injector tool."""

load("//tools/auditable/3rdparty/crates:crates.bzl", "crate_repositories")

def auditable_dependencies():
    """Define dependencies of the `auditable_injector` tool"""
    return crate_repositories()

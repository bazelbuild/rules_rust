"""Define transitive dependencies for `rules_rust` examples

There are some transitive dependencies of the dependencies of the examples' 
dependencies. This file contains the required macros to pull these dependencies
"""

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("@rules_proto//proto:repositories.bzl", "rules_proto_dependencies", "rules_proto_toolchains")

# buildifier: disable=unnamed-macro
def transitive_deps(is_top_level = False):
    """Define transitive dependencies for `rules_rust` examples

    Args:
        is_top_level (bool, optional): Indicates wheather or not this is being called
            from the root WORKSPACE file of `rules_rust`. Defaults to False.
    """

    rules_proto_dependencies()

    rules_proto_toolchains()

    # Needed by the hello_uses_cargo_manifest_dir example.
    if is_top_level:
        maybe(
            native.local_repository,
            name = "rules_rust_example_cargo_manifest_dir",
            path = "examples/cargo_manifest_dir/external_crate",
        )
    else:
        maybe(
            native.local_repository,
            name = "rules_rust_example_cargo_manifest_dir",
            path = "cargo_manifest_dir/external_crate",
        )

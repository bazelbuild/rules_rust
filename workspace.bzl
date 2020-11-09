# buildifier: disable=module-docstring
load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
load("@bazel_skylib//lib:versions.bzl", "versions")

_MINIMUM_SUPPORTED_BAZEL_VERSION = "3.0.0"

def _bazel_version_impl(repository_ctx):
    """The implementation for the `bazel_version` rule

    Args:
        repository_ctx (repository_ctx): The repository rules context object
    """
    bazel_version = versions.get()
    if len(bazel_version) == 0:
        # buildifier: disable=print
        print("You're using development build of Bazel, make sure it's at least version {}".format(
            _MINIMUM_SUPPORTED_BAZEL_VERSION,
        ))
    elif not versions.is_at_least(_MINIMUM_SUPPORTED_BAZEL_VERSION, bazel_version):
        fail("Bazel {} is too old to use with rules_rust, please use at least Bazel {}, preferably newer.".format(
            bazel_version,
            _MINIMUM_SUPPORTED_BAZEL_VERSION,
        ))
    repository_ctx.file("BUILD.bazel", "exports_files(['def.bzl'])")
    repository_ctx.file("def.bzl", "BAZEL_VERSION='" + bazel_version + "'")

bazel_version = repository_rule(
    doc = (
        "A repository rule that generates a new repository which contains a representation of " +
        "the version of Bazel being used."
    ),
    implementation = _bazel_version_impl,
)

def rust_workspace():
    """A helper macro for setting up requirements for `rules_rust` within a given workspace.

    This macro should always loaded and invoked after `rust_repositories` within a WORKSPACE
    file.
    """

    bazel_skylib_workspace()

    # Give this repository a scoped name to avoid conflicting with other
    # projects' similar workarounds when used in the same workspace
    # (issue #268#issuecomment-713920963). TODO(#462): Investigate
    # whether this can be entirely replaced with `native.bazel_version`.
    bazel_version(name = "io_bazel_rules_rust_bazel_version")

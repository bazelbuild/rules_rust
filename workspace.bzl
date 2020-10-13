load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
load("@bazel_skylib//lib:versions.bzl", "versions")

_MINIMUM_SUPPORTED_BAZEL_VERSION = "0.17.1"

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
    elif versions.is_at_most(_MINIMUM_SUPPORTED_BAZEL_VERSION, bazel_version):
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

    bazel_version(name = "bazel_version")

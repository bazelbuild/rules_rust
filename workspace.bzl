load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
load("@bazel_skylib//lib:versions.bzl", "versions")

def _bazel_version_impl(repository_ctx):
    """The implementation for the `bazel_version` rule

    Args:
        repository_ctx (repository_ctx): The repository rules context object
    """
    bazel_version = versions.get()
    if len(bazel_version) == 0:
        # buildifier: disable=print
        print("You're using development build of Bazel, make sure it's at least version 0.17.1")
    elif versions.is_at_most("0.17.0", bazel_version):
        fail("Bazel {} is too old to use with rules_rust, please use at least Bazel 0.17.1, preferably newer.".format(bazel_version))
    repository_ctx.file("BUILD", "exports_files(['def.bzl'])")
    repository_ctx.file("def.bzl", "BAZEL_VERSION='" + bazel_version + "'")

bazel_version = repository_rule(
    doc = (
        "A repository rule that generates a new repository which contains a representation of " +
        "the version of Bazel being used."
    ),
    implementation = _bazel_version_impl,
)

def rust_workspace():
    """A helper macro for setting up requirements for `rules_rust` within a given workspace"""

    bazel_skylib_workspace()

    bazel_version(name = "bazel_version")


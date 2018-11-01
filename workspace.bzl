load("@bazel_skylib//lib:versions.bzl", "versions")

def _store_bazel_version(repository_ctx):
    bazel_version = versions.get()
    if len(bazel_version) == 0:
        print("You're using development build of Bazel, make sure it's at least version 0.17.1")
    elif versions.is_at_most("0.17.0", bazel_version):
        fail("Bazel {} is too old to use with rules_rust, please use at least Bazel 0.17.1, preferably newer.".format(bazel_version))
    repository_ctx.file("BUILD", "exports_files(['def.bzl'])")
    repository_ctx.file("def.bzl", "BAZEL_VERSION='" + bazel_version + "'")

bazel_version = repository_rule(
    implementation = _store_bazel_version,
)

"""`local_crate_mirror` rule implementation."""

load("//crate_universe/private:common_utils.bzl", "execute")
load("//crate_universe/private:generate_utils.bzl", "get_generator")
load("//crate_universe/private:urls.bzl", "CARGO_BAZEL_SHA256S", "CARGO_BAZEL_URLS")
load("//rust/platform:triple.bzl", "get_host_triple")

def _copy_tree(repository_ctx, src):
    """Copies every file below `src` to the same relative path in the repository.

    Symlinks below `src` are followed, so the copy holds their targets.
    """

    # Starlark has neither recursion nor `while`, so walk the tree with a
    # worklist of directories and a generous bound on how many it may hold.
    # The caller watches the whole tree, so the walk registers no watches of
    # its own; a watched directory that is later deleted fails the refetch.
    pending = [(src, "")]
    for _ in range(1000000):
        if not pending:
            return
        directory, prefix = pending.pop()
        for child in directory.readdir(watch = "no"):
            name = prefix + child.basename
            if child.is_dir:
                pending.append((child, name + "/"))
            else:
                # `legacy_utf8 = False` writes the bytes `read` returned
                # unchanged; Bazel 7 defaults to re-encoding them as UTF-8.
                # repository_ctx cannot read a file's mode, so every file is
                # made executable to keep scripts a build script runs working.
                repository_ctx.file(
                    name,
                    repository_ctx.read(child, watch = "no"),
                    executable = True,
                    legacy_utf8 = False,
                )
    fail("Too many directories below {}".format(src))

def _local_crate_mirror_impl(repository_ctx):
    path = repository_ctx.path(repository_ctx.attr.path)

    host_triple = get_host_triple(repository_ctx)

    generator, _generator_sha256 = get_generator(repository_ctx, host_triple.str)

    # Only repository_ctx APIs are used so the mirror also works on Windows
    # hosts, which have no `cp` or `find`. Files are copied rather than
    # symlinked so the mirror is self-contained: the crate may live somewhere
    # a sandboxed action cannot see, such as /tmp under the Linux sandbox.
    # The tree is watched before it is copied so that an edit made during
    # the copy still refetches the mirror.
    repository_ctx.watch_tree(path)
    _copy_tree(repository_ctx, path)

    execute(repository_ctx, [generator, "render", "--options-json", repository_ctx.attr.options_json, "--output-path", repository_ctx.path("BUILD.bazel")])

    repository_ctx.file("WORKSPACE.bazel", "")
    if hasattr(repository_ctx, "repo_metadata"):
        return repository_ctx.repo_metadata(reproducible = True)
    return None

local_crate_mirror = repository_rule(
    doc = """This is a private implementation detail of crate_universe, and should not be relied on in manually written code.

This is effectively a `local_repository` rule implementation, but where the `BUILD.bazel` file is generated using the `cargo-bazel render` command.""",
    implementation = _local_crate_mirror_impl,
    attrs = {
        "generator": attr.string(
            doc = (
                "The absolute label of a generator. Eg. `@cargo_bazel_bootstrap//:cargo-bazel`. " +
                "This is typically used when bootstrapping"
            ),
        ),
        "generator_sha256s": attr.string_dict(
            doc = "Dictionary of `host_triple` -> `sha256` for a `cargo-bazel` binary.",
            default = CARGO_BAZEL_SHA256S,
        ),
        "generator_urls": attr.string_dict(
            doc = (
                "URL template from which to download the `cargo-bazel` binary. `{host_triple}` and will be " +
                "filled in according to the host platform."
            ),
            default = CARGO_BAZEL_URLS,
        ),
        "options_json": attr.string(
            doc = "JSON serialized instance of a crate_universe::context::SingleBuildFileRenderContext",
        ),
        "path": attr.string(
            # TODO: Verify what happens if this is not an absolute path.
            doc = "Absolute path to the crate source directory whose contents will be copied into the mirror repository.",
        ),
        "quiet": attr.bool(
            doc = "If stdout and stderr should not be printed to the terminal.",
            default = True,
        ),
    },
)

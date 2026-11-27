"""The `cargo-bazel` binaries of a release, as repositories.

A release publishes a binary per platform and records their URLs in
`urls.bzl`. Declaring each as a repository, rather than downloading the
host's during extension evaluation, lets `bazel fetch --all` and
`bazel vendor --all` collect every platform's binary with everything else
a module needs, so a repository cache or vendor directory filled on one
machine serves another of any platform without rules_rust-specific steps.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//crate_universe/private:urls.bzl", "CARGO_BAZEL_SHA256S", "CARGO_BAZEL_URLS")

# The platforms a release builds `cargo-bazel` for. `use_repo` in
# `MODULE.bazel` imports a repository per entry, so the list is fixed here
# rather than read from `urls.bzl`, which is empty until a release writes it.
# Keep in step with `TRIPLES` in `.github/workflows/release_prep.sh`.
CARGO_BAZEL_TRIPLES = [
    "aarch64-apple-darwin",
    "aarch64-pc-windows-msvc",
    "aarch64-unknown-linux-gnu",
    "aarch64-unknown-linux-musl",
    "s390x-unknown-linux-gnu",
    "x86_64-apple-darwin",
    "x86_64-pc-windows-gnu",
    "x86_64-pc-windows-msvc",
    "x86_64-unknown-linux-gnu",
    "x86_64-unknown-linux-musl",
]

def cargo_bazel_repository_name(triple):
    """The repository holding the `cargo-bazel` binary of a platform.

    Args:
        triple (str): The platform triple.

    Returns:
        str: The apparent repository name.
    """
    return "cargo_bazel_" + triple

def cargo_bazel_binary_name(triple):
    """The file name of the `cargo-bazel` binary of a platform.

    Args:
        triple (str): The platform triple.

    Returns:
        str: `cargo-bazel`, with `.exe` on Windows.
    """
    return "cargo-bazel.exe" if "windows" in triple else "cargo-bazel"

_BUILD_FILE = """\
exports_files(glob(["cargo-bazel*"]))

filegroup(
    name = "file",
    srcs = glob(["cargo-bazel*"]),
    visibility = ["//visibility:public"],
)
"""

def _cargo_bazel_from_bootstrap_impl(repository_ctx):
    # Resolving through the BUILD file keeps the binary itself out of what
    # Bazel watches; the bootstrap repository rebuilds it when its inputs change.
    bootstrap = repository_ctx.path(Label("@cargo_bazel_bootstrap//:BUILD.bazel")).dirname
    binary = repository_ctx.attr.binary
    repository_ctx.symlink(bootstrap.get_child(binary), "file/" + binary)
    repository_ctx.file("file/BUILD.bazel", _BUILD_FILE)
    repository_ctx.file("BUILD.bazel", "")

_cargo_bazel_from_bootstrap = repository_rule(
    doc = """\
The layout of a release's `cargo-bazel` repository, holding the binary a
source checkout bootstraps instead. A platform other than the host gets the
host's binary, which only matters to `bazel fetch --all` of a checkout.
""",
    implementation = _cargo_bazel_from_bootstrap_impl,
    attrs = {
        "binary": attr.string(
            doc = "The file name of the binary.",
            mandatory = True,
        ),
    },
)

def cargo_bazel_binaries():
    """Declares a repository per platform holding that platform's `cargo-bazel`.

    With a release's `urls.bzl` each is the published binary; without one,
    the bootstrapped binary stands in.

    Returns:
        list[struct(repo=str, is_dev_dep=bool)]: The repositories declared.
    """
    direct_deps = []
    for triple in CARGO_BAZEL_TRIPLES:
        repo = cargo_bazel_repository_name(triple)
        binary = cargo_bazel_binary_name(triple)
        url = CARGO_BAZEL_URLS.get(triple)
        if url:
            maybe(
                http_file,
                name = repo,
                urls = [url],
                sha256 = CARGO_BAZEL_SHA256S.get(triple),
                downloaded_file_path = binary,
                executable = True,
            )
        else:
            maybe(
                _cargo_bazel_from_bootstrap,
                name = repo,
                binary = binary,
            )
        direct_deps.append(struct(repo = repo, is_dev_dep = False))
    return direct_deps

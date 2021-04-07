"""A module defining the all dependencies of the crate_universe repository rule"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//crate_universe/private:defaults.bzl", "DEFAULT_SHA256_CHECKSUMS", "DEFAULT_URL_TEMPLATE")

def crate_universe_bins(url_template = DEFAULT_URL_TEMPLATE, sha256s = DEFAULT_SHA256_CHECKSUMS):
    """Defines repositories for crate universe binaries

    Args:
        url_template (str, optional): A template url for downloading binaries.
            This must contain a `{bin}` key.
        sha256s (dict, optional): A dict of sha256 values where the key is the
            platform triple of the associated binary.
    """

    # If a repository declaration is added or removed from there, the same
    # should occur in `defaults.bzl` and `create_universe.yaml`.
    triples = {
        "aarch64-apple-darwin": "",
        "aarch64-unknown-linux-gnu": "",
        "x86_64-apple-darwin": "",
        "x86_64-pc-windows-gnu": ".exe",
        "x86_64-unknown-linux-gnu": "",
    }

    for (triple, extension) in triples.items():
        maybe(
            http_file,
            name = "rules_rust_crate_universe__{}".format(triple),
            downloaded_file_path = "resolver{}".format(extension),
            executable = True,
            sha256 = sha256s.get(triple),
            urls = [url_template.format(bin = "crate_universe_resolver-{}{}".format(triple, extension))],
        )

def crate_universe_deps():
    """Define all dependencies for the crate_universe repository rule"""
    crate_universe_bins()

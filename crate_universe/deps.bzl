"""A module defining the all dependencies of the crate_universe repository rule"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//crate_universe/private:defaults.bzl", "DEFAULT_SHA256_CHECKSUMS", "DEFAULT_URL_TEMPLATE")

def crate_universe_bins(url_template = None, sha256s = None):
    """Defines repositories for crate universe binaries

    Args:
        url_template (str, optional): A template url for downloading binaries.
            This must contain a `{bin}` key.
        sha256s (dict, optional): A dict of sha256 values where the key is the
            platform triple of the associated binary.
    """

    if not url_template:
        url_template = DEFAULT_URL_TEMPLATE

    if not sha256s:
        sha256s = DEFAULT_SHA256_CHECKSUMS

    # If a repository declaration is added or removed from there, the same
    # should occur in `defaults.bzl` and other relevant files.
    maybe(
        http_file,
        name = "rules_rust_crate_universe__aarch64-apple-darwin",
        downloaded_file_path = "resolver",
        executable = True,
        sha256 = sha256s.get("aarch64-apple-darwin"),
        urls = [url_template.format(bin = "crate_universe_resolver-aarch64-apple-darwin")],
    )

    maybe(
        http_file,
        name = "rules_rust_crate_universe__aarch64-unknown-linux-gnu",
        downloaded_file_path = "resolver",
        executable = True,
        sha256 = sha256s.get("aarch64-unknown-linux-gnu"),
        urls = [url_template.format(bin = "crate_universe_resolver-aarch64-unknown-linux-gnu")],
    )

    maybe(
        http_file,
        name = "rules_rust_crate_universe__x86_64-apple-darwin",
        downloaded_file_path = "resolver",
        executable = True,
        sha256 = sha256s.get("x86_64-apple-darwin"),
        urls = [url_template.format(bin = "crate_universe_resolver-x86_64-apple-darwin")],
    )

    maybe(
        http_file,
        name = "rules_rust_crate_universe__x86_64-pc-windows-gnu",
        downloaded_file_path = "resolver.exe",
        executable = True,
        sha256 = sha256s.get("x86_64-pc-windows-gnu"),
        urls = [url_template.format(bin = "crate_universe_resolver-x86_64-pc-windows-gnu.exe")],
    )

    maybe(
        http_file,
        name = "rules_rust_crate_universe__x86_64-unknown-linux-gnu",
        downloaded_file_path = "resolver",
        executable = True,
        sha256 = sha256s.get("x86_64-unknown-linux-gnu"),
        urls = [url_template.format(bin = "crate_universe_resolver-x86_64-unknown-linux-gnu")],
    )

def crate_universe_deps():
    """Define all dependencies for the crate_universe repository rule"""
    crate_universe_bins()

"""Dependencies for Rust prost rules"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//proto/prost/private/3rdparty/crates:crates.bzl", "crate_repositories")

def rust_prost_dependencies(bzlmod = False):
    """Declares repositories needed for prost.

    Args:
        bzlmod (bool): Whether bzlmod is enabled.

    Returns:
        list[struct(repo=str, is_dev_dep=bool)]: A list of the repositories
        defined by this macro.
    """

    direct_deps = [
        struct(repo = "rules_rust_prost__heck", is_dev_dep = False),
    ]
    if bzlmod:
        # Without bzlmod, this function is normally called by the
        # rust_prost_dependencies function in the private directory.
        # However, the private directory is inaccessible, plus there's no
        # reason to keep two rust_prost_dependencies functions with bzlmod.
        direct_deps.extend(crate_repositories())
    else:
        maybe(
            http_archive,
            name = "rules_proto",
            sha256 = "6fb6767d1bef535310547e03247f7518b03487740c11b6c6adb7952033fe1295",
            strip_prefix = "rules_proto-6.0.2",
            url = "https://github.com/bazelbuild/rules_proto/releases/download/6.0.2/rules_proto-6.0.2.tar.gz",
        )

        maybe(
            http_archive,
            name = "com_google_protobuf",
            sha256 = "52b6160ae9266630adb5e96a9fc645215336371a740e87d411bfb63ea2f268a0",
            strip_prefix = "protobuf-3.18.0",
            urls = ["https://github.com/protocolbuffers/protobuf/releases/download/v3.18.0/protobuf-all-3.18.0.tar.gz"],
        )

    maybe(
        http_archive,
        name = "rules_rust_prost__heck",
        sha256 = "95505c38b4572b2d910cecb0281560f54b440a19336cbbcb27bf6ce6adc6f5a8",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/heck/heck-0.4.1.crate"],
        strip_prefix = "heck-0.4.1",
        build_file = Label("@rules_rust//proto/prost/private/3rdparty/crates:BUILD.heck-0.4.1.bazel"),
    )
    return direct_deps

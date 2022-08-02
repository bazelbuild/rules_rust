"""Dependencies for the `@rules_rust_examples//sys` package"""

load("//sys/basic/3rdparty/crates:defs.bzl", basic_crate_repositories = "crate_repositories")
load("//sys/complex/3rdparty/crates:defs.bzl", complex_crate_repositories = "crate_repositories")
load("//third_party/openssl:openssl_repositories.bzl", "openssl_repositories")

def sys_deps():
    """This macro loads dependencies for the `sys` crate examples

    Commonly `*-sys` crates are built on top of some existing library and
    will have a number of dependencies. The examples here use
    [crate_universe](https://bazelbuild.github.io/rules_rust/crate_universe.html)
    to gather these dependencies and make them avaialble in the workspace.
    """

    # Required by `//sys/complex`
    openssl_repositories()

    basic_crate_repositories()
    complex_crate_repositories()

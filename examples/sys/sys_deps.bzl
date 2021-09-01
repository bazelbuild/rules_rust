# buildifier: disable=module-docstring
load("//sys/basic/raze:crates.bzl", "basic_sys_fetch_remote_crates")
load("//sys/complex:repositories.bzl", "complex_sys_repositories")

def sys_deps():
    """This macro loads dependencies for the `sys` crate examples

    Commonly `*-sys` crates are built on top of some existing library and
    will have a number of dependencies. The examples here use
    [cargo-raze](https://github.com/google/cargo-raze) to gather these
    dependencies and make them avaialble in the workspace.
    """
    basic_sys_fetch_remote_crates()
    complex_sys_repositories()

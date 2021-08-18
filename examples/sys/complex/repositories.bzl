# buildifier: disable=module-docstring
load("//sys/complex/raze:crates.bzl", "complex_sys_fetch_remote_crates")
load("//third_party/openssl:openssl_repositories.bzl", "openssl_repositories")

def complex_sys_repositories():
    """Define repository dependencies for the `complex_sys` example"""

    complex_sys_fetch_remote_crates()

    openssl_repositories()

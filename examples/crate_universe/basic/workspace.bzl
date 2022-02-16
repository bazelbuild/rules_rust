"""A module for loading crate universe dependencies"""

load("@rules_rust//crate_universe:defs.bzl", "crate", "crate_universe")

def deps():
    crate_universe(
        name = "basic_deps",
        packages = [
            crate.spec(
                name = "lazy_static",
                semver = "=1.4",
            ),
            crate.spec(
                name = "value-bag",
                semver = "=1.0.0-alpha.7",
            ),
        ],
        supported_targets = [
            "x86_64-apple-darwin",
            "x86_64-unknown-linux-gnu",
            "x86_64-pc-windows-msvc",
        ],
        resolver = "@rules_rust_crate_universe_bootstrap//:crate_universe_resolver",
    )

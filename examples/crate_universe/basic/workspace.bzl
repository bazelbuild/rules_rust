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
        ],
        supported_targets = [
            "x86_64-apple-darwin",
            "x86_64-unknown-linux-gnu",
        ],
    )

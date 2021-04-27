"""A module for loading crate universe dependencies"""

load("@rules_rust//crate_universe:defs.bzl", "crate", "crate_universe")

def deps():
    crate_universe(
        name = "uses_sys_crate_deps",
        cargo_toml_files = ["//uses_sys_crate:Cargo.toml"],
        packages = [
            crate.spec(
                name = "libc",
                semver = "=0.2.76",
            ),
        ],
        supported_targets = [
            "x86_64-apple-darwin",
            "x86_64-unknown-linux-gnu",
        ],
    )

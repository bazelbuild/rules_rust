"""A module for declaraing a repository for bootstrapping crate_universe"""

load("//cargo:defs.bzl", "cargo_bootstrap_repository")
load("//rust:defs.bzl", "rust_common")

def crate_universe_bootstrap():
    cargo_bootstrap_repository(
        name = "rules_rust_crate_universe_bootstrap",
        cargo_lockfile = Label("//crate_universe:Cargo.lock"),
        cargo_toml = Label("//crate_universe:Cargo.toml"),
        srcs = [Label("//crate_universe:resolver_srcs")],
        version = rust_common.default_version,
        binary = "crate_universe_resolver",
    )

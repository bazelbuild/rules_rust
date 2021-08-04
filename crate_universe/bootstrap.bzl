"""A module for declaraing a repository for bootstrapping crate_universe"""

load("//cargo:defs.bzl", "cargo_bootstrap_repository")
load("//rust:repositories.bzl", "DEFAULT_RUST_VERSION")

def crate_universe_bootstrap():
    cargo_bootstrap_repository(
        name = "rules_rust_crate_universe_bootstrap",
        cargo_lockfile = Label("//crate_universe:Cargo.lock"),
        cargo_toml = Label("//crate_universe:Cargo.toml"),
        srcs = [Label("//crate_universe:resolver_srcs")],
        version = DEFAULT_RUST_VERSION,
        binary = "crate_universe_resolver",
    )

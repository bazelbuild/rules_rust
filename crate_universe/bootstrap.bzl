"""A module for declaraing a repository for bootstrapping crate_universe"""

load("//cargo:defs.bzl", "cargo_bootstrap_repository", "cargo_env")
load("//crate_universe/third_party/openssl:openssl_repositories.bzl", "openssl_repositories")
load("//rust:defs.bzl", "rust_common")

def crate_universe_bootstrap():
    openssl_repositories()

    cargo_bootstrap_repository(
        name = "rules_rust_crate_universe_bootstrap",
        cargo_lockfile = Label("//crate_universe:Cargo.lock"),
        cargo_toml = Label("//crate_universe:Cargo.toml"),
        srcs = [Label("//crate_universe:resolver_srcs")],
        version = rust_common.default_version,
        binary = "crate_universe_resolver",
        env = {
            "*": {
                "OPENSSL_STATIC": "1",
            },
        },
        env_label = {
            "x86_64-pc-windows-gnu": cargo_env({
                "PERL": "@perl_windows//:perl/bin/perl.exe",
            }),
            "x86_64-pc-windows-msvc": cargo_env({
                "PERL": "@perl_windows//:perl/bin/perl.exe",
            }),
        },
    )

"""A module for loading crate universe dependencies"""

load("@rules_rust//crate_universe:defs.bzl", "crate_universe")

def deps():
    crate_universe(
        name = "uses_proc_macro_deps",
        cargo_toml_files = ["//uses_proc_macro:Cargo.toml"],
        resolver = "@rules_rust_crate_universe_bootstrap//:crate_universe_resolver",
    )

load("@rules_rust//cargo:repositories_bin.bzl", "crate_universe_bin_deps")

def crate_universe_deps():
    crate_universe_bin_deps()

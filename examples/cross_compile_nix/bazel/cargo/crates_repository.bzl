""" Crate Universe Packages and Annotations """

load("@rules_rust//crate_universe:defs.bzl", "crate")
load("//bazel/cargo/crates:libc.bzl", libc = "ANNOTATION")
load("//bazel/cargo/crates:proc_macro2.bzl", proc_macro2 = "ANNOTATION")
load("//bazel/cargo/crates:syn.bzl", syn = "ANNOTATION")

PACKAGES = {
    "anyhow": crate.spec(
        version = "1.0.75",
    ),
    "tokio": crate.spec(
        version = "1.34.0",
        features = [
            "full",
        ],
    ),
}

ANNOTATIONS = {
    "libc": [libc],
    "proc-macro2": [proc_macro2],
    "syn": [syn],
}

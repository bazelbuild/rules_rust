"""A module for loading crate universe dependencies"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("@rules_rust//crate_universe:defs.bzl", "crate", "crate_universe")

def deps():
    maybe(
        http_archive,
        name = "openssl",
        build_file = "//has_aliased_deps:BUILD.openssl.bazel",
        sha256 = "23011a5cc78e53d0dc98dfa608c51e72bcd350aa57df74c5d5574ba4ffb62e74",
        strip_prefix = "openssl-OpenSSL_1_1_1d",
        urls = ["https://github.com/openssl/openssl/archive/OpenSSL_1_1_1d.tar.gz"],
    )

    crate_universe(
        name = "has_aliased_deps_deps",
        cargo_toml_files = ["//has_aliased_deps:Cargo.toml"],
        overrides = {
            "openssl-sys": crate.override(
                extra_build_script_env_vars = {
                    "OPENSSL_DIR": "../openssl/openssl",
                },
                extra_bazel_deps = {
                    "cfg(all())": ["@openssl//:openssl"],
                },
                extra_build_script_bazel_data_deps = {
                    "cfg(all())": ["@openssl//:openssl"],
                },
            ),
        },
        supported_targets = [
            "x86_64-apple-darwin",
            "x86_64-unknown-linux-gnu",
        ],
    )

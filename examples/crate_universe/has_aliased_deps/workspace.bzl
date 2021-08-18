"""A module for loading crate universe dependencies"""

load("@examples//third_party/openssl:openssl_repositories.bzl", "openssl_repositories")
load("@rules_rust//crate_universe:defs.bzl", "crate", "crate_universe")

def deps():
    openssl_repositories()

    crate_universe(
        name = "has_aliased_deps_deps",
        cargo_toml_files = ["//has_aliased_deps:Cargo.toml"],
        overrides = {
            "openssl-sys": crate.override(
                extra_build_script_env_vars = {
                    "OPENSSL_DIR": "$(execpath @openssl//:gen_dir)",
                    "OPENSSL_STATIC": "1",
                },
                extra_bazel_deps = {
                    "cfg(all())": ["@openssl//:openssl"],
                },
                extra_build_script_bazel_data_deps = {
                    "cfg(all())": [
                        "@openssl//:openssl",
                        "@openssl//:gen_dir",
                    ],
                },
                extra_bazel_data_deps = {
                    "cfg(all())": [
                        "@openssl//:openssl",
                        "@openssl//:gen_dir",
                    ],
                },
            ),
        },
        supported_targets = [
            "x86_64-apple-darwin",
            "x86_64-unknown-linux-gnu",
            "x86_64-pc-windows-msvc",
        ],
    )

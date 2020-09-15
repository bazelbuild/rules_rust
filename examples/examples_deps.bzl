"""Define dependencies for `rules_rust` examples"""

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
load("@build_bazel_rules_nodejs//:index.bzl", "node_repositories", "npm_install")
load("@examples//hello_sys:workspace.bzl", "remote_deps")
load("@io_bazel_rules_rust//:workspace.bzl", "rust_workspace")
load("@io_bazel_rules_rust//bindgen:repositories.bzl", "rust_bindgen_repositories")
load("@io_bazel_rules_rust//proto:repositories.bzl", "rust_proto_repositories")
load("@io_bazel_rules_rust//rust:repositories.bzl", "rust_repositories", "rust_repository_set")
load("@io_bazel_rules_rust//wasm_bindgen:repositories.bzl", "rust_wasm_bindgen_repositories")
load("@rules_proto//proto:repositories.bzl", "rules_proto_dependencies", "rules_proto_toolchains")

def deps():
    """Define dependencies for `rules_rust` examples"""
    bazel_skylib_workspace()

    rust_repositories()

    rust_repository_set(
        name = "fake_toolchain_for_test_of_sha256",
        edition = "2018",
        exec_triple = "x86_64-unknown-linux-gnu",
        extra_target_triples = [],
        rustfmt_version = "1.4.12",
        sha256s = {
            "rust-1.46.0-x86_64-unknown-linux-gnu": "e3b98bc3440fe92817881933f9564389eccb396f5f431f33d48b979fa2fbdcf5",
            "rustfmt-1.4.12-x86_64-unknown-linux-gnu": "1894e76913303d66bf40885a601462844eec15fca9e76a6d13c390d7000d64b0",
            "rust-std-1.46.0-x86_64-unknown-linux-gnu": "ac04aef80423f612c0079829b504902de27a6997214eb58ab0765d02f7ec1dbc",
        },
        version = "1.46.0",
    )

    rust_proto_repositories()

    node_repositories()

    # Dependencies for the @examples//hello_world_wasm example.
    npm_install(
        name = "npm",
        package_json = "@examples//:package.json",
        package_lock_json = "@examples//:package-lock.json",
    )

    rust_bindgen_repositories()

    rust_wasm_bindgen_repositories()

    rust_workspace()

    remote_deps()

    rules_proto_dependencies()

    rules_proto_toolchains()

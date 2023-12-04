"""Module extension for bootstrapping cargo-bazel."""

load("//crate_universe:deps_bootstrap.bzl", _cargo_bazel_bootstrap_repo_rule = "cargo_bazel_bootstrap")

def _cargo_bazel_bootstrap_impl(_):
    _cargo_bazel_bootstrap_repo_rule(
        rust_toolchain_cargo_template = "@rust_host_tools//:bin/{tool}",
        rust_toolchain_rustc_template = "@rust_host_tools//:bin/{tool}",
    )

cargo_bazel_bootstrap = module_extension(
    implementation = _cargo_bazel_bootstrap_impl,
    doc = """Module extension to generate the cargo_bazel binary.""",
)

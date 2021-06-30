"""A module for declaraing a repository for bootstrapping crate_universe"""

load("//crate_universe/private:util.bzl", "get_cargo_and_rustc", "get_host_triple")
load("//rust:repositories.bzl", "DEFAULT_RUST_VERSION")
load("//rust/platform:triple_mappings.bzl", "system_to_binary_ext", "triple_to_system")

BOOTSTRAP_ENV_VAR = "RULES_RUST_CRATE_UNIVERSE_BOOTSTRAP"

_INSTALL_SCRIPT_CONTENT = """\
#!/bin/bash

set -euo pipefail

cp "${CRATE_RESOLVER_BIN}" "$@"
"""

_BUILD_FILE_CONTENT = """\
package(default_visibility = ["//visibility:public"])

exports_files(["release/crate_universe_resolver{ext}"])

sh_binary(
    name = "install",
    data = [
        ":release/crate_universe_resolver{ext}",
    ],
    env = {{
        "CRATE_RESOLVER_BIN": "$(execpath :release/crate_universe_resolver{ext})",
    }},
    srcs = ["install.sh"],
)
"""

def _crate_universe_resolver_bootstrapping_impl(repository_ctx):
    # no-op if there has been no request for bootstrapping
    if BOOTSTRAP_ENV_VAR not in repository_ctx.os.environ:
        repository_ctx.file("BUILD.bazel")
        return

    host_triple, _ = get_host_triple(repository_ctx)
    tools = get_cargo_and_rustc(repository_ctx, host_triple)
    extension = system_to_binary_ext(triple_to_system(host_triple))

    repository_dir = repository_ctx.path(".")
    resolver_path = repository_ctx.path("release/crate_universe_resolver" + extension)

    args = [
        tools.cargo,
        "build",
        "--release",
        "--locked",
        "--target-dir",
        repository_dir,
        "--manifest-path",
        repository_ctx.path(repository_ctx.attr.cargo_toml),
    ]

    repository_ctx.report_progress("bootstrapping crate_universe_resolver")
    result = repository_ctx.execute(
        args,
        environment = {
            "RUSTC": str(tools.rustc),
        },
        quiet = False,
    )

    if result.return_code != 0:
        fail("exit_code: {}".format(
            result.return_code,
        ))

    repository_ctx.file("install.sh", _INSTALL_SCRIPT_CONTENT)

    repository_ctx.file("BUILD.bazel", _BUILD_FILE_CONTENT.format(
        ext = extension,
    ))

_crate_universe_resolver_bootstrapping = repository_rule(
    doc = "A rule for bootstrapping a crate_universe_resolver binary using [Cargo](https://doc.rust-lang.org/cargo/)",
    implementation = _crate_universe_resolver_bootstrapping_impl,
    attrs = {
        "cargo_lockfile": attr.label(
            doc = "The lockfile of the crate_universe resolver",
            allow_single_file = ["Cargo.lock"],
            default = Label("//crate_universe:Cargo.lock"),
        ),
        "cargo_toml": attr.label(
            doc = "The path of the crate_universe resolver manifest (`Cargo.toml` file)",
            allow_single_file = ["Cargo.toml"],
            default = Label("//crate_universe:Cargo.toml"),
        ),
        "iso_date": attr.string(
            doc = "The iso_date of cargo binary the resolver should use. Note: This can only be set if `version` is `beta` or `nightly`",
        ),
        "rust_toolchain_repository_template": attr.string(
            doc = (
                "The template to use for finding the host `rust_toolchain` repository. `{version}` (eg. '1.53.0'), " +
                "`{triple}` (eg. 'x86_64-unknown-linux-gnu'), `{system}` (eg. 'darwin'), and `{arch}` (eg. 'aarch64') " +
                "will be replaced in the string if present."
            ),
            default = "rust_{system}_{arch}",
        ),
        "srcs": attr.label(
            doc = "Souces to the crate_universe resolver",
            allow_files = True,
            default = Label("//crate_universe:resolver_srcs"),
        ),
        "version": attr.string(
            doc = "The version of cargo the resolver should use",
            default = DEFAULT_RUST_VERSION,
        ),
    },
    environ = [BOOTSTRAP_ENV_VAR],
)

def crate_universe_bootstrap():
    _crate_universe_resolver_bootstrapping(
        name = "rules_rust_crate_universe_bootstrap",
    )

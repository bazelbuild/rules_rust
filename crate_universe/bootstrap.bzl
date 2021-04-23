"""A module for declaraing a repository for bootstrapping crate_universe"""

load("//crate_universe/private:util.bzl", "get_host_info")

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

    resolver_triple, toolchain_repo, extension = get_host_info(repository_ctx)

    cargo_path = repository_ctx.path(Label(toolchain_repo + "//:bin/cargo" + extension))
    rustc_path = repository_ctx.path(Label(toolchain_repo + "//:bin/rustc" + extension))

    repository_dir = repository_ctx.path(".")
    resolver_path = repository_ctx.path("release/crate_universe_resolver" + extension)

    args = [
        cargo_path,
        "build",
        "--release",
        "--locked",
        "--target-dir",
        repository_dir,
        "--manifest-path",
        repository_ctx.path(repository_ctx.attr.manifest),
    ]

    repository_ctx.report_progress("bootstrapping crate_universe_resolver")
    result = repository_ctx.execute(
        args,
        environment = {
            "RUSTC": str(rustc_path),
            "RUST_LOG": "info",
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
    doc = "A rule for bootstrapping a crate_universe_resolver binary",
    implementation = _crate_universe_resolver_bootstrapping_impl,
    attrs = {
        "lockfile": attr.label(
            doc = "The lockfile of the crate_universe resolver",
            allow_single_file = ["Cargo.lock"],
            default = Label("//crate_universe:Cargo.lock"),
        ),
        "manifest": attr.label(
            doc = "The path of the crate_universe resolver manifest (`Cargo.toml` file)",
            allow_single_file = ["Cargo.toml"],
            default = Label("//crate_universe:Cargo.toml"),
        ),
        "srcs": attr.label(
            doc = "Souces to the crate_universe resolver",
            allow_files = True,
            default = Label("//crate_universe:resolver_srcs"),
        ),
    },
    environ = [BOOTSTRAP_ENV_VAR],
)

def crate_universe_bootstrap():
    _crate_universe_resolver_bootstrapping(
        name = "rules_rust_crate_universe_bootstrap",
    )

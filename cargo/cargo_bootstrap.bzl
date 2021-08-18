"""The `cargo_bootstrap` rule is used for bootstrapping cargo binaries in a repository rule."""

load("//cargo/private:cargo_utils.bzl", "get_cargo_and_rustc", "get_host_triple")
load("//rust:repositories.bzl", "DEFAULT_RUST_VERSION")

_CARGO_BUILD_MODES = [
    "release",
    "debug",
]

def cargo_bootstrap(
        repository_ctx,
        cargo_bin,
        rustc_bin,
        binary,
        cargo_manifest,
        quiet = False,
        build_mode = "release",
        target_dir = None):
    """A function for bootstrapping a cargo binary within a repository rule

    Args:
        repository_ctx (repository_ctx): The rule's context object.
        cargo_bin (path): The path to a Cargo binary.
        rustc_bin (path): The path to a Rustc binary.
        binary (str): The binary to build (the `--bin` parameter for Cargo).
        cargo_manifest (path): The path to a Cargo manifest (Cargo.toml file).
        quiet (bool, optional): Whether or not to print output from the Cargo command.
        build_mode (str, optional): The build mode to use
        target_dir (path, optional): The directory in which to produce build outputs
            (Cargo's --target-dir argument).

    Returns:
        path: The path of the built binary within the target directory
    """

    if not target_dir:
        target_dir = repository_ctx.path(".")

    args = [
        cargo_bin,
        "build",
        "--bin",
        binary,
        "--locked",
        "--target-dir",
        target_dir,
        "--manifest-path",
        cargo_manifest,
    ]

    if build_mode not in _CARGO_BUILD_MODES:
        fail("'{}' is not a supported build mode. Use one of {}".format(build_mode, _CARGO_BUILD_MODES))

    if build_mode == "release":
        args.append("--release")

    repository_ctx.report_progress("Cargo Bootstrapping {}".format(binary))
    result = repository_ctx.execute(
        args,
        environment = {
            "RUSTC": str(rustc_bin),
        },
        quiet = quiet,
    )

    if result.return_code != 0:
        fail("exit_code: {}".format(
            result.return_code,
        ))

    extension = ""
    if "win" in repository_ctx.os.name:
        extension = ".exe"

    binary_path = "{}/{}{}".format(
        build_mode,
        binary,
        extension,
    )

    if not repository_ctx.path(binary_path).exists:
        fail("Failed to produce binary at {}".format(binary_path))

    return binary_path

_BUILD_FILE_CONTENT = """\
load("@rules_rust//rust:defs.bzl", "rust_binary")

package(default_visibility = ["//visibility:public"])

exports_files([
    "{binary_name}",
    "{binary}"
])

rust_binary(
    name = "install",
    rustc_env = {{
        "RULES_RUST_CARGO_BOOTSTRAP_BINARY": "$(rootpath {binary})"
    }},
    data = [
        "{binary}",
    ],
    srcs = [
        "@rules_rust//cargo/bootstrap:bootstrap_installer.rs"
    ],
)
"""

def _cargo_bootstrap_repository_impl(repository_ctx):
    if repository_ctx.attr.version in ("beta", "nightly"):
        version_str = "{}-{}".format(repository_ctx.attr.version, repository_ctx.attr.iso_date)
    else:
        version_str = repository_ctx.attr.version

    host_triple = get_host_triple(repository_ctx)
    tools = get_cargo_and_rustc(
        repository_ctx = repository_ctx,
        toolchain_repository_template = repository_ctx.attr.rust_toolchain_repository_template,
        host_triple = host_triple,
        version = version_str,
    )

    binary_name = repository_ctx.attr.binary or repository_ctx.name

    built_binary = cargo_bootstrap(
        repository_ctx,
        cargo_bin = tools.cargo,
        rustc_bin = tools.rustc,
        binary = binary_name,
        cargo_manifest = repository_ctx.path(repository_ctx.attr.cargo_toml),
        build_mode = repository_ctx.attr.build_mode,
    )

    # Create a symlink so that the binary can be accesed via it's target name
    repository_ctx.symlink(built_binary, binary_name)

    repository_ctx.file("BUILD.bazel", _BUILD_FILE_CONTENT.format(
        binary_name = binary_name,
        binary = built_binary,
    ))

cargo_bootstrap_repository = repository_rule(
    doc = "A rule for bootstrapping a Rust binary using [Cargo](https://doc.rust-lang.org/cargo/)",
    implementation = _cargo_bootstrap_repository_impl,
    attrs = {
        "binary": attr.string(
            doc = "The binary to build (the `--bin` parameter for Cargo). If left empty, the repository name will be used.",
        ),
        "build_mode": attr.string(
            doc = "The build mode the binary should be built with",
            values = [
                "debug",
                "release",
            ],
            default = "release",
        ),
        "cargo_lockfile": attr.label(
            doc = "The lockfile of the crate_universe resolver",
            allow_single_file = ["Cargo.lock"],
            mandatory = True,
        ),
        "cargo_toml": attr.label(
            doc = "The path of the crate_universe resolver manifest (`Cargo.toml` file)",
            allow_single_file = ["Cargo.toml"],
            mandatory = True,
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
        "srcs": attr.label_list(
            doc = "Souces to crate to build.",
            allow_files = True,
            mandatory = True,
        ),
        "version": attr.string(
            doc = "The version of cargo the resolver should use",
            default = DEFAULT_RUST_VERSION,
        ),
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
    },
)

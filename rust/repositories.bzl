"""`rules_rust` uses a collection of repository rules to generate hermtic
toolchains for execution and target environments. A large set of commonly
used toolchains are defined simply by calling `rust_repositories` in your
WORKSPACE file but toolchains can be defined more granularly by using
`rust_repository_set` or any of the other underlying `rust_*_repository`
repository rules with `rust_toolchain_repository`.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load(
    "//rust/platform:triple_mappings.bzl",
    "SUPPORTED_PLATFORM_TRIPLES",
    "system_to_binary_ext",
    "system_to_dylib_ext",
    "system_to_staticlib_ext",
    "system_to_stdlib_linkflags",
    "triple_to_constraint_set",
    "triple_to_system",
)
load(
    "//rust/private:repository_utils.bzl",
    "BUILD_for_rust_cargo_toolchain",
    "BUILD_for_rust_clippy_toolchain",
    "BUILD_for_rust_rustfmt_toolchain",
    "BUILD_for_rust_toolchain",
    "DEFAULT_STATIC_RUST_URL_TEMPLATES",
    "check_version_valid",
    "load_cargo",
    "load_clippy",
    "load_llvm_tools",
    "load_rust_compiler",
    "load_rust_src",
    "load_rust_stdlib",
    "load_rustc_dev_nightly",
    "load_rustfmt",
    "write_build_and_workspace",
    _load_arbitrary_tool = "load_arbitrary_tool",
)
load("//rust/private:utils.bzl", "dedent")

# Reexport to satisfy previsouly public API
load_arbitrary_tool = _load_arbitrary_tool

# Note: Code in `.github/workflows/crate_universe.yaml` looks for this line,
# if you remove it or change its format, you will also need to update that code.
DEFAULT_RUST_VERSION = "1.53.0"
DEFAULT_TOOLCHAIN_TRIPLES = [
    "aarch64-apple-darwin",
    "aarch64-unknown-linux-gnu",
    "x86_64-apple-darwin",
    "x86_64-pc-windows-msvc",
    "x86_64-unknown-freebsd",
    "x86_64-unknown-linux-gnu",
]
DEFAULT_RUST_EDITION = "2015"

def _rust_toolchain_repository_impl(repository_ctx):
    iso_date = "\"{}\"".format(repository_ctx.attr.iso_date) if repository_ctx.attr.iso_date else None

    # Define exec variables
    rustc_repository = repository_ctx.attr.rustc_repository
    exec_triple = repository_ctx.attr.exec_triple
    include_rustc_srcs_env = repository_ctx.os.environ.get("RULES_RUST_TOOLCHAIN_INCLUDE_RUSTC_SRCS")
    if include_rustc_srcs_env != None:
        include_rustc_srcs = include_rustc_srcs_env.lower() in ["true", "1"]
    else:
        include_rustc_srcs = repository_ctx.attr.include_rustc_srcs
    rustc_srcs = "\"{}\"".format(repository_ctx.attr.rustc_srcs) if include_rustc_srcs else None

    # Define target variables
    target_triple = repository_ctx.attr.target_triple
    target_system = triple_to_system(target_triple)
    stdlib_repository = repository_ctx.attr.stdlib_repository
    allocator_library = "\"{}\"".format(repository_ctx.attr.allocator_library) if repository_ctx.attr.allocator_library else None

    stdlib_linkflags = None
    if "BAZEL_RUST_STDLIB_LINKFLAGS" in repository_ctx.os.environ:
        stdlib_linkflags = repository_ctx.os.environ["BAZEL_RUST_STDLIB_LINKFLAGS"].split(":")
    if stdlib_linkflags == None:
        stdlib_linkflags = repository_ctx.attr.stdlib_linkflags

    build_file_contents = [
        BUILD_for_rust_toolchain(
            name = repository_ctx.name,
            allocator_library = allocator_library,
            binary_ext = system_to_binary_ext(target_system),
            default_edition = repository_ctx.attr.edition,
            dylib_ext = system_to_dylib_ext(target_system),
            exec_constraints = repository_ctx.attr.exec_compatible_with,
            exec_triple = repository_ctx.attr.exec_triple,
            iso_date = iso_date,
            os = target_system,
            rust_stdlib = "@{}//:rust_std".format(stdlib_repository),
            rustc = "@{}//:rustc".format(rustc_repository),
            rustc_lib = "@{}//:rustc_lib".format(rustc_repository),
            rustc_srcs = rustc_srcs,
            rustdoc = "@{}//:rustdoc".format(rustc_repository),
            staticlib_ext = system_to_staticlib_ext(target_system),
            stdlib_linkflags = stdlib_linkflags,
            target_constraints = repository_ctx.attr.target_compatible_with,
            target_triple = target_triple,
            version = repository_ctx.attr.version,
        ),
    ]

    if repository_ctx.attr.cargo:
        build_file_contents.append(BUILD_for_rust_cargo_toolchain(
            cargo = repository_ctx.attr.cargo,
            exec_constraints = repository_ctx.attr.exec_compatible_with,
            target_constraints = repository_ctx.attr.target_compatible_with,
        ))

    if repository_ctx.attr.clippy:
        build_file_contents.append(BUILD_for_rust_clippy_toolchain(
            clippy = repository_ctx.attr.clippy,
            exec_constraints = repository_ctx.attr.exec_compatible_with,
            target_constraints = repository_ctx.attr.target_compatible_with,
        ))

    if repository_ctx.attr.rustfmt:
        build_file_contents.append(BUILD_for_rust_rustfmt_toolchain(
            rustfmt = repository_ctx.attr.rustfmt,
            exec_constraints = repository_ctx.attr.exec_compatible_with,
            target_constraints = repository_ctx.attr.target_compatible_with,
        ))

    write_build_and_workspace(repository_ctx, "\n".join(build_file_contents))

rust_toolchain_repository = repository_rule(
    doc = dedent("""\
    A repository rule for wiring together all tools and components required by a host/exec platform for compilation.

    This rule can be used to represent any rustc platform with "host" tools. It creates a `rust_exec_toolchain` using
    generated labels for it's dependencies to allow the toolchain to be registered without requiring that the components
    are first downloaded. For more details on rustc platforms and host tools, see
    [The rustc book](https://doc.rust-lang.org/stable/rustc/platform-support.html).
    """),
    attrs = {
        "allocator_library": attr.label(
            doc = "Target that provides allocator functions when rust_library targets are embedded in a `cc_binary`.",
        ),
        "cargo": attr.string(
            doc = "The label of a Cargo binary from `rust_cargo_repository`",
        ),
        "clippy": attr.string(
            doc = "The label of a Clippy binary from `rust_clippy_repository`",
        ),
        "edition": attr.string(
            doc = "The rust edition to be used by default.",
            default = DEFAULT_RUST_EDITION,
        ),
        "exec_compatible_with": attr.string_list(
            doc = "A list of constraint_values that must be present in the execution platform for this target.",
        ),
        "exec_triple": attr.string(
            doc = "The platform triple of the execution environment.",
            mandatory = True,
        ),
        "include_rustc_srcs": attr.bool(
            doc = (
                "Whether to download and unpack the rustc source files. These are very large, and " +
                "slow to unpack, but are required to support rust analyzer. An environment variable " +
                "`RULES_RUST_TOOLCHAIN_INCLUDE_RUSTC_SRCS` can also be used to control this attribute. " +
                "This variable will take precedence over the hard coded attribute. Setting it to `true` " +
                "to activates this attribute where all other values deactivate it."
            ),
            default = False,
        ),
        "iso_date": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
        ),
        "rustc_repository": attr.string(
            doc = "The repository name of `rust_rustc_repository`.",
            mandatory = True,
        ),
        "rustc_srcs": attr.string(
            doc = "The label of a `rustc_srcs` filegroup target from `rust_rustc_srcs_repository`.",
        ),
        "rustfmt": attr.string(
            doc = "The label of a Rustfmt binary from `rust_rustfmt_repository`",
        ),
        "stdlib_linkflags": attr.string_list(
            doc = "Additional linker libs used when rust-std lib is linked.",
        ),
        "stdlib_repository": attr.string(
            doc = "The repository name for a `rust_stdlib_repository`.",
            mandatory = True,
        ),
        "target_compatible_with": attr.string_list(
            doc = (
                "A list of constraint_values that must be present in the target platform for this target to " +
                "be considered compatible."
            ),
        ),
        "target_triple": attr.string(
            doc = "The platform triple of the target environment.",
            mandatory = True,
        ),
        "version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
            mandatory = True,
        ),
    },
    implementation = _rust_toolchain_repository_impl,
    environ = ["RULES_RUST_TOOLCHAIN_INCLUDE_RUSTC_SRCS"],
)

def _rust_rustc_repository_impl(repository_ctx):
    """The implementation of the rust toolchain repository rule."""

    check_version_valid(repository_ctx.attr.version, repository_ctx.attr.iso_date)

    build_components = [load_rust_compiler(repository_ctx)]

    # Rust 1.45.0 and nightly builds after 2020-05-22 need the llvm-tools gzip to get the libLLVM dylib
    if repository_ctx.attr.version >= "1.45.0" or \
       (repository_ctx.attr.version == "nightly" and repository_ctx.attr.iso_date > "2020-05-22"):
        load_llvm_tools(repository_ctx, repository_ctx.attr.triple)

    if repository_ctx.attr.dev_components:
        load_rustc_dev_nightly(repository_ctx, repository_ctx.attr.triple)

    write_build_and_workspace(repository_ctx, "\n".join(build_components))

rust_rustc_repository = repository_rule(
    doc = "must be a host toolchain",
    attrs = {
        "dev_components": attr.bool(
            doc = "Whether to download the rustc-dev components (defaults to False). Requires version to be \"nightly\".",
            default = False,
        ),
        "iso_date": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
        ),
        "sha256s": attr.string_dict(
            doc = "A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.",
        ),
        "triple": attr.string(
            doc = "The Rust-style target that this compiler runs on",
            mandatory = True,
        ),
        "urls": attr.string_list(
            doc = (
                "A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used " +
                "to substitute the tool being fetched (using .format)."
            ),
            default = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        ),
        "version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
            mandatory = True,
        ),
    },
    implementation = _rust_rustc_repository_impl,
)

def _rust_stdlib_repository_impl(repository_ctx):
    """The implementation of the rust-std target toolchain repository rule."""

    check_version_valid(repository_ctx.attr.version, repository_ctx.attr.iso_date)

    write_build_and_workspace(repository_ctx, load_rust_stdlib(repository_ctx, repository_ctx.attr.triple))

rust_stdlib_repository = repository_rule(
    doc = "A repository rule for fetching the `rust-std` ([Rust Standard Library](https://doc.rust-lang.org/std/)) artifact for the requested platform.",
    attrs = {
        "iso_date": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
        ),
        "sha256s": attr.string_dict(
            doc = "A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.",
        ),
        "triple": attr.string(
            doc = "The Rust-style target that this compiler runs on",
            mandatory = True,
        ),
        "urls": attr.string_list(
            doc = (
                "A list of mirror urls containing the tools from the Rust-lang static file server. " +
                "These must contain the '{}' used to substitute the tool being fetched (using .format)."
            ),
            default = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        ),
        "version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
            mandatory = True,
        ),
    },
    implementation = _rust_stdlib_repository_impl,
)

def _rust_srcs_repository_impl(repository_ctx):
    """The `rust_srcs_repository` repository rule implementation"""

    write_build_and_workspace(repository_ctx, load_rust_src(repository_ctx))

rust_srcs_repository = repository_rule(
    doc = (
        "A repository rule for fetching rustc sources. These are typically useful for things " +
        "[rust-analyzer](https://rust-analyzer.github.io/)."
    ),
    implementation = _rust_srcs_repository_impl,
    attrs = {
        "iso_date": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
        ),
        "sha256": attr.string(
            doc = "The sha256 of the rustc-src artifact.",
        ),
        "urls": attr.string_list(
            doc = (
                "A list of mirror urls containing the tools from the Rust-lang static file server. " +
                "These must contain the '{}' used to substitute the tool being fetched (using .format)."
            ),
            default = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        ),
        "version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
            mandatory = True,
        ),
    },
)

def _rust_rustfmt_repository_impl(repository_ctx):
    """The `rust_rustfmt_repository` repository rule implementation"""

    write_build_and_workspace(repository_ctx, load_rustfmt(repository_ctx))

rust_rustfmt_repository = repository_rule(
    doc = (
        "A repository rule for downloading a [Rustfmt](https://github.com/rust-lang/rustfmt#readme) artifact for " +
        "use in a `rust_rustfmt_toolchain`."
    ),
    implementation = _rust_rustfmt_repository_impl,
    attrs = {
        "iso_date": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
        ),
        "sha256": attr.string(
            doc = "The sha256 of the rustfmt artifact.",
        ),
        "triple": attr.string(
            doc = "The Rust-style target that this compiler runs on",
            mandatory = True,
        ),
        "urls": attr.string_list(
            doc = (
                "A list of mirror urls containing the tools from the Rust-lang static file server. " +
                "These must contain the '{}' used to substitute the tool being fetched (using .format)."
            ),
            default = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        ),
        "version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
            mandatory = True,
        ),
    },
)

def _rust_cargo_repository_impl(repository_ctx):
    """The `rust_cargo_repository` repository rule implementation"""

    write_build_and_workspace(repository_ctx, load_cargo(repository_ctx))

rust_cargo_repository = repository_rule(
    doc = (
        "A repository rule for downloading a [Cargo](https://doc.rust-lang.org/cargo/) artifact for " +
        "use in a `rust_cargo_toolchain`."
    ),
    implementation = _rust_cargo_repository_impl,
    attrs = {
        "iso_date": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
        ),
        "sha256": attr.string(
            doc = "The sha256 of the cargo artifact.",
        ),
        "triple": attr.string(
            doc = "The Rust-style target that this compiler runs on",
            mandatory = True,
        ),
        "urls": attr.string_list(
            doc = (
                "A list of mirror urls containing the tools from the Rust-lang static file server. " +
                "These must contain the '{}' used to substitute the tool being fetched (using .format)."
            ),
            default = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        ),
        "version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
            mandatory = True,
        ),
    },
)

def _rust_clippy_repository_impl(repository_ctx):
    """The `rust_clippy_repository` repository rule implementation"""

    write_build_and_workspace(repository_ctx, load_clippy(repository_ctx))

rust_clippy_repository = repository_rule(
    doc = (
        "A repository rule for defining a `rust_clippy_toolchain` from the requested version of " +
        "[Clippy](https://github.com/rust-lang/rust-clippy#readme)"
    ),
    implementation = _rust_clippy_repository_impl,
    attrs = {
        "iso_date": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
        ),
        "sha256": attr.string(
            doc = "The sha256 of the clippy-driver artifact.",
        ),
        "triple": attr.string(
            doc = "The Rust-style target that this compiler runs on",
            mandatory = True,
        ),
        "urls": attr.string_list(
            doc = (
                "A list of mirror urls containing the tools from the Rust-lang static file server. " +
                "These must contain the '{}' used to substitute the tool being fetched (using .format)."
            ),
            default = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        ),
        "version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
            mandatory = True,
        ),
    },
)

# buildifier: disable=unnamed-macro
def rust_repositories(
        dev_components = False,
        edition = DEFAULT_RUST_EDITION,
        include_rustc_srcs = False,
        iso_date = None,
        prefix = "rules_rust",
        register_toolchains = True,
        rustfmt_version = None,
        sha256s = None,
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        version = DEFAULT_RUST_VERSION):
    """Instantiate repositories and toolchains required by `rules_rust`.

    Skip this macro and call the [rust_exec_toolchain_repository](#rust_exec_toolchain_repository) or
    [rust_target_toolchain_repository](#rust_target_toolchain_repository) rules directly if you need a
    compiler for other hosts or for additional target triples.

    The `sha256` attribute represents a dict associating tool subdirectories to sha256 hashes. As an example:
    ```python
    {
        "rust-1.46.0-x86_64-unknown-linux-gnu": "e3b98bc3440fe92817881933f9564389eccb396f5f431f33d48b979fa2fbdcf5",
        "rustfmt-1.4.12-x86_64-unknown-linux-gnu": "1894e76913303d66bf40885a601462844eec15fca9e76a6d13c390d7000d64b0",
        "rust-std-1.46.0-x86_64-unknown-linux-gnu": "ac04aef80423f612c0079829b504902de27a6997214eb58ab0765d02f7ec1dbc",
    }
    ```

    Args:
        dev_components (bool, optional): Whether to download the rustc-dev components.
        edition (str, optional): The rust edition to be used by default (2015 (default) or 2018)
        include_rustc_srcs (bool, optional): Whether to download rustc's src code. This is required in order to use rust-analyzer
            support. See [rust_toolchain_repository.include_rustc_srcs](#rust_toolchain_repository-include_rustc_srcs).
            for more details
        iso_date (str, optional): The date of the nightly or beta release (or None, if the version is a specific version).
        prefix (str, optional): The prefix used for all generated repositories. Eg. `{prefix}_{repository}`.
        register_toolchains (bool, optional): Whether or not to register any toolchains. Setting this to false will
            allow for other repositories the rules depend on to get defined while allowing users to have full control
            over their toolchains
        rustfmt_version (str, optional): Same as `version` but is only used for `rustfmt`
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must
            contain the '{}' used to substitute the tool being fetched (using .format).
        version (str, optional): The version of Rust. Either "nightly", "beta", or an exact version. Defaults to a modern version.
    """
    if dev_components and version != "nightly":
        fail("Rust version must be set to \"nightly\" to enable rustc-dev components")

    maybe(
        http_archive,
        name = "rules_cc",
        url = "https://github.com/bazelbuild/rules_cc/archive/624b5d59dfb45672d4239422fa1e3de1822ee110.zip",
        sha256 = "8c7e8bf24a2bf515713445199a677ee2336e1c487fa1da41037c6026de04bbc3",
        strip_prefix = "rules_cc-624b5d59dfb45672d4239422fa1e3de1822ee110",
        type = "zip",
    )

    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "1c531376ac7e5a180e0237938a2536de0c54d93f5c278634818e0efc952dd56c",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
        ],
    )

    if register_toolchains:
        # Register all default exec triples
        for exec_triple in DEFAULT_TOOLCHAIN_TRIPLES:
            for target_triple in SUPPORTED_PLATFORM_TRIPLES:
                rust_repository_set(
                    prefix = prefix,
                    dev_components = dev_components,
                    edition = edition,
                    exec_triple = exec_triple,
                    include_rustc_srcs = include_rustc_srcs,
                    iso_date = iso_date,
                    rustfmt_iso_date = iso_date,
                    sha256s = sha256s,
                    target_triple = target_triple,
                    urls = urls,
                    version = version,
                )

        # Register a fake cc_toolchain for use in wasm_bindgen to allow for the config transition
        # to the wasm target platform.
        native.register_toolchains(str(Label("//rust/private/dummy_cc_toolchain:dummy_cc_wasm32_toolchain")))

# buildifier: disable=unnamed-macro
def rust_repository_set(
        prefix,
        exec_triple,
        target_triple,
        allocator_library = None,
        dev_components = False,
        edition = DEFAULT_RUST_EDITION,
        exec_compatible_with = None,
        include_rustc_srcs = False,
        iso_date = None,
        rustfmt_iso_date = None,
        rustfmt_version = None,
        sha256s = None,
        stdlib_linkflags = None,
        target_compatible_with = None,
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        version = DEFAULT_RUST_VERSION):
    """A repository rule for defining a [rust_exec_toolchain](#rust_exec_toolchain).

    This repository rule generates repositories for host tools (as described by [The rustc book][trc]) and wires
    them into a `rust_exec_toolchain` target. Note that the `rust_exec_toolchain` only includes `rustc` and it's
    dependencies. Additional host tools such as `Cargo`, `Clippy`, and `Rustfmt` are all declared as separate
    toolchains. This rule should be used to define more customized exec toolchains than those created by
    `rust_repositories`.

    Repositories Created:
    - [rust_cargo_repository](#rust_cargo_repository)
    - [rust_clippy_repository](#rust_clippy_repository)
    - [rust_rustc_repository](#rust_rustc_repository)
    - [rust_rustfmt_repository](#rust_rustfmt_repository)
    - [rust_srcs_repository](#rust_srcs_repository)

    Toolchains Created:
    - [rust_exec_toolchain](#rust_exec_toolchain)
    - [rust_cargo_toolchain](#rust_cargo_toolchain)
    - [rust_clippy_toolchain](#rust_clippy_toolchain)
    - [rust_rustfmt_toolchain](#rust_rustfmt_toolchain)


    [trc]: https://doc.rust-lang.org/stable/rustc/platform-support.html

    Args:
        prefix (str): A common prefix for all generated repositories.
        triple (str): The platform triple of the execution environment.
        dev_components (bool, optional): [description]. Defaults to False.
        edition (str, optional): The rust edition to be used by default.
        exec_compatible_with (list, optional): Optional exec constraints for the toolchain. If unset, a default will be used
            based on the value of `triple`. See `@rules_rust//rust/platform:triple_mappings.bzl` for more details.
        include_rustc_srcs (bool, optional): Whether to download and unpack the
            rustc source files. These are very large, and slow to unpack, but are required to support rust analyzer.
        iso_date (str, optional): The date of the tool (or None, if the version is a specific version).
        rustfmt_iso_date (str, optional): Similar to `iso_date` but specific to Rustfmt. If unspecified, `iso_date` will be used.
        rustfmt_version (str, optional): Similar to `version` but specific to Rustfmt. If unspecified, `version` will be used.
        sha256s (dict, optional): A dict associating tool subdirectories to sha256 hashes.
        target_compatible_with (list, optional): Optional target constraints for the toolchain.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must
            contain the '{}' used to substitute the tool being fetched (using .format).
        version (str, optional): The version of the tool among \"nightly\", \"beta\", or an exact version.
    """
    version_str = version if version not in ["nightly", "beta"] else "{}-{}".format(
        version,
        iso_date,
    )

    rustc_repo_name = "{}_rustc_{}_{}".format(prefix, version_str, exec_triple)
    rust_rustc_repository(
        name = rustc_repo_name,
        dev_components = dev_components,
        iso_date = iso_date,
        sha256s = sha256s,
        triple = exec_triple,
        urls = urls,
        version = version,
    )

    # rustc_srcs are platform agnostic so it should be something
    # defined once and shared accross various toolchains
    rustc_srcs_name = "{}_rustc_srcs_{}".format(prefix, version_str)
    maybe(
        rust_srcs_repository,
        name = rustc_srcs_name,
        iso_date = iso_date,
        sha256 = sha256s.get("rustc-src") if sha256s else None,
        urls = urls,
        version = version,
    )

    rustfmt_version_str = version_str
    if rustfmt_version:
        rustfmt_version_str = rustfmt_version if rustfmt_version not in ["nightly", "beta"] else "{}-{}".format(
            rustfmt_version,
            rustfmt_iso_date,
        )

    rustfmt_name = "{}_rustfmt_{}_{}".format(prefix, rustfmt_version_str, exec_triple)
    rust_rustfmt_repository(
        name = rustfmt_name,
        iso_date = rustfmt_iso_date or iso_date,
        triple = exec_triple,
        version = rustfmt_version or version,
        urls = urls,
    )

    cargo_name = "{}_cargo_{}_{}".format(prefix, version_str, exec_triple)
    rust_cargo_repository(
        name = cargo_name,
        iso_date = iso_date,
        triple = exec_triple,
        version = version,
        urls = urls,
    )

    clippy_name = "{}_clippy_{}_{}".format(prefix, version_str, exec_triple)
    rust_clippy_repository(
        name = clippy_name,
        iso_date = iso_date,
        triple = exec_triple,
        version = version,
        urls = urls,
    )

    stdlib_repo_name = "{}_stdlib_{}_{}".format(prefix, version_str, target_triple)
    rust_stdlib_repository(
        name = stdlib_repo_name,
        iso_date = iso_date,
        sha256s = sha256s,
        triple = target_triple,
        urls = urls,
        version = version,
    )

    if exec_compatible_with == None:
        exec_compatible_with = triple_to_constraint_set(exec_triple)

    if target_compatible_with == None:
        target_compatible_with = triple_to_constraint_set(target_triple)

    stdlib_opts = stdlib_linkflags
    if stdlib_opts == None:
        stdlib_opts = system_to_stdlib_linkflags(triple_to_system(target_triple))

    toolchain_name = "{prefix}_toolchain_{ver}_{exec}__{target}".format(
        prefix = prefix,
        ver = version_str,
        exec = exec_triple,
        target = target_triple,
    )

    rust_toolchain_repository(
        name = toolchain_name,
        allocator_library = allocator_library,
        cargo = "@{}//:cargo".format(cargo_name),
        clippy = "@{}//:clippy_driver_bin".format(clippy_name),
        edition = edition,
        exec_compatible_with = exec_compatible_with,
        include_rustc_srcs = include_rustc_srcs,
        iso_date = iso_date,
        rustc_repository = rustc_repo_name,
        rustc_srcs = "@{}//:rustc_srcs".format(rustc_srcs_name),
        rustfmt = "@{}//:rustfmt_bin".format(rustfmt_name),
        stdlib_linkflags = stdlib_opts,
        stdlib_repository = stdlib_repo_name,
        target_compatible_with = target_compatible_with,
        exec_triple = exec_triple,
        target_triple = target_triple,
        version = version,
    )
    native.register_toolchains(*[
        tool.format(toolchain_name)
        for tool in [
            "@{}//:toolchain",
            "@{}//:cargo_toolchain",
            "@{}//:clippy_toolchain",
            "@{}//:rustfmt_toolchain",
        ]
    ])

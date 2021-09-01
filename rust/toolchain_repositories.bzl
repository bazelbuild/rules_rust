"""`rules_rust` uses a collection of repository rules to generate hermtic
toolchains for execution and target environments. A large set of commonly
used toolchains are defined simply by calling `rust_repositories` in your
WORKSPACE file but toolchains can be defined more granularly by using
`rust_repository_set` or any of the other underlying `rust_*_repository`
repository rules with `rust_exec_toolchain_repository` or
`rust_target_toolchain_repository`.
"""

load(
    "//rust/platform:triple_mappings.bzl",
    "system_to_binary_ext",
    "system_to_dylib_ext",
    "system_to_staticlib_ext",
    "system_to_stdlib_linkflags",
    "triple_to_constraint_set",
    "triple_to_system",
)
load("//rust/private:common.bzl", "rust_common")
load(
    "//rust/private:repository_utils.bzl",
    "BUILD_for_exec_toolchain",
    "BUILD_for_target_toolchain",
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
)
load("//rust/private:utils.bzl", "dedent")

def _rust_exec_toolchain_repository_impl(repository_ctx):
    rustc_repository = repository_ctx.attr.rustc_repository
    triple = repository_ctx.attr.triple
    system = triple_to_system(triple)

    include_rustc_srcs_env = repository_ctx.os.environ.get("RULES_RUST_TOOLCHAIN_INCLUDE_RUSTC_SRCS")
    if include_rustc_srcs_env != None:
        include_rustc_srcs = include_rustc_srcs_env.lower() in ["true", "1"]
    else:
        include_rustc_srcs = repository_ctx.attr.include_rustc_srcs
    rustc_srcs = "\"{}\"".format(repository_ctx.attr.rustc_srcs) if include_rustc_srcs else None
    iso_date = "\"{}\"".format(repository_ctx.attr.iso_date) if repository_ctx.attr.iso_date else None

    build_file_contents = BUILD_for_exec_toolchain(
        name = repository_ctx.name,
        cargo = repository_ctx.attr.cargo,
        clippy = repository_ctx.attr.clippy,
        exec_constraints = repository_ctx.attr.exec_compatible_with,
        target_constraints = repository_ctx.attr.target_compatible_with,
        default_edition = repository_ctx.attr.edition,
        iso_date = iso_date,
        os = system,
        rustc = "@{}//:rustc".format(rustc_repository),
        rustc_lib = "@{}//:rustc_lib".format(rustc_repository),
        rustc_srcs = rustc_srcs,
        rustdoc = "@{}//:rustdoc".format(rustc_repository),
        rustfmt = repository_ctx.attr.rustfmt,
        triple = triple,
        version = repository_ctx.attr.version,
    )

    write_build_and_workspace(repository_ctx, build_file_contents)

_rust_exec_toolchain_repository = repository_rule(
    doc = dedent("""\
    A repository rule for wiring together all tools and components required by a host/exec platform for compilation.

    This rule can be used to represent any rustc platform with "host" tools. It creates a `rust_exec_toolchain` using
    generated labels for it's dependencies to allow the toolchain to be registered without requiring that the components
    are first downloaded. For more details on rustc platforms and host tools, see
    [The rustc book](https://doc.rust-lang.org/stable/rustc/platform-support.html).
    """),
    attrs = {
        "auth": attr.string_dict(
            doc = (
                "Auth object compatible with repository_ctx.download to use when downloading files. " +
                "See https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download for more details."
            ),
        ),
        "cargo": attr.string(
            doc = "The label of a Cargo binary from `rust_cargo_repository`",
        ),
        "clippy": attr.string(
            doc = "The label of a Clippy binary from `rust_clippy_repository`",
        ),
        "edition": attr.string(
            doc = "The rust edition to be used by default.",
            default = rust_common.default_edition,
        ),
        "exec_compatible_with": attr.string_list(
            doc = (
                "A list of constraint_values that must be present in the execution platform for this target. " +
                "If left unspecified, a default set for the provided triple will be used. See " +
                "`@rules_rust//rust/platform:triple_mappings.bzl%triple_to_constraint_set`."
            ),
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
        "target_compatible_with": attr.string_list(
            doc = (
                "A list of constraint_values that must be present in the target platform for this target to " +
                "be considered compatible."
            ),
        ),
        "triple": attr.string(
            doc = "The Rust-style target that this compiler runs on",
            mandatory = True,
        ),
        "version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
            mandatory = True,
        ),
    },
    implementation = _rust_exec_toolchain_repository_impl,
    environ = ["RULES_RUST_TOOLCHAIN_INCLUDE_RUSTC_SRCS"],
)

def _rust_target_toolchain_repository_impl(repository_ctx):
    stdlib_repository = repository_ctx.attr.stdlib_repository
    triple = repository_ctx.attr.triple
    system = triple_to_system(triple)

    allocator_library = "\"{}\"".format(repository_ctx.attr.allocator_library) if repository_ctx.attr.allocator_library else None

    stdlib_linkflags = None
    if "BAZEL_RUST_STDLIB_LINKFLAGS" in repository_ctx.os.environ:
        stdlib_linkflags = repository_ctx.os.environ["BAZEL_RUST_STDLIB_LINKFLAGS"].split(":")
    if stdlib_linkflags == None:
        stdlib_linkflags = repository_ctx.attr.stdlib_linkflags

    iso_date = "\"{}\"".format(repository_ctx.attr.iso_date) if repository_ctx.attr.iso_date else None

    build_file_contents = BUILD_for_target_toolchain(
        name = repository_ctx.name,
        allocator_library = allocator_library,
        binary_ext = system_to_binary_ext(system),
        dylib_ext = system_to_dylib_ext(system),
        os = system,
        rust_stdlib = "@{}//:rust_std".format(stdlib_repository),
        staticlib_ext = system_to_staticlib_ext(system),
        stdlib_linkflags = stdlib_linkflags,
        triple = triple,
        exec_constraints = repository_ctx.attr.exec_compatible_with,
        target_constraints = repository_ctx.attr.target_compatible_with,
        version = repository_ctx.attr.version,
        iso_date = iso_date,
    )

    write_build_and_workspace(repository_ctx, build_file_contents)

_rust_target_toolchain_repository = repository_rule(
    doc = dedent("""\
    A repository rule for wiring together all components required by a target platform for compilation.

    This rule is used to represent any target platform. It creates a `rust_target_toolchain` using
    generated labels for it's dependencies to allow the toolchain to be registered without requiring that the components
    are first downloaded. For more information on target platforms see
    [The rustc book](https://doc.rust-lang.org/stable/rustc/platform-support.html).
    """),
    attrs = {
        "allocator_library": attr.label(
            doc = "Target that provides allocator functions when rust_library targets are embedded in a `cc_binary`.",
        ),
        "auth": attr.string_dict(
            doc = (
                "Auth object compatible with repository_ctx.download to use when downloading files. " +
                "See https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download for more details."
            ),
        ),
        "exec_compatible_with": attr.string_list(
            doc = "A list of constraint_values that must be present in the execution platform for this target.",
        ),
        "iso_date": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
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
                "be considered compatible. If left unspecified, a default set for the provided triple will be used. See " +
                "`@rules_rust//rust/platform:triple_mappings.bzl%triple_to_constraint_set`."
            ),
        ),
        "triple": attr.string(
            doc = "The platform triple of the target environment.",
            mandatory = True,
        ),
        "version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
            mandatory = True,
        ),
    },
    implementation = _rust_target_toolchain_repository_impl,
    environ = ["BAZEL_RUST_STDLIB_LINKFLAGS"],
)

# buildifier: disable=unnamed-macro
def rust_exec_toolchain_repository(
        name,
        triple,
        dev_components = False,
        edition = rust_common.default_edition,
        exec_compatible_with = None,
        include_rustc_srcs = False,
        iso_date = None,
        rustfmt_iso_date = None,
        rustfmt_version = None,
        sha256s = None,
        target_compatible_with = [],
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        version = rust_common.default_version):
    """A repository rule for defining a [rust_exec_toolchain](#rust_exec_toolchain).

    This repository rule generates repositories for host tools (as described by [The rustc book][trc]) and wires
    them into a `rust_exec_toolchain` target. Note that the `rust_exec_toolchain` only includes `rustc` and it's
    dependencies. Additional host tools such as `Cargo`, `Clippy`, and `Rustfmt` are all declared as separate
    toolchains. This rule should be used to define more customized exec toolchains than those created by
    `rust_repositories`.

    Tool Repositories Created:
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
        name (str): The name of the toolchain repository as well as the prefix for each individual 'tool repository'.
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

    rustc_repo_name = "{}_rustc".format(name)
    rust_rustc_repository(
        name = rustc_repo_name,
        dev_components = dev_components,
        iso_date = iso_date,
        sha256s = sha256s,
        triple = triple,
        urls = urls,
        version = version,
    )

    # rustc_srcs are platform agnostic so it should be something
    # defined once and shared accross various toolchains
    rustc_srcs_name = "{}_rustc_srcs".format(name)
    if not rustc_srcs_name in native.existing_rules():
        rust_srcs_repository(
            name = rustc_srcs_name,
            iso_date = iso_date,
            sha256 = sha256s.get("rustc-src") if sha256s else None,
            urls = urls,
            version = version,
        )

    rustfmt_name = "{}_rustfmt".format(name)
    if rustfmt_version:
        rustfmt_version_str = rustfmt_version if rustfmt_version not in ["nightly", "beta"] else "{}-{}".format(
            rustfmt_version,
            rustfmt_iso_date,
        )
        rustfmt_name = "{}_{}".format(rustfmt_name, rustfmt_version)

    rust_rustfmt_repository(
        name = rustfmt_name,
        iso_date = rustfmt_iso_date or iso_date,
        triple = triple,
        version = rustfmt_version or version,
        urls = urls,
    )

    cargo_name = "{}_cargo".format(name)
    rust_cargo_repository(
        name = cargo_name,
        iso_date = iso_date,
        triple = triple,
        version = version,
        urls = urls,
    )

    clippy_name = "{}_clippy".format(name)
    rust_clippy_repository(
        name = clippy_name,
        iso_date = iso_date,
        triple = triple,
        version = version,
        urls = urls,
    )

    _rust_exec_toolchain_repository(
        name = name,
        cargo = "@{}//:cargo".format(cargo_name),
        clippy = "@{}//:clippy_driver_bin".format(clippy_name),
        edition = edition,
        exec_compatible_with = exec_compatible_with or triple_to_constraint_set(triple),
        include_rustc_srcs = include_rustc_srcs,
        rustc_repository = rustc_repo_name,
        rustc_srcs = "@{}//:rustc_srcs".format(rustc_srcs_name),
        rustfmt = "@{}//:rustfmt_bin".format(rustfmt_name),
        target_compatible_with = target_compatible_with,
        triple = triple,
        version = version,
    )
    native.register_toolchains(*[
        tool.format(name)
        for tool in [
            "@{}//:toolchain",
            "@{}//:cargo_toolchain",
            "@{}//:clippy_toolchain",
            "@{}//:rustfmt_toolchain",
        ]
    ])

# buildifier: disable=unnamed-macro
def rust_target_toolchain_repository(
        name,
        triple,
        allocator_library = None,
        exec_compatible_with = [],
        iso_date = None,
        sha256s = None,
        stdlib_linkflags = None,
        target_compatible_with = None,
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        version = rust_common.default_version):
    """A repository rule for defining a [rust_target_toolchain](#rust_target_toolchain).

    This rule declares repository rules for components that may be required to build for the target platform
    such as the `rust-std` artifact. The targets that represent these components are wired into the
    `rust_target_toolchain` that's created which is then consumed by a `rust_toolchain` target for generating
    the sysroot to use in a `Rustc` action. This rule should be used to define more customized target toolchains
    than those created by `rust_repositories`.

    Tool Repositories Created:
    - [rust_stdlib_repository](#rust_stdlib_repository)

    Toolchains Created:
    - [rust_target_toolchain](#rust_target_toolchain)

    Args:
        name (str): The name of the toolchain repository as well as the prefix for each individual 'tool repository'.
        triple (str): The platform triple of the target environment.
        allocator_library (str, optional): Target that provides allocator functions when rust_library targets are embedded in a `cc_binary`.
        exec_compatible_with (list, optional): Optional exec constraints for the toolchain.
        iso_date (str, optional): The date of the tool (or None, if the version is a specific version).
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes.
        stdlib_linkflags (list, optional): The repository name for a `rust_stdlib_repository`.
        target_compatible_with (list, optional): Optional target constraints for the toolchain. If unset, a default will be used
            based on the value of `triple`. See `@rules_rust//rust/platform:triple_mappings.bzl` for more details.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must
            contain the '{}' used to substitute the tool being fetched (using .format).
        version (str, optional): The version of the tool among \"nightly\", \"beta\", or an exact version.
    """
    stdlib_repo_name = "{}_stdlib".format(name)
    rust_stdlib_repository(
        name = stdlib_repo_name,
        iso_date = iso_date,
        sha256s = sha256s,
        triple = triple,
        urls = urls,
        version = version,
    )

    stdlib_opts = stdlib_linkflags
    if stdlib_opts == None:
        stdlib_opts = system_to_stdlib_linkflags(triple_to_system(triple))

    _rust_target_toolchain_repository(
        name = name,
        allocator_library = allocator_library,
        exec_compatible_with = exec_compatible_with,
        iso_date = iso_date,
        stdlib_linkflags = stdlib_opts,
        stdlib_repository = stdlib_repo_name,
        target_compatible_with = target_compatible_with or triple_to_constraint_set(triple),
        triple = triple,
        version = version,
    )

    native.register_toolchains("@{}//:toolchain".format(name))

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
        "auth": attr.string_dict(
            doc = (
                "Auth object compatible with repository_ctx.download to use when downloading files. " +
                "See https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download for more details."
            ),
        ),
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
        "auth": attr.string_dict(
            doc = (
                "Auth object compatible with repository_ctx.download to use when downloading files. " +
                "See https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download for more details."
            ),
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
        "auth": attr.string_dict(
            doc = (
                "Auth object compatible with repository_ctx.download to use when downloading files. " +
                "See https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download for more details."
            ),
        ),
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
        "auth": attr.string_dict(
            doc = (
                "Auth object compatible with repository_ctx.download to use when downloading files. " +
                "See https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download for more details."
            ),
        ),
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
        "auth": attr.string_dict(
            doc = (
                "Auth object compatible with repository_ctx.download to use when downloading files. " +
                "See https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download for more details."
            ),
        ),
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
        "auth": attr.string_dict(
            doc = (
                "Auth object compatible with repository_ctx.download to use when downloading files. " +
                "See https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download for more details."
            ),
        ),
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

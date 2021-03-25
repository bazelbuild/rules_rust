# buildifier: disable=module-docstring
DEFAULT_REPOSITORY_TEMPLATE = "https://crates.io/api/v1/crates/{crate}/{version}/download"

def _crate_universe_resolve_impl(repository_ctx):
    """Entry-point repository to manage rust dependencies.

    General flow is:
    - Serialize user-provided rule attributes into JSON
    - Call the Rust resolver script. It writes a `defs.bzl` file in this repo containing the
      transitive dependencies as repo rules in a `pinned_rust_install()` macro.
    - The user then calls defs.bzl%pinned_rust_install().

    Environment Variables:
        RULES_RUST_UPDATE_CRATE_UNIVERSE_LOCKFILE: Re-pin the lockfile if `true`.
        RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE: Override URL to use to download resolver binary - for local paths use a file:// URL.
    """

    if repository_ctx.os.name == "linux":
        toolchain_repo = "@rust_linux_x86_64"
    elif repository_ctx.os.name == "mac os x":
        toolchain_repo = "@rust_darwin_x86_64"
    else:
        fail("Could not locate resolver for OS " + repository_ctx.os.name)
    cargo_label = Label(toolchain_repo + "//:bin/cargo")
    rustc_label = Label(toolchain_repo + "//:bin/rustc")

    lockfile_path = None
    if repository_ctx.attr.lockfile:
        lockfile_path = repository_ctx.path(repository_ctx.attr.lockfile)

    # Yay hand-crafted JSON serialisation...
    input_content = """{{
  "repository_name": {name},
  "packages": [
      {packages}
  ],
  "cargo_toml_files": {{
      {cargo_toml_files}
  }},
  "overrides": {{
      {overrides}
  }},
  "repository_template": "{repository_template}",
  "target_triples": [
    {targets}
  ],
  "cargo": "{cargo}"
}}""".format(
        name = "\"{}\"".format(repository_ctx.attr.name),
        packages = ",\n".join([artifact for artifact in repository_ctx.attr.packages]),
        cargo_toml_files = ",\n".join(['"{}": "{}"'.format(ct, repository_ctx.path(ct)) for ct in repository_ctx.attr.cargo_toml_files]),
        overrides = ",\n".join(["\"{}\": {}".format(oname, ovalue) for (oname, ovalue) in repository_ctx.attr.overrides.items()]),
        repository_template = repository_ctx.attr.repository_template,
        targets = ",\n".join(['"{}"'.format(target) for target in repository_ctx.attr.supported_targets]),
        cargo = repository_ctx.path(cargo_label),
    )

    input_path = "_{name}.json".format(name = repository_ctx.attr.name)

    # For debugging or working on changes to the resolver, you can set something like:
    #   export RULES_RUST_RESOLVER_URL_OVERRIDE=file:///path/to/rules_rust/cargo/crate_universe_resolver/target/release/resolver
    resolver_url = repository_ctx.os.environ.get("RULES_RUST_CRATE_UNIVERSE_RESOLVER_URL_OVERRIDE", None)
    if resolver_url and resolver_url.startswith("file://"):
        sha256_result = repository_ctx.execute(["sha256sum", resolver_url[7:]])
        resolver_sha = sha256_result.stdout[:64]

        resolver_path = repository_ctx.path("resolver")
        repository_ctx.download(
            url = resolver_url,
            sha256 = resolver_sha,
            output = resolver_path,
            executable = True,
        )
    else:
        # TODO: Avoid downloading both the linux and darwin one each time.
        if repository_ctx.os.name == "linux":
            resolver_path = repository_ctx.path(repository_ctx.attr._resolver_script_linux)
        elif repository_ctx.os.name == "mac os x":
            resolver_path = repository_ctx.path(repository_ctx.attr._resolver_script_darwin)
        else:
            fail("Could not locate resolver for OS " + repository_ctx.os.name)

    repository_ctx.file(input_path, content = input_content)

    args = [
        resolver_path,
        "--input_path",
        input_path,
        "--output_path",
        repository_ctx.path("defs.bzl"),
        "--repo-name",
        repository_ctx.attr.name,
    ]
    if lockfile_path != None:
        args.append("--lockfile")
        str(args.append(lockfile_path))
    if repository_ctx.os.environ.get("RULES_RUST_UPDATE_CRATE_UNIVERSE_LOCKFILE", "false") == "true":
        args.append("--update-lockfile")

    path_binaries = [
        repository_ctx.path(rustc_label),
    ]

    result = repository_ctx.execute(
        args,
        environment = {
            # The resolver invokes `cargo metadata` which relies on `rustc` being on the $PATH
            # See https://github.com/rust-lang/cargo/issues/8219
            "PATH": ":".join([str(b.dirname) for b in path_binaries]),

            "RUST_LOG": "info",
        },
    )
    repository_ctx.delete(input_path)
    if result.stderr:
        print("Output from resolver: " + result.stderr) # buildifier: disable=print
    if result.return_code != 0:
        fail("Error resolving deps:\n" + result.stdout + "\n" + result.stderr)

    repository_ctx.file("BUILD.bazel")

_crate_universe_resolve = repository_rule(
    implementation = _crate_universe_resolve_impl,
    attrs = {
        "cargo_toml_files": attr.label_list(),
        "lockfile": attr.label(
            allow_single_file = True,
            mandatory = False,
        ),
        "overrides": attr.string_dict(doc = """Mapping of crate name to crate.override(...) entries)

Example:

    load("@rules_rust//cargo:workspace.bzl", "rust_library", "crate")

    rust_library(
        name = "mylib",
        # [...]
        overrides = {
            "tokio": crate.override(
                extra_rust_env_vars = {
                    "MY_ENV_VAR": "MY_ENV_VALUE",
                },
                extra_build_script_env_vars = {
                    "MY_BUILD_SCRIPT_ENV_VAR": "MY_ENV_VALUE",
                },
                extra_bazel_deps = {
                    # Extra dependencies are per target. They are additive.
                    "cfg(unix)": ["@somerepo//:foo"],  # cfg() predicate.
                    "x86_64-apple-darwin": ["@somerepo//:bar"],  # Specific triple.
                    "cfg(all())": ["@somerepo//:baz"],  # Applies to all targets ("regular dependency").
                },
                extra_build_script_bazel_deps = {
                    # Extra dependencies are per target. They are additive.
                    "cfg(unix)": ["@buildscriptdep//:foo"],
                    "x86_64-apple-darwin": ["@buildscriptdep//:bar"],
                    "cfg(all())": ["@buildscriptdep//:baz"],
                },
                extra_bazel_data_deps = {
                    # ...
                },
                extra_build_script_bazel_data_deps = {
                    # ...
                },
            ),
        },
    )

"""),
        "packages": attr.string_list(allow_empty = True),
        "repository_template": attr.string(),
        "supported_targets": attr.string_list(allow_empty = False),
        "_resolver_script_darwin": attr.label(
            default = "@crate_universe_resolver_darwin//file:downloaded",
            executable = True,
            cfg = "host",
        ),
        "_resolver_script_linux": attr.label(
            default = "@crate_universe_resolver_linux//file:downloaded",
            executable = True,
            cfg = "host",
        ),
    },
)

def crate_universe(
        name,
        packages = [],
        cargo_toml_files = [],
        overrides = {},
        repository_template = None,
        supported_targets = [],
        lockfile = None):
    """Resolve crates from a cargo repository which can be consumed as dependencies by targets using rules_rust.

    This is currently highly experimental, and subject to breaking API changes without notice.

    In order to actually use this rule, you will need to make available a built version of the rust binary in `cargo/crate_universe_resolver`
    as an http_file with the name crate_universe_resolver_linux or crate_universe_resolver_darwin (whichever is appropriate for your platform).
    """

    _crate_universe_resolve(
        name = name,
        packages = [package.to_json() for package in packages],
        cargo_toml_files = [_absolutify(label) for label in cargo_toml_files],
        overrides = dict([(k, v.to_json()) for (k, v) in overrides.items()]),
        repository_template = repository_template if repository_template else DEFAULT_REPOSITORY_TEMPLATE,
        supported_targets = supported_targets,
        lockfile = lockfile,
    )

def _absolutify(label):
    if label.startswith("//") or label.startswith("@"):
        return label
    if label.startswith(":"):
        return "//" + native.package_name() + label
    return "//" + native.package_name() + ":" + label

def _spec(
        name,
        semver,
        features = None):
    return struct(
        name = name,
        semver = semver,
        features = features if features else [],
    )

def _override(
        extra_rust_env_vars = None,
        extra_build_script_env_vars = None,
        extra_bazel_deps = None,
        extra_build_script_bazel_deps = None,
        extra_bazel_data_deps = None,
        extra_build_script_bazel_data_deps = None,
        features_to_remove = []):
    for (dep_key, dep_val) in [
        (extra_bazel_deps, extra_bazel_deps),
        (extra_build_script_bazel_deps, extra_build_script_bazel_deps),
        (extra_bazel_data_deps, extra_bazel_data_deps),
        (extra_build_script_bazel_data_deps, extra_build_script_bazel_data_deps),
    ]:
        if dep_val != None:
            if not type(dep_val) == "dict":
                fail("The {} attribute should be a dictionary".format(dep_key))

            for target, deps in dep_val.items():
                if not type(deps) == "list" or any([type(x) != "string" for x in deps]):
                    fail("The {} values should be lists of strings".format(dep_key))

    return struct(
        extra_rust_env_vars = extra_rust_env_vars if extra_rust_env_vars else {},
        extra_build_script_env_vars = extra_build_script_env_vars if extra_build_script_env_vars else {},
        extra_bazel_deps = extra_bazel_deps if extra_bazel_deps else {},
        extra_build_script_bazel_deps = extra_build_script_bazel_deps if extra_build_script_bazel_deps else {},
        extra_bazel_data_deps = extra_bazel_data_deps if extra_bazel_data_deps else {},
        extra_build_script_bazel_data_deps = extra_build_script_bazel_data_deps if extra_build_script_bazel_data_deps else {},
        features_to_remove = features_to_remove,
    )

crate = struct(
    spec = _spec,
    override = _override,
)

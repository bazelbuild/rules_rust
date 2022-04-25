"""Rules for vendoring Bazel targets into existing workspaces"""

load("//crate_universe/private:generate_utils.bzl", "compile_config", "render_config")
load("//crate_universe/private:splicing_utils.bzl", "kebab_case_keys", "splicing_config")
load("//crate_universe/private:urls.bzl", "CARGO_BAZEL_LABEL")
load("//rust/platform:triple_mappings.bzl", "SUPPORTED_PLATFORM_TRIPLES")

_UNIX_WRAPPER = """\
#!/usr/bin/env bash
set -euo pipefail
export RUNTIME_PWD="$(pwd)"
eval exec env - BUILD_WORKSPACE_DIRECTORY="${{BUILD_WORKSPACE_DIRECTORY}}" {env} \\
"{bin}" {args} "$@"
"""

_WINDOWS_WRAPPER = """\
@ECHO OFF
set RUNTIME_PWD=%CD%
{env}

call {bin} {args} %@%
"""

CARGO_BAZEL_GENERATOR_PATH = "CARGO_BAZEL_GENERATOR_PATH"

def _runfiles_path(path, is_windows):
    if is_windows:
        runtime_pwd_var = "%RUNTIME_PWD%"
    else:
        runtime_pwd_var = "${RUNTIME_PWD}"
    if path.startswith("../"):
        return "{}/external/{}".format(runtime_pwd_var, path[len("../"):])
    return "{}/{}".format(runtime_pwd_var, path)

def _is_windows(ctx):
    toolchain = ctx.toolchains[Label("@rules_rust//rust:toolchain")]
    return "windows" in toolchain.target_triple

def _get_output_package(ctx):
    # Determine output directory
    if ctx.attr.vendor_path.startswith("/"):
        output = ctx.attr.vendor_path
    else:
        output = "{}/{}".format(
            ctx.label.package,
            ctx.attr.vendor_path,
        )
    return output

def _write_data_file(ctx, name, data):
    file = ctx.actions.declare_file("{}.{}".format(ctx.label.name, name))
    ctx.actions.write(
        output = file,
        content = data,
    )
    return file

def _write_splicing_manifest(ctx):
    # Deserialize information about direct packges
    direct_packages_info = {
        # Ensure the data is using kebab-case as that's what `cargo_toml::DependencyDetail` expects.
        pkg: kebab_case_keys(dict(json.decode(data)))
        for (pkg, data) in ctx.attr.packages.items()
    }

    # Manifests are required to be single files
    manifests = {m[DefaultInfo].files.to_list()[0].short_path: str(m.label) for m in ctx.attr.manifests}

    config = json.decode(ctx.attr.splicing_config or splicing_config())
    splicing_manifest_content = {
        # TODO: How do cargo config files get factored into vendored builds
        "cargo_config": None,
        "direct_packages": direct_packages_info,
        "manifests": manifests,
    }

    manifest = _write_data_file(
        ctx = ctx,
        name = "cargo-bazel-splicing-manifest.json",
        data = json.encode_indent(
            dict(dict(config).items() + splicing_manifest_content.items()),
            indent = " " * 4,
        ),
    )

    is_windows = _is_windows(ctx)

    args = ["--splicing-manifest", _runfiles_path(manifest.short_path, is_windows)]
    runfiles = [manifest]
    return args, runfiles

def _write_extra_manifests_manifest(ctx):
    manifest = _write_data_file(
        ctx = ctx,
        name = "cargo-bazel-extra-manifests-manifest.json",
        data = json.encode(struct(
            # TODO: This is for extra workspace members
            manifests = [],
        )),
    )
    is_windows = _is_windows(ctx)
    args = ["--extra-manifests-manifest", _runfiles_path(manifest.short_path, is_windows)]
    runfiles = [manifest]
    return args, runfiles

def _write_config_file(ctx):
    rendering_config = dict(json.decode(render_config()))

    output_pkg = _get_output_package(ctx)

    if ctx.attr.mode == "local":
        build_file_base_template = "@{}//{}/{{name}}-{{version}}:BUILD.bazel"
        crate_label_template = "//{}/{{name}}-{{version}}:{{target}}".format(
            output_pkg,
        )
    else:
        build_file_base_template = "@{}//{}:BUILD.{{name}}-{{version}}.bazel"
        crate_label_template = rendering_config["crate_label_template"]

    rendering_config.update({
        "build_file_template": build_file_base_template.format(
            ctx.workspace_name,
            output_pkg,
        ),
        "crate_label_template": crate_label_template,
        "crates_module_template": "@{}//{}:{{file}}".format(
            ctx.workspace_name,
            output_pkg,
        ),
        "vendor_mode": ctx.attr.mode,
    })

    config_data = compile_config(
        crate_annotations = ctx.attr.annotations,
        generate_build_scripts = ctx.attr.generate_build_scripts,
        cargo_config = None,
        render_config = rendering_config,
        supported_platform_triples = ctx.attr.supported_platform_triples,
        repository_name = ctx.attr.repository_name or ctx.label.name,
    )

    config = _write_data_file(
        ctx = ctx,
        name = "cargo-bazel-config.json",
        data = json.encode_indent(
            config_data,
            indent = " " * 4,
        ),
    )

    is_windows = _is_windows(ctx)
    args = ["--config", _runfiles_path(config.short_path, is_windows)]
    runfiles = [config] + ctx.files.manifests
    return args, runfiles

def _crates_vendor_impl(ctx):
    toolchain = ctx.toolchains[Label("@rules_rust//rust:toolchain")]
    is_windows = _is_windows(ctx)

    environ = {
        "CARGO": _runfiles_path(toolchain.cargo.short_path, is_windows),
        "RUSTC": _runfiles_path(toolchain.rustc.short_path, is_windows),
    }

    args = ["vendor"]

    cargo_bazel_runfiles = []

    # Allow action envs to override the use of the cargo-bazel target.
    if CARGO_BAZEL_GENERATOR_PATH in ctx.var:
        bin_path = ctx.var[CARGO_BAZEL_GENERATOR_PATH]
    elif ctx.executable.cargo_bazel:
        bin_path = _runfiles_path(ctx.executable.cargo_bazel.short_path, is_windows)
        cargo_bazel_runfiles.append(ctx.executable.cargo_bazel)
    else:
        fail("{} is missing either the `cargo_bazel` attribute or the '{}' action env".format(
            ctx.label,
            CARGO_BAZEL_GENERATOR_PATH,
        ))

    # Generate config file
    config_args, config_runfiles = _write_config_file(ctx)
    args.extend(config_args)
    cargo_bazel_runfiles.extend(config_runfiles)

    # Generate splicing manifest
    splicing_manifest_args, splicing_manifest_runfiles = _write_splicing_manifest(ctx)
    args.extend(splicing_manifest_args)
    cargo_bazel_runfiles.extend(splicing_manifest_runfiles)

    # Generate extra-manifests manifest
    extra_manifests_manifest_args, extra_manifests_manifest_runfiles = _write_extra_manifests_manifest(ctx)
    args.extend(extra_manifests_manifest_args)
    cargo_bazel_runfiles.extend(extra_manifests_manifest_runfiles)

    # Optionally include buildifier
    if ctx.attr.buildifier:
        args.extend(["--buildifier", _runfiles_path(ctx.executable.buildifier.short_path, is_windows)])
        cargo_bazel_runfiles.append(ctx.executable.buildifier)

    # Dtermine platform specific settings
    if is_windows:
        extension = ".bat"
        template = _WINDOWS_WRAPPER
        env_template = "\nset {}={}"
    else:
        extension = ".sh"
        template = _UNIX_WRAPPER
        env_template = "{}={}"

    # Write the wrapper script
    runner = ctx.actions.declare_file(ctx.label.name + extension)
    ctx.actions.write(
        output = runner,
        content = template.format(
            env = " ".join([env_template.format(key, val) for key, val in environ.items()]),
            bin = bin_path,
            args = " ".join(args),
        ),
        is_executable = True,
    )

    return DefaultInfo(
        files = depset([runner]),
        runfiles = ctx.runfiles(
            files = cargo_bazel_runfiles,
            transitive_files = toolchain.all_files,
        ),
        executable = runner,
    )

crates_vendor = rule(
    implementation = _crates_vendor_impl,
    doc = "A rule for defining Rust dependencies (crates) and writing targets for them to the current workspace",
    attrs = {
        "annotations": attr.string_list_dict(
            doc = "Extra settings to apply to crates. See [crate.annotation](#crateannotation).",
        ),
        "buildifier": attr.label(
            doc = "The path to a [buildifier](https://github.com/bazelbuild/buildtools/blob/5.0.1/buildifier/README.md) binary used to format generated BUILD files.",
            cfg = "exec",
            executable = True,
            default = Label("//crate_universe/private/vendor:buildifier"),
        ),
        "cargo_bazel": attr.label(
            doc = (
                "The cargo-bazel binary to use for vendoring. If this attribute is not set, then a " +
                "`{}` action env will be used.".format(CARGO_BAZEL_GENERATOR_PATH)
            ),
            cfg = "exec",
            executable = True,
            allow_files = True,
            default = CARGO_BAZEL_LABEL,
        ),
        "generate_build_scripts": attr.bool(
            doc = (
                "Whether or not to generate " +
                "[cargo build scripts](https://doc.rust-lang.org/cargo/reference/build-scripts.html) by default."
            ),
            default = True,
        ),
        "manifests": attr.label_list(
            doc = "A list of Cargo manifests (`Cargo.toml` files).",
            allow_files = ["Cargo.toml"],
        ),
        "mode": attr.string(
            doc = (
                "Flags determining how crates should be vendored. `local` is where crate source and BUILD files are " +
                "written to the repository. `remote` is where only BUILD files are written and repository rules " +
                "used to fetch source code."
            ),
            values = [
                "local",
                "remote",
            ],
            default = "remote",
        ),
        "packages": attr.string_dict(
            doc = "A set of crates (packages) specifications to depend on. See [crate.spec](#crate.spec).",
        ),
        "repository_name": attr.string(
            doc = "The name of the repository to generate for `remote` vendor modes. If unset, the label name will be used",
        ),
        "splicing_config": attr.string(
            doc = (
                "The configuration flags to use for splicing Cargo maniests. Use `//crate_universe:defs.bzl\\%rsplicing_config` to " +
                "generate the value for this field. If unset, the defaults defined there will be used."
            ),
        ),
        "supported_platform_triples": attr.string_list(
            doc = "A set of all platform triples to consider when generating dependencies.",
            default = SUPPORTED_PLATFORM_TRIPLES,
        ),
        "vendor_path": attr.string(
            doc = "The path to a directory to write files into. Absolute paths will be treated as relative to the workspace root",
            default = "crates",
        ),
    },
    executable = True,
    toolchains = ["@rules_rust//rust:toolchain"],
)

def _crates_vendor_remote_repository_impl(repository_ctx):
    build_file = repository_ctx.path(repository_ctx.attr.build_file)
    defs_module = repository_ctx.path(repository_ctx.attr.defs_module)

    repository_ctx.file("BUILD.bazel", repository_ctx.read(build_file))
    repository_ctx.file("defs.bzl", repository_ctx.read(defs_module))
    repository_ctx.file("crates.bzl", "")
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

crates_vendor_remote_repository = repository_rule(
    doc = "Creates a repository paired with `crates_vendor` targets using the `remote` vendor mode.",
    implementation = _crates_vendor_remote_repository_impl,
    attrs = {
        "build_file": attr.label(
            doc = "The BUILD file to use for the root package",
            mandatory = True,
        ),
        "defs_module": attr.label(
            doc = "The `defs.bzl` file to use in the repository",
            mandatory = True,
        ),
    },
)

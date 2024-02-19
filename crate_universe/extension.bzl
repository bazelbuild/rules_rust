"""Module extension for generating third-party crates for use in bazel."""

load("@bazel_skylib//lib:structs.bzl", "structs")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//crate_universe:defs.bzl", _crate_universe_crate = "crate")
load("//crate_universe/private:crates_vendor.bzl", "CRATES_VENDOR_ATTRS", "generate_config_file", "generate_splicing_manifest")
load("//crate_universe/private:generate_utils.bzl", "render_config")
load("//crate_universe/private/module_extensions:cargo_bazel_bootstrap.bzl", "get_cargo_bazel_runner")

# A list of labels which may be relative (and if so, is within the repo the rule is generated in).
#
# If I were to write ":foo", with attr.label_list, it would evaluate to
# "@@//:foo". However, for a tag such as deps, ":foo" should refer to
# "@@rules_rust~crates~<crate>//:foo".
_relative_label_list = attr.string_list

_OPT_BOOL_VALUES = {
    "auto": None,
    "off": False,
    "on": True,
}

def optional_bool(doc):
    return attr.string(doc = doc, values = _OPT_BOOL_VALUES.keys(), default = "auto")

def _get_or_insert(d, key, value):
    if key not in d:
        d[key] = value
    return d[key]

def _generate_repo_impl(repo_ctx):
    for path, contents in repo_ctx.attr.contents.items():
        repo_ctx.file(path, contents)

_generate_repo = repository_rule(
    implementation = _generate_repo_impl,
    attrs = dict(
        contents = attr.string_dict(mandatory = True),
    ),
)

def _generate_hub_and_spokes(module_ctx, cargo_bazel, cfg, annotations):
    cargo_lockfile = module_ctx.path(cfg.cargo_lockfile)
    tag_path = module_ctx.path(cfg.name)

    rendering_config = json.decode(render_config(
        regen_command = "Run 'cargo update [--workspace]'",
    ))
    config_file = tag_path.get_child("config.json")
    module_ctx.file(
        config_file,
        executable = False,
        content = generate_config_file(
            module_ctx,
            mode = "remote",
            annotations = annotations,
            generate_build_scripts = cfg.generate_build_scripts,
            supported_platform_triples = cfg.supported_platform_triples,
            generate_target_compatible_with = True,
            repository_name = cfg.name,
            output_pkg = cfg.name,
            workspace_name = cfg.name,
            generate_binaries = cfg.generate_binaries,
            render_config = rendering_config,
            repository_ctx = module_ctx,
        ),
    )

    manifests = {module_ctx.path(m): m for m in cfg.manifests}
    splicing_manifest = tag_path.get_child("splicing_manifest.json")
    module_ctx.file(
        splicing_manifest,
        executable = False,
        content = generate_splicing_manifest(
            packages = {},
            splicing_config = "",
            cargo_config = cfg.cargo_config,
            manifests = {str(k): str(v) for k, v in manifests.items()},
            manifest_to_path = module_ctx.path,
        ),
    )

    splicing_output_dir = tag_path.get_child("splicing-output")
    cargo_bazel([
        "splice",
        "--output-dir",
        splicing_output_dir,
        "--config",
        config_file,
        "--splicing-manifest",
        splicing_manifest,
        "--cargo-lockfile",
        cargo_lockfile,
    ])

    # Create a lockfile, since we need to parse it to generate spoke
    # repos.
    lockfile_path = tag_path.get_child("lockfile.json")
    module_ctx.file(lockfile_path, "")

    cargo_bazel([
        "generate",
        "--cargo-lockfile",
        cargo_lockfile,
        "--config",
        config_file,
        "--splicing-manifest",
        splicing_manifest,
        "--repository-dir",
        tag_path,
        "--metadata",
        splicing_output_dir.get_child("metadata.json"),
        "--repin",
        "--lockfile",
        lockfile_path,
    ])

    crates_dir = tag_path.get_child(cfg.name)
    _generate_repo(
        name = cfg.name,
        contents = {
            "BUILD.bazel": module_ctx.read(crates_dir.get_child("BUILD.bazel")),
            "defs.bzl": module_ctx.read(crates_dir.get_child("defs.bzl")),
        },
    )

    contents = json.decode(module_ctx.read(lockfile_path))

    for crate in contents["crates"].values():
        repo = crate["repository"]
        if repo == None:
            continue
        name = crate["name"]
        version = crate["version"]

        # "+" isn't valid in a repo name.
        crate_repo_name = "{repo_name}__{name}-{version}".format(
            repo_name = cfg.name,
            name = name,
            version = version.replace("+", "-"),
        )

        build_file_content = module_ctx.read(crates_dir.get_child("BUILD.%s-%s.bazel" % (name, version)))
        if "Http" in repo:
            # Replicates functionality in repo_http.j2.
            repo = repo["Http"]
            http_archive(
                name = crate_repo_name,
                patch_args = repo.get("patch_args", None),
                patch_tool = repo.get("patch_tool", None),
                patches = repo.get("patches", None),
                remote_patch_strip = 1,
                sha256 = repo.get("sha256", None),
                type = "tar.gz",
                urls = [repo["url"]],
                strip_prefix = "%s-%s" % (crate["name"], crate["version"]),
                build_file_content = build_file_content,
            )
        elif "Git" in repo:
            # Replicates functionality in repo_git.j2
            repo = repo["Git"]
            kwargs = {}
            for k, v in repo["commitish"].items():
                if k == "Rev":
                    kwargs["commit"] = v
                else:
                    kwargs[k.lower()] = v
            new_git_repository(
                name = crate_repo_name,
                init_submodules = True,
                patch_args = repo.get("patch_args", None),
                patch_tool = repo.get("patch_tool", None),
                patches = repo.get("patches", None),
                shallow_since = repo.get("shallow_since", None),
                remote = repo["remote"],
                build_file_content = build_file_content,
                strip_prefix = repo.get("strip_prefix", None),
                **kwargs
            )
        else:
            fail("Invalid repo: expected Http or Git to exist for crate %s-%s, got %s" % (name, version, repo))

def _crate_impl(module_ctx):
    cargo_bazel = get_cargo_bazel_runner(module_ctx)
    all_repos = []
    for mod in module_ctx.modules:
        module_annotations = {}
        repo_specific_annotations = {}
        for annotation_tag in mod.tags.annotation:
            annotation_dict = structs.to_dict(annotation_tag)
            repositories = annotation_dict.pop("repositories")
            crate = annotation_dict.pop("crate")

            # The crate.annotation function can take in either a list or a bool.
            # For the tag-based method, because it has type safety, we have to
            # split it into two parameters.
            if annotation_dict.pop("gen_all_binaries"):
                annotation_dict["gen_binaries"] = True
            annotation_dict["gen_build_script"] = _OPT_BOOL_VALUES[annotation_dict["gen_build_script"]]
            annotation = _crate_universe_crate.annotation(**{
                k: v
                for k, v in annotation_dict.items()
                # Tag classes can't take in None, but the function requires None
                # instead of the empty values in many cases.
                # https://github.com/bazelbuild/bazel/issues/20744
                if v != "" and v != [] and v != {}
            })
            if not repositories:
                _get_or_insert(module_annotations, crate, []).append(annotation)
            for repo in repositories:
                _get_or_insert(
                    _get_or_insert(repo_specific_annotations, repo, {}),
                    crate,
                    [],
                ).append(annotation)

        local_repos = []
        for cfg in mod.tags.from_cargo:
            if cfg.name in local_repos:
                fail("Defined two crate universes with the same name in the same MODULE.bazel file. Use the name tag to give them different names.")
            elif cfg.name in all_repos:
                fail("Defined two crate universes with the same name in different MODULE.bazel files. Either give one a different name, or use use_extension(isolate=True)")

            annotations = {k: v for k, v in module_annotations.items()}
            for crate, values in repo_specific_annotations.get(cfg.name, {}).items():
                _get_or_insert(annotations, crate, []).extend(values)
            _generate_hub_and_spokes(module_ctx, cargo_bazel, cfg, annotations)
            all_repos.append(cfg.name)
            local_repos.append(cfg.name)

        for repo in repo_specific_annotations:
            if repo not in local_repos:
                fail("Annotation specified for repo %s, but the module defined repositories %s" % (repo, local_repos))

_from_cargo = tag_class(
    doc = "Generates a repo @crates from a Cargo.toml / Cargo.lock pair",
    attrs = dict(
        name = attr.string(doc = "The name of the repo to generate", default = "crates"),
        cargo_lockfile = CRATES_VENDOR_ATTRS["cargo_lockfile"],
        manifests = CRATES_VENDOR_ATTRS["manifests"],
        cargo_config = CRATES_VENDOR_ATTRS["cargo_config"],
        generate_binaries = CRATES_VENDOR_ATTRS["generate_binaries"],
        generate_build_scripts = CRATES_VENDOR_ATTRS["generate_build_scripts"],
        supported_platform_triples = CRATES_VENDOR_ATTRS["supported_platform_triples"],
    ),
)

# This should be kept in sync with crate_universe/private/crate.bzl.
_annotation = tag_class(
    attrs = dict(
        repositories = attr.string_list(doc = "A list of repository names specified from `crate.from_cargo(name=...)` that this annotation is applied to. Defaults to all repositories.", default = []),
        crate = attr.string(doc = "The name of the crate the annotation is applied to", mandatory = True),
        version = attr.string(doc = "The versions of the crate the annotation is applied to. Defaults to all versions.", default = "*"),
        additive_build_file_content = attr.string(doc = "Extra contents to write to the bottom of generated BUILD files."),
        additive_build_file = attr.label(doc = "A file containing extra contents to write to the bottom of generated BUILD files."),
        alias_rule = attr.string(doc = "Alias rule to use instead of `native.alias()`.  Overrides [render_config](#render_config)'s 'default_alias_rule'."),
        build_script_data = _relative_label_list(doc = "A list of labels to add to a crate's `cargo_build_script::data` attribute."),
        build_script_tools = _relative_label_list(doc = "A list of labels to add to a crate's `cargo_build_script::tools` attribute."),
        build_script_data_glob = attr.string_list(doc = "A list of glob patterns to add to a crate's `cargo_build_script::data` attribute"),
        build_script_deps = _relative_label_list(doc = "A list of labels to add to a crate's `cargo_build_script::deps` attribute."),
        build_script_env = attr.string_dict(doc = "Additional environment variables to set on a crate's `cargo_build_script::env` attribute."),
        build_script_proc_macro_deps = _relative_label_list(doc = "A list of labels to add to a crate's `cargo_build_script::proc_macro_deps` attribute."),
        build_script_rundir = attr.string(doc = "An override for the build script's rundir attribute."),
        build_script_rustc_env = attr.string_dict(doc = "Additional environment variables to set on a crate's `cargo_build_script::env` attribute."),
        build_script_toolchains = attr.label_list(doc = "A list of labels to set on a crates's `cargo_build_script::toolchains` attribute."),
        compile_data = _relative_label_list(doc = "A list of labels to add to a crate's `rust_library::compile_data` attribute."),
        compile_data_glob = attr.string_list(doc = "A list of glob patterns to add to a crate's `rust_library::compile_data` attribute."),
        crate_features = attr.string_list(doc = "A list of strings to add to a crate's `rust_library::crate_features` attribute."),
        data = _relative_label_list(doc = "A list of labels to add to a crate's `rust_library::data` attribute."),
        data_glob = attr.string_list(doc = "A list of glob patterns to add to a crate's `rust_library::data` attribute."),
        deps = _relative_label_list(doc = "A list of labels to add to a crate's `rust_library::deps` attribute."),
        extra_aliased_targets = attr.string_dict(doc = "A list of targets to add to the generated aliases in the root crate_universe repository."),
        gen_binaries = attr.string_list(doc = "As a list, the subset of the crate's bins that should get `rust_binary` targets produced."),
        gen_all_binaries = attr.bool(doc = "If true, generates `rust_binary` targets for all of the crates bins"),
        disable_pipelining = attr.bool(doc = "If True, disables pipelining for library targets for this crate."),
        gen_build_script = attr.string(
            doc = "An authorative flag to determine whether or not to produce `cargo_build_script` targets for the current crate. Supported values are 'on', 'off', and 'auto'.",
            values = _OPT_BOOL_VALUES.keys(),
            default = "auto",
        ),
        patch_args = attr.string_list(doc = "The `patch_args` attribute of a Bazel repository rule. See [http_archive.patch_args](https://docs.bazel.build/versions/main/repo/http.html#http_archive-patch_args)"),
        patch_tool = attr.string(doc = "The `patch_tool` attribute of a Bazel repository rule. See [http_archive.patch_tool](https://docs.bazel.build/versions/main/repo/http.html#http_archive-patch_tool)"),
        patches = attr.label_list(doc = "The `patches` attribute of a Bazel repository rule. See [http_archive.patches](https://docs.bazel.build/versions/main/repo/http.html#http_archive-patches)"),
        proc_macro_deps = _relative_label_list(doc = "A list of labels to add to a crate's `rust_library::proc_macro_deps` attribute."),
        rustc_env = attr.string_dict(doc = "Additional variables to set on a crate's `rust_library::rustc_env` attribute."),
        rustc_env_files = _relative_label_list(doc = "A list of labels to set on a crate's `rust_library::rustc_env_files` attribute."),
        rustc_flags = attr.string_list(doc = "A list of strings to set on a crate's `rust_library::rustc_flags` attribute."),
        shallow_since = attr.string(doc = "An optional timestamp used for crates originating from a git repository instead of a crate registry. This flag optimizes fetching the source code."),
    ),
)

crate = module_extension(
    implementation = _crate_impl,
    tag_classes = dict(
        from_cargo = _from_cargo,
        annotation = _annotation,
    ),
)

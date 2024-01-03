"""Module extension for generating third-party crates for use in bazel."""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//crate_universe/private:crates_vendor.bzl", "CRATES_VENDOR_ATTRS", "generate_config_file", "generate_splicing_manifest")
load("//crate_universe/private:generate_utils.bzl", "render_config")
load("//crate_universe/private/module_extensions:cargo_bazel_bootstrap.bzl", "get_cargo_bazel_runner")

def _generate_repo_impl(repo_ctx):
    for path, contents in repo_ctx.attr.contents.items():
        repo_ctx.file(path, contents)

_generate_repo = repository_rule(
    implementation = _generate_repo_impl,
    attrs = dict(
        contents = attr.string_dict(mandatory = True),
    ),
)

def _generate_hub_and_spokes(module_ctx, cargo_bazel, cfg):
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
            annotations = {},
            generate_build_scripts = cfg.generate_build_scripts,
            supported_platform_triples = cfg.supported_platform_triples,
            generate_target_compatible_with = True,
            repository_name = cfg.name,
            output_pkg = cfg.name,
            workspace_name = cfg.name,
            generate_binaries = cfg.generate_binaries,
            render_config = rendering_config,
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
        local_repos = []
        for cfg in mod.tags.from_cargo:
            if cfg.name in local_repos:
                fail("Defined two crate universes with the same name in the same MODULE.bazel file. Use the name tag to give them different names.")
            elif cfg.name in all_repos:
                fail("Defined two crate universes with the same name in different MODULE.bazel files. Either give one a different name, or use use_extension(isolate=True)")
            _generate_hub_and_spokes(module_ctx, cargo_bazel, cfg)
            all_repos.append(cfg.name)
            local_repos.append(cfg.name)

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

crate = module_extension(
    implementation = _crate_impl,
    tag_classes = dict(
        from_cargo = _from_cargo,
    ),
)

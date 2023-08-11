"""Macros used for represeting crates or annotations for existing crates"""

def _workspace_member(version, sha256 = None):
    """Define information for extra workspace members

    Args:
        version (str): The semver of the crate to download. Must be an exact version.
        sha256 (str, optional): The sha256 checksum of the `.crate` file.

    Returns:
        string: A json encoded string of all inputs
    """
    return json.encode(struct(
        version = version,
        sha256 = sha256,
    ))

def _spec(
        package = None,
        version = None,
        default_features = True,
        features = [],
        git = None,
        branch = None,
        tag = None,
        rev = None):
    """A constructor for a crate dependency.

    See [specifying dependencies][sd] in the Cargo book for more details.

    [sd]: https://doc.rust-lang.org/cargo/reference/specifying-dependencies.html

    Args:
        package (str, optional): The explicit name of the package (used when attempting to alias a crate).
        version (str, optional): The exact version of the crate. Cannot be used with `git`.
        default_features (bool, optional): Maps to the `default-features` flag.
        features (list, optional): A list of features to use for the crate
        git (str, optional): The Git url to use for the crate. Cannot be used with `version`.
        branch (str, optional): The git branch of the remote crate. Tied with the `git` param. Only one of branch, tag or rev may be specified. Specifying `rev` is recommended for fully-reproducible builds.
        tag (str, optional): The git tag of the remote crate. Tied with the `git` param. Only one of branch, tag or rev may be specified. Specifying `rev` is recommended for fully-reproducible builds.
        rev (str, optional): The git revision of the remote crate. Tied with the `git` param. Only one of branch, tag or rev may be specified.

    Returns:
        string: A json encoded string of all inputs
    """
    return json.encode(struct(
        package = package,
        default_features = default_features,
        features = features,
        version = version,
        git = git,
        branch = branch,
        tag = tag,
        rev = rev,
    ))

def _assert_absolute(label):
    """Ensure a given label is an absolute label

    Args:
        label (Label): The label to check
    """
    label_str = str(label)
    if not label.startswith("@"):
        fail("The labels must be absolute. Please update '{}'".format(
            label_str,
        ))

def _annotation(
        version = "*",
        additive_build_file = None,
        additive_build_file_content = None,
        build_script_data = None,
        build_script_tools = None,
        build_script_data_glob = None,
        build_script_deps = None,
        build_script_env = None,
        build_script_proc_macro_deps = None,
        build_script_rustc_env = None,
        build_script_toolchains = None,
        compile_data = None,
        compile_data_glob = None,
        crate_features = None,
        data = None,
        data_glob = None,
        deps = None,
        extra_aliased_targets = {},
        gen_binaries = [],
        disable_pipelining = False,
        gen_build_script = None,
        patch_args = None,
        patch_tool = None,
        patches = None,
        proc_macro_deps = None,
        rustc_env = None,
        rustc_env_files = None,
        rustc_flags = None,
        shallow_since = None):
    """A collection of extra attributes and settings for a particular crate

    Args:
        version (str, optional): The version or semver-conditions to match with a crate. The wildcard `*`
            matches any version, including prerelease versions.
        additive_build_file_content (str, optional): Extra contents to write to the bottom of generated BUILD files.
        additive_build_file (str, optional): A file containing extra contents to write to the bottom of
            generated BUILD files.
        build_script_data (list, optional): A list of labels to add to a crate's `cargo_build_script::data` attribute.
        build_script_tools (list, optional): A list of labels to add to a crate's `cargo_build_script::tools` attribute.
        build_script_data_glob (list, optional): A list of glob patterns to add to a crate's `cargo_build_script::data`
            attribute.
        build_script_deps (list, optional): A list of labels to add to a crate's `cargo_build_script::deps` attribute.
        build_script_env (dict, optional): Additional environment variables to set on a crate's
            `cargo_build_script::env` attribute.
        build_script_proc_macro_deps (list, optional): A list of labels to add to a crate's
            `cargo_build_script::proc_macro_deps` attribute.
        build_script_rustc_env (dict, optional): Additional environment variables to set on a crate's
            `cargo_build_script::env` attribute.
        build_script_toolchains (list, optional): A list of labels to set on a crates's `cargo_build_script::toolchains` attribute.
        compile_data (list, optional): A list of labels to add to a crate's `rust_library::compile_data` attribute.
        compile_data_glob (list, optional): A list of glob patterns to add to a crate's `rust_library::compile_data`
            attribute.
        crate_features (list, optional): A list of strings to add to a crate's `rust_library::crate_features`
            attribute.
        data (list, optional): A list of labels to add to a crate's `rust_library::data` attribute.
        data_glob (list, optional): A list of glob patterns to add to a crate's `rust_library::data` attribute.
        deps (list, optional): A list of labels to add to a crate's `rust_library::deps` attribute.
        extra_aliased_targets (dict, optional): A list of targets to add to the generated aliases in the root
            crate_universe repository.
        gen_binaries (list or bool, optional): As a list, the subset of the crate's bins that should get `rust_binary`
            targets produced. Or `True` to generate all, `False` to generate none.
        disable_pipelining (bool, optional): If True, disables pipelining for library targets for this crate.
        gen_build_script (bool, optional): An authorative flag to determine whether or not to produce
            `cargo_build_script` targets for the current crate.
        patch_args (list, optional): The `patch_args` attribute of a Bazel repository rule. See
            [http_archive.patch_args](https://docs.bazel.build/versions/main/repo/http.html#http_archive-patch_args)
        patch_tool (list, optional): The `patch_tool` attribute of a Bazel repository rule. See
            [http_archive.patch_tool](https://docs.bazel.build/versions/main/repo/http.html#http_archive-patch_tool)
        patches (list, optional): The `patches` attribute of a Bazel repository rule. See
            [http_archive.patches](https://docs.bazel.build/versions/main/repo/http.html#http_archive-patches)
        proc_macro_deps (list, optional): A list of labels to add to a crate's `rust_library::proc_macro_deps`
            attribute.
        rustc_env (dict, optional): Additional variables to set on a crate's `rust_library::rustc_env` attribute.
        rustc_env_files (list, optional): A list of labels to set on a crate's `rust_library::rustc_env_files`
            attribute.
        rustc_flags (list, optional): A list of strings to set on a crate's `rust_library::rustc_flags` attribute.
        shallow_since (str, optional): An optional timestamp used for crates originating from a git repository
            instead of a crate registry. This flag optimizes fetching the source code.

    Returns:
        string: A json encoded string containing the specified version and separately all other inputs.
    """
    if additive_build_file:
        _assert_absolute(additive_build_file)
    if patches:
        for patch in patches:
            _assert_absolute(patch)

    return json.encode((
        version,
        struct(
            additive_build_file = additive_build_file,
            additive_build_file_content = additive_build_file_content,
            build_script_data = build_script_data,
            build_script_tools = build_script_tools,
            build_script_data_glob = build_script_data_glob,
            build_script_deps = build_script_deps,
            build_script_env = build_script_env,
            build_script_proc_macro_deps = build_script_proc_macro_deps,
            build_script_rustc_env = build_script_rustc_env,
            build_script_toolchains = build_script_toolchains,
            compile_data = compile_data,
            compile_data_glob = compile_data_glob,
            crate_features = crate_features,
            data = data,
            data_glob = data_glob,
            deps = deps,
            extra_aliased_targets = extra_aliased_targets,
            gen_binaries = gen_binaries,
            disable_pipelining = disable_pipelining,
            gen_build_script = gen_build_script,
            patch_args = patch_args,
            patch_tool = patch_tool,
            patches = patches,
            proc_macro_deps = proc_macro_deps,
            rustc_env = rustc_env,
            rustc_env_files = rustc_env_files,
            rustc_flags = rustc_flags,
            shallow_since = shallow_since,
        ),
    ))

crate = struct(
    spec = _spec,
    annotation = _annotation,
    workspace_member = _workspace_member,
)

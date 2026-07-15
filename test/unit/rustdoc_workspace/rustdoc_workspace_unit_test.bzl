"""Unittests to verify properties of the `rust_workspace_doc` rule and aspect"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load(
    "//rust:defs.bzl",
    "rust_binary",
    "rust_library",
    "rust_test",
    "rust_workspace_doc",
    "rust_workspace_doc_aspect",
)
load(
    "//test/unit:common.bzl",
    "assert_argv_contains",
    "assert_argv_contains_not",
    "assert_argv_contains_prefix",
)

_NIGHTLY_CONFIG_SETTINGS = {
    str(Label("//rust/toolchain/channel:channel")): "nightly",
}

def _get_action(env, mnemonic):
    """Find the single action with the given mnemonic on the target under test."""
    tut = analysistest.target_under_test(env)
    actions = [action for action in tut.actions if action.mnemonic == mnemonic]
    asserts.equals(
        env,
        1,
        len(actions),
        "Expected exactly one `{}` action, got {}".format(
            mnemonic,
            [action.mnemonic for action in tut.actions],
        ),
    )
    return actions[0]

def _count_argv(action, flag):
    return len([arg for arg in action.argv if arg == flag])

def _workspace_doc_aspect_on_lib_test_impl(ctx):
    env = analysistest.begin(ctx)
    action = _get_action(env, "RustdocMerge")

    assert_argv_contains(env, action, "--merge=none")
    assert_argv_contains(env, action, "-Zunstable-options")
    assert_argv_contains(env, action, "--parts-out-dir")

    # `wd_mid_alpha` has one documented dependency (`wd_base`), whose crate
    # directory is pre-created for cross-crate link generation.
    assert_argv_contains(env, action, "--mkdir")

    return analysistest.end(env)

_workspace_doc_aspect_on_lib_test = analysistest.make(
    _workspace_doc_aspect_on_lib_test_impl,
    config_settings = _NIGHTLY_CONFIG_SETTINGS,
    extra_target_under_test_aspects = [rust_workspace_doc_aspect],
)

def _workspace_doc_aspect_on_leaf_test_impl(ctx):
    env = analysistest.begin(ctx)
    action = _get_action(env, "RustdocMerge")

    # A crate without dependencies has no crate directories to pre-create.
    assert_argv_contains_not(env, action, "--mkdir")

    return analysistest.end(env)

_workspace_doc_aspect_on_leaf_test = analysistest.make(
    _workspace_doc_aspect_on_leaf_test_impl,
    config_settings = _NIGHTLY_CONFIG_SETTINGS,
    extra_target_under_test_aspects = [rust_workspace_doc_aspect],
)

def _workspace_doc_aspect_stable_noop_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    # On non-nightly toolchains the aspect produces no documentation actions.
    actions = [action for action in tut.actions if action.mnemonic == "RustdocMerge"]
    asserts.equals(
        env,
        0,
        len(actions),
        "Expected no `RustdocMerge` actions on a stable toolchain",
    )

    return analysistest.end(env)

_workspace_doc_aspect_stable_noop_test = analysistest.make(
    _workspace_doc_aspect_stable_noop_test_impl,
    config_settings = {
        str(Label("//rust/toolchain/channel:channel")): "stable",
    },
    extra_target_under_test_aspects = [rust_workspace_doc_aspect],
)

def _workspace_doc_finalize_test_impl(ctx):
    env = analysistest.begin(ctx)
    action = _get_action(env, "RustdocMergeFinalize")

    assert_argv_contains(env, action, "--merge=finalize")
    assert_argv_contains(env, action, "-Zunstable-options")

    # The default is to generate a root index page listing all crates.
    assert_argv_contains(env, action, "--enable-index-page")

    # The diamond dependency graph (root -> mid_alpha, mid_beta -> base)
    # contains four distinct crates (including the binary root), each
    # contributing exactly one parts directory despite `base` being reachable
    # through two paths.
    asserts.equals(
        env,
        4,
        _count_argv(action, "--include-parts-dir"),
        "Expected one `--include-parts-dir` per documented crate",
    )

    return analysistest.end(env)

_workspace_doc_finalize_test = analysistest.make(
    _workspace_doc_finalize_test_impl,
    config_settings = _NIGHTLY_CONFIG_SETTINGS,
)

def _workspace_doc_copy_test_impl(ctx):
    env = analysistest.begin(ctx)
    action = _get_action(env, "RustdocMergeCopy")

    assert_argv_contains(env, action, "--output")
    assert_argv_contains(env, action, "--inputs")

    # Four per-crate html directories (including the binary root) plus the
    # finalize directory. The action inputs additionally contain the merge
    # tool and its runfiles.
    input_dirs = [input for input in action.inputs.to_list() if input.is_directory]
    asserts.equals(
        env,
        5,
        len(input_dirs),
        "Expected the merge-copy action to consume every html directory and the finalize directory",
    )

    return analysistest.end(env)

_workspace_doc_copy_test = analysistest.make(
    _workspace_doc_copy_test_impl,
    config_settings = _NIGHTLY_CONFIG_SETTINGS,
)

def _workspace_doc_no_index_test_impl(ctx):
    env = analysistest.begin(ctx)
    action = _get_action(env, "RustdocMergeFinalize")

    assert_argv_contains_not(env, action, "--enable-index-page")

    return analysistest.end(env)

_workspace_doc_no_index_test = analysistest.make(
    _workspace_doc_no_index_test_impl,
    config_settings = _NIGHTLY_CONFIG_SETTINGS,
)

def _workspace_doc_extra_flag_test_impl(ctx):
    env = analysistest.begin(ctx)
    action = _get_action(env, "RustdocMerge")

    assert_argv_contains(env, action, "--document-private-items")

    return analysistest.end(env)

_workspace_doc_extra_flag_test = analysistest.make(
    _workspace_doc_extra_flag_test_impl,
    config_settings = _NIGHTLY_CONFIG_SETTINGS | {
        str(Label("//rust/settings:rustdoc_workspace_extra_flag")): ["--document-private-items"],
    },
    extra_target_under_test_aspects = [rust_workspace_doc_aspect],
)

def _workspace_doc_bin_collision_test_impl(ctx):
    env = analysistest.begin(ctx)
    action = _get_action(env, "RustdocMergeFinalize")

    # `wd_base_bin` produces a binary crate named `wd_base`, which collides
    # with the `wd_base` library. Like `cargo doc`, the library wins and the
    # binary is skipped, leaving the four crates of the main diamond.
    asserts.equals(
        env,
        4,
        _count_argv(action, "--include-parts-dir"),
        "Expected a binary colliding with a library crate name to be skipped",
    )

    return analysistest.end(env)

_workspace_doc_bin_collision_test = analysistest.make(
    _workspace_doc_bin_collision_test_impl,
    config_settings = _NIGHTLY_CONFIG_SETTINGS,
)

def _workspace_doc_skips_tagged_and_test_crates_test_impl(ctx):
    env = analysistest.begin(ctx)
    action = _get_action(env, "RustdocMergeFinalize")

    # The dependency graph is root (tagged `no_docs`) -> base plus a
    # `rust_test` target. Only `base` is documented, but crates reachable
    # through skipped targets are still collected.
    asserts.equals(
        env,
        1,
        _count_argv(action, "--include-parts-dir"),
        "Expected `no_docs`-tagged and test crates to be skipped",
    )

    return analysistest.end(env)

_workspace_doc_skips_tagged_and_test_crates_test = analysistest.make(
    _workspace_doc_skips_tagged_and_test_crates_test_impl,
    config_settings = _NIGHTLY_CONFIG_SETTINGS,
)

def _workspace_doc_zip_output_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    files = tut[DefaultInfo].files.to_list()
    asserts.equals(env, 1, len(files))
    asserts.true(env, files[0].is_directory, "Expected the default output to be a directory")

    output_groups = tut[OutputGroupInfo]
    zips = output_groups.rustdoc_zip.to_list()
    asserts.equals(env, 1, len(zips))
    asserts.equals(env, "zip", zips[0].extension)

    asserts.equals(
        env,
        4,
        len(output_groups.crate_docs.to_list()),
        "Expected one entry in the `crate_docs` output group per documented crate",
    )

    return analysistest.end(env)

_workspace_doc_zip_output_test = analysistest.make(
    _workspace_doc_zip_output_test_impl,
    config_settings = _NIGHTLY_CONFIG_SETTINGS,
)

def _workspace_doc_duplicate_crate_name_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "found multiple crates named")
    return analysistest.end(env)

_workspace_doc_duplicate_crate_name_test = analysistest.make(
    _workspace_doc_duplicate_crate_name_test_impl,
    config_settings = _NIGHTLY_CONFIG_SETTINGS,
    expect_failure = True,
)

def _workspace_doc_no_crates_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "found no crates to document")
    return analysistest.end(env)

_workspace_doc_no_crates_test = analysistest.make(
    _workspace_doc_no_crates_test_impl,
    config_settings = _NIGHTLY_CONFIG_SETTINGS,
    expect_failure = True,
)

def _workspace_doc_requires_nightly_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "requires a nightly Rust toolchain")
    return analysistest.end(env)

_workspace_doc_requires_nightly_test = analysistest.make(
    _workspace_doc_requires_nightly_test_impl,
    config_settings = {
        str(Label("//rust/toolchain/channel:channel")): "stable",
    },
    expect_failure = True,
)

def _define_targets():
    """Define the targets under test.

    The main dependency graph is a diamond:

    ```
              wd_root
             /       \\
      wd_mid_alpha  wd_mid_beta
             \\       /
              wd_base
    ```
    """
    rust_library(
        name = "wd_base",
        srcs = ["wd_base.rs"],
        edition = "2021",
    )

    rust_library(
        name = "wd_mid_alpha",
        srcs = ["wd_mid_alpha.rs"],
        edition = "2021",
        deps = [":wd_base"],
    )

    rust_library(
        name = "wd_mid_beta",
        srcs = ["wd_mid_beta.rs"],
        edition = "2021",
        deps = [":wd_base"],
    )

    rust_binary(
        name = "wd_root",
        srcs = ["wd_root.rs"],
        edition = "2021",
        deps = [
            ":wd_mid_alpha",
            ":wd_mid_beta",
        ],
    )

    # All `rust_workspace_doc` fixtures are tagged `manual`: they are only
    # analyzed through the analysis tests below (which force the toolchain
    # channel they need) and would fail to analyze in wildcard builds.
    rust_workspace_doc(
        name = "wd_docs",
        tags = ["manual"],
        deps = [":wd_root"],
    )

    rust_workspace_doc(
        name = "wd_docs_no_index",
        generate_index_page = False,
        tags = ["manual"],
        deps = [":wd_root"],
    )

    # Targets which are expected to be skipped by the aspect.
    rust_library(
        name = "wd_root_no_docs",
        srcs = ["wd_mid_alpha.rs"],
        crate_name = "wd_root_no_docs",
        edition = "2021",
        tags = ["no_docs"],
        deps = [":wd_base"],
    )

    rust_test(
        name = "wd_base_test",
        crate = ":wd_base",
        edition = "2021",
    )

    rust_workspace_doc(
        name = "wd_docs_with_skipped_crates",
        tags = ["manual"],
        testonly = True,
        deps = [
            ":wd_base_test",
            ":wd_root_no_docs",
        ],
    )

    # A binary crate whose name collides with the `wd_base` library.
    rust_binary(
        name = "wd_base_bin",
        srcs = ["wd_base_bin.rs"],
        crate_name = "wd_base",
        edition = "2021",
    )

    rust_workspace_doc(
        name = "wd_docs_bin_collision",
        tags = ["manual"],
        deps = [
            ":wd_base_bin",
            ":wd_root",
        ],
    )

    # Two targets producing crates with the same name.
    rust_library(
        name = "wd_duplicate_alpha",
        srcs = ["wd_base.rs"],
        crate_name = "wd_duplicate",
        edition = "2021",
    )

    rust_library(
        name = "wd_duplicate_beta",
        srcs = ["wd_mid_beta.rs"],
        crate_name = "wd_duplicate",
        edition = "2021",
        deps = [":wd_base"],
    )

    rust_workspace_doc(
        name = "wd_docs_duplicate_names",
        tags = ["manual"],
        deps = [
            ":wd_duplicate_alpha",
            ":wd_duplicate_beta",
        ],
    )

    rust_workspace_doc(
        name = "wd_docs_empty",
        tags = ["manual"],
        deps = [],
    )

def rustdoc_workspace_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the macro.
    """
    _define_targets()

    _workspace_doc_aspect_on_lib_test(
        name = "workspace_doc_aspect_on_lib_test",
        target_under_test = ":wd_mid_alpha",
    )

    _workspace_doc_aspect_on_leaf_test(
        name = "workspace_doc_aspect_on_leaf_test",
        target_under_test = ":wd_base",
    )

    _workspace_doc_aspect_stable_noop_test(
        name = "workspace_doc_aspect_stable_noop_test",
        target_under_test = ":wd_mid_alpha",
    )

    _workspace_doc_finalize_test(
        name = "workspace_doc_finalize_test",
        target_under_test = ":wd_docs",
    )

    _workspace_doc_copy_test(
        name = "workspace_doc_copy_test",
        target_under_test = ":wd_docs",
    )

    _workspace_doc_no_index_test(
        name = "workspace_doc_no_index_test",
        target_under_test = ":wd_docs_no_index",
    )

    _workspace_doc_extra_flag_test(
        name = "workspace_doc_extra_flag_test",
        target_under_test = ":wd_mid_alpha",
    )

    _workspace_doc_bin_collision_test(
        name = "workspace_doc_bin_collision_test",
        target_under_test = ":wd_docs_bin_collision",
    )

    _workspace_doc_skips_tagged_and_test_crates_test(
        name = "workspace_doc_skips_tagged_and_test_crates_test",
        target_under_test = ":wd_docs_with_skipped_crates",
    )

    _workspace_doc_zip_output_test(
        name = "workspace_doc_zip_output_test",
        target_under_test = ":wd_docs",
    )

    _workspace_doc_duplicate_crate_name_test(
        name = "workspace_doc_duplicate_crate_name_test",
        target_under_test = ":wd_docs_duplicate_names",
    )

    _workspace_doc_no_crates_test(
        name = "workspace_doc_no_crates_test",
        target_under_test = ":wd_docs_empty",
    )

    _workspace_doc_requires_nightly_test(
        name = "workspace_doc_requires_nightly_test",
        target_under_test = ":wd_docs",
    )

    native.test_suite(
        name = name,
        tests = [
            ":workspace_doc_aspect_on_leaf_test",
            ":workspace_doc_aspect_on_lib_test",
            ":workspace_doc_aspect_stable_noop_test",
            ":workspace_doc_bin_collision_test",
            ":workspace_doc_copy_test",
            ":workspace_doc_duplicate_crate_name_test",
            ":workspace_doc_extra_flag_test",
            ":workspace_doc_finalize_test",
            ":workspace_doc_no_crates_test",
            ":workspace_doc_no_index_test",
            ":workspace_doc_requires_nightly_test",
            ":workspace_doc_skips_tagged_and_test_crates_test",
            ":workspace_doc_zip_output_test",
        ],
    )

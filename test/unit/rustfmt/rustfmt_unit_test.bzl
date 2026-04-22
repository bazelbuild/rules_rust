"""Unit tests for the rustfmt aspect and rustfmt_test rule."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load(
    "//rust:defs.bzl",
    "rust_binary",
    "rust_library",
    "rust_proc_macro",
    "rust_shared_library",
    "rust_test",
    "rustfmt_aspect",
    "rustfmt_test",
)
load(
    "//test/unit:common.bzl",
    "assert_argv_contains_prefix_suffix",
)

def _find_rustfmt_action(env, actions):
    for action in actions:
        if action.mnemonic == "Rustfmt":
            return action
    asserts.true(env, False, "Expected to find a Rustfmt action")
    return None

def _rustfmt_srcs_after_check(argv):
    """Extract the source file args that follow --check in the argv."""
    srcs = []
    found_check = False
    for arg in argv:
        if found_check:
            srcs.append(arg)
        elif arg == "--check":
            found_check = True
    return srcs

def _srcs_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    action = _find_rustfmt_action(env, tut.actions)
    if not action:
        return analysistest.end(env)

    srcs = _rustfmt_srcs_after_check(action.argv)
    asserts.true(env, len(srcs) == 1, "Expected exactly 1 source, got {}".format(srcs))
    assert_argv_contains_prefix_suffix(env, action, "", "/" + ctx.attr._expected_src)

    return analysistest.end(env)

def _make_srcs_test(expected_src):
    return analysistest.make(
        _srcs_test_impl,
        extra_target_under_test_aspects = [rustfmt_aspect],
        attrs = {
            "_expected_src": attr.string(default = expected_src),
        },
    )

_lib_srcs_test = _make_srcs_test("lib.rs")
_main_srcs_test = _make_srcs_test("main.rs")

def _generated_srcs_excluded_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    action = _find_rustfmt_action(env, tut.actions)
    if not action:
        return analysistest.end(env)

    srcs = _rustfmt_srcs_after_check(action.argv)
    asserts.true(env, len(srcs) == 1, "Expected exactly 1 source (generated excluded), got {}".format(srcs))
    assert_argv_contains_prefix_suffix(env, action, "", "/" + ctx.attr._expected_src)

    for src in srcs:
        asserts.true(
            env,
            not src.endswith("/generated.rs"),
            "Generated source should not be in Rustfmt action argv, got {}".format(src),
        )

    return analysistest.end(env)

def _make_generated_srcs_excluded_test(expected_src):
    return analysistest.make(
        _generated_srcs_excluded_test_impl,
        extra_target_under_test_aspects = [rustfmt_aspect],
        attrs = {
            "_expected_src": attr.string(default = expected_src),
        },
    )

_generated_lib_srcs_excluded_test = _make_generated_srcs_excluded_test("lib.rs")
_generated_main_srcs_excluded_test = _make_generated_srcs_excluded_test("main.rs")

# ---------- rustfmt_test rule tests ----------

def _get_manifest_runfiles(tut):
    """Get .rustfmt manifest files from a target's default runfiles."""
    return [f for f in tut[DefaultInfo].default_runfiles.files.to_list() if f.extension == "rustfmt"]

def _get_source_runfiles(tut):
    """Get .rs source files from a target's default runfiles."""
    return [f for f in tut[DefaultInfo].default_runfiles.files.to_list() if f.extension == "rs"]

def _rustfmt_test_single_target_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    manifests = _get_manifest_runfiles(tut)
    asserts.equals(env, 1, len(manifests), "Expected 1 manifest in runfiles, got {}".format(
        [f.basename for f in manifests],
    ))

    rs_files = _get_source_runfiles(tut)
    basenames = [f.basename for f in rs_files]
    asserts.true(env, "lib.rs" in basenames, "Expected lib.rs in runfiles, got {}".format(basenames))

    return analysistest.end(env)

_rustfmt_test_single_target_test = analysistest.make(_rustfmt_test_single_target_test_impl)

def _rustfmt_test_multi_target_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    manifests = _get_manifest_runfiles(tut)
    asserts.equals(env, 2, len(manifests), "Expected 2 manifests in runfiles, got {}".format(
        [f.basename for f in manifests],
    ))

    return analysistest.end(env)

_rustfmt_test_multi_target_test = analysistest.make(_rustfmt_test_multi_target_test_impl)

def _rustfmt_test_norustfmt_skipped_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    rs_files = _get_source_runfiles(tut)
    asserts.equals(env, 0, len(rs_files), "Expected 0 source files for norustfmt target, got {}".format(
        [f.basename for f in rs_files],
    ))

    return analysistest.end(env)

_rustfmt_test_norustfmt_skipped_test = analysistest.make(_rustfmt_test_norustfmt_skipped_test_impl)

def _rustfmt_test_mixed_tags_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    rs_files = _get_source_runfiles(tut)
    basenames = [f.basename for f in rs_files]
    asserts.equals(env, 1, len(rs_files), "Expected 1 source file (tagged target skipped), got {}".format(basenames))
    asserts.true(env, "lib.rs" in basenames, "Expected lib.rs in runfiles, got {}".format(basenames))

    return analysistest.end(env)

_rustfmt_test_mixed_tags_test = analysistest.make(_rustfmt_test_mixed_tags_test_impl)

def _rustfmt_test_tag_variant_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    rs_files = _get_source_runfiles(tut)
    asserts.equals(env, 0, len(rs_files), "Expected 0 source files for format-skip tag variant, got {}".format(
        [f.basename for f in rs_files],
    ))

    return analysistest.end(env)

_rustfmt_test_tag_variant_test = analysistest.make(_rustfmt_test_tag_variant_test_impl)

def _define_targets():
    rust_library(
        name = "lib_target",
        srcs = ["lib.rs"],
        edition = "2021",
    )

    rust_shared_library(
        name = "shared_lib_target",
        srcs = ["lib.rs"],
        edition = "2021",
    )

    rust_proc_macro(
        name = "proc_macro_target",
        srcs = ["lib.rs"],
        edition = "2021",
    )

    rust_binary(
        name = "binary_target",
        srcs = ["main.rs"],
        edition = "2021",
    )

    rust_test(
        name = "test_target",
        srcs = ["lib.rs"],
        edition = "2021",
    )

    write_file(
        name = "gen_src",
        out = "generated.rs",
        content = [],
        newline = "unix",
    )

    rust_library(
        name = "lib_with_generated",
        srcs = ["lib.rs", ":gen_src"],
        crate_root = "lib.rs",
        edition = "2021",
    )

    rust_shared_library(
        name = "shared_lib_with_generated",
        srcs = ["lib.rs", ":gen_src"],
        crate_root = "lib.rs",
        edition = "2021",
    )

    rust_proc_macro(
        name = "proc_macro_with_generated",
        srcs = ["lib.rs", ":gen_src"],
        crate_root = "lib.rs",
        edition = "2021",
    )

    rust_binary(
        name = "binary_with_generated",
        srcs = ["main.rs", ":gen_src"],
        crate_root = "main.rs",
        edition = "2021",
    )

    rust_test(
        name = "test_with_generated",
        srcs = ["lib.rs", ":gen_src"],
        crate_root = "lib.rs",
        edition = "2021",
    )

    # --- rustfmt_test rule targets ---

    rustfmt_test(
        name = "fmt_test_single",
        targets = [":lib_target"],
    )

    rustfmt_test(
        name = "fmt_test_multi",
        targets = [":lib_target", ":binary_target"],
    )

    rust_library(
        name = "norustfmt_lib",
        srcs = ["lib.rs"],
        edition = "2021",
        tags = ["norustfmt"],
    )

    rustfmt_test(
        name = "fmt_test_norustfmt",
        targets = [":norustfmt_lib"],
    )

    rustfmt_test(
        name = "fmt_test_mixed_tags",
        targets = [":norustfmt_lib", ":lib_target"],
    )

    rust_library(
        name = "no_format_lib",
        srcs = ["lib.rs"],
        edition = "2021",
        tags = ["no-format"],
    )

    rust_library(
        name = "no_rustfmt_lib",
        srcs = ["lib.rs"],
        edition = "2021",
        tags = ["no-rustfmt"],
    )

    rust_library(
        name = "no_rustfmt_caps_lib",
        srcs = ["lib.rs"],
        edition = "2021",
        tags = ["No_Rustfmt"],
    )

    rustfmt_test(
        name = "fmt_test_no_format_tag",
        targets = [":no_format_lib"],
    )

    rustfmt_test(
        name = "fmt_test_no_rustfmt_tag",
        targets = [":no_rustfmt_lib"],
    )

    rustfmt_test(
        name = "fmt_test_no_rustfmt_caps_tag",
        targets = [":no_rustfmt_caps_lib"],
    )

def rustfmt_unit_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _define_targets()

    _lib_srcs_test(
        name = "rust_library_srcs_test",
        target_under_test = ":lib_target",
    )

    _lib_srcs_test(
        name = "rust_shared_library_srcs_test",
        target_under_test = ":shared_lib_target",
    )

    _lib_srcs_test(
        name = "rust_proc_macro_srcs_test",
        target_under_test = ":proc_macro_target",
    )

    _main_srcs_test(
        name = "rust_binary_srcs_test",
        target_under_test = ":binary_target",
    )

    _lib_srcs_test(
        name = "rust_test_srcs_test",
        target_under_test = ":test_target",
    )

    _generated_lib_srcs_excluded_test(
        name = "rust_library_generated_srcs_test",
        target_under_test = ":lib_with_generated",
    )

    _generated_lib_srcs_excluded_test(
        name = "rust_shared_library_generated_srcs_test",
        target_under_test = ":shared_lib_with_generated",
    )

    _generated_lib_srcs_excluded_test(
        name = "rust_proc_macro_generated_srcs_test",
        target_under_test = ":proc_macro_with_generated",
    )

    _generated_main_srcs_excluded_test(
        name = "rust_binary_generated_srcs_test",
        target_under_test = ":binary_with_generated",
    )

    _generated_lib_srcs_excluded_test(
        name = "rust_test_generated_srcs_test",
        target_under_test = ":test_with_generated",
    )

    # --- rustfmt_test rule tests ---

    _rustfmt_test_single_target_test(
        name = "rustfmt_test_single_target_test",
        target_under_test = ":fmt_test_single",
    )

    _rustfmt_test_multi_target_test(
        name = "rustfmt_test_multi_target_test",
        target_under_test = ":fmt_test_multi",
    )

    _rustfmt_test_norustfmt_skipped_test(
        name = "rustfmt_test_norustfmt_skipped_test",
        target_under_test = ":fmt_test_norustfmt",
    )

    _rustfmt_test_mixed_tags_test(
        name = "rustfmt_test_mixed_tags_test",
        target_under_test = ":fmt_test_mixed_tags",
    )

    _rustfmt_test_tag_variant_test(
        name = "rustfmt_test_no_format_tag_test",
        target_under_test = ":fmt_test_no_format_tag",
    )

    _rustfmt_test_tag_variant_test(
        name = "rustfmt_test_no_rustfmt_tag_test",
        target_under_test = ":fmt_test_no_rustfmt_tag",
    )

    _rustfmt_test_tag_variant_test(
        name = "rustfmt_test_no_rustfmt_caps_tag_test",
        target_under_test = ":fmt_test_no_rustfmt_caps_tag",
    )

    native.test_suite(
        name = name,
        tests = [
            ":rust_library_srcs_test",
            ":rust_shared_library_srcs_test",
            ":rust_proc_macro_srcs_test",
            ":rust_binary_srcs_test",
            ":rust_test_srcs_test",
            ":rust_library_generated_srcs_test",
            ":rust_shared_library_generated_srcs_test",
            ":rust_proc_macro_generated_srcs_test",
            ":rust_binary_generated_srcs_test",
            ":rust_test_generated_srcs_test",
            ":rustfmt_test_single_target_test",
            ":rustfmt_test_multi_target_test",
            ":rustfmt_test_norustfmt_skipped_test",
            ":rustfmt_test_mixed_tags_test",
            ":rustfmt_test_no_format_tag_test",
            ":rustfmt_test_no_rustfmt_tag_test",
            ":rustfmt_test_no_rustfmt_caps_tag_test",
        ],
    )

"""Tests that rustdoc and clippy come from their own toolchains.

`rust_toolchain` carries only what every compile action needs. `rustdoc` and
`clippy-driver` are provided by the `rustdoc_toolchain` and `clippy_toolchain`
registered alongside it, each laying out `bin/<tool>` next to the
`librustc_driver` libraries the tool loads, and they are inputs only of the
actions which run them.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:common_settings.bzl", "bool_flag")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//cargo:defs.bzl", "cargo_build_script")
load("//rust:clippy_toolchain.bzl", "clippy_toolchain")
load("//rust:defs.bzl", "rust_clippy_aspect", "rust_common", "rust_doc", "rust_library")
load("//rust:rustdoc_toolchain.bzl", "rustdoc_toolchain")
load(":sysroot_test.bzl", "symlinked_distribution_toolchains")

_RUSTDOC = ["rustdoc", "rustdoc.exe"]
_CLIPPY = ["clippy-driver", "clippy-driver.exe", "cargo-clippy", "cargo-clippy.exe"]
_CARGO = ["cargo", "cargo.exe"]

def _find_action(actions, mnemonic):
    for action in actions:
        if action.mnemonic == mnemonic:
            return action
    fail("Failed to find {} action".format(mnemonic))

def _assert_no_inputs_named(env, action, names):
    for file in action.inputs.to_list():
        asserts.false(
            env,
            file.basename in names,
            "{} action should not depend on {}".format(action.mnemonic, file.path),
        )

def _assert_single_sysroot(env, action):
    """Assert `action` depends on exactly one generated sysroot, identified by its `rust.sysroot` anchor."""
    anchors = [file.path for file in action.inputs.to_list() if file.basename == "rust.sysroot"]
    asserts.equals(env, 1, len(anchors), "{} action should depend on one sysroot, got {}".format(action.mnemonic, anchors))
    return anchors[0].removesuffix("/rust.sysroot") if len(anchors) == 1 else None

def _assert_tool_from_own_toolchain(env, action, names):
    """Assert `action` runs a tool laid out as `<toolchain>/bin/<tool>` beside its `librustc_driver`."""
    inputs = action.inputs.to_list()
    tools = [file for file in inputs if file.basename in names]
    asserts.equals(env, 1, len(tools), "Expected exactly one of {} among the inputs of {}".format(names, action.mnemonic))
    if len(tools) != 1:
        return
    tool = tools[0]

    asserts.true(env, tool.dirname.endswith("/bin"), "{} should live in a `bin` directory".format(tool.path))
    asserts.false(env, "/rust_toolchain/" in tool.path, "{} should not come from the `rust_toolchain` sysroot".format(tool.path))

    root = tool.dirname.removesuffix("/bin")
    driver_libs = [
        file
        for file in inputs
        if file.path.startswith(root + "/") and "rustc_driver" in file.basename
    ]
    asserts.true(env, bool(driver_libs), "{} should be accompanied by `librustc_driver` under {}".format(tool.path, root))

    # The tree is a complete sysroot derived from the `rust_toolchain`'s:
    # `rustc` sits beside the tool and the action runs with it as `--sysroot`.
    rustc_path = tool.dirname + "/rustc"
    asserts.true(
        env,
        any([file.path in (rustc_path, rustc_path + ".exe") for file in inputs]),
        "{} should have `rustc` beside it".format(tool.path),
    )
    asserts.true(
        env,
        any([arg.endswith("/" + root.split("/")[-1]) and arg.startswith("--sysroot=") for arg in action.argv]),
        "{} should run with its own sysroot as `--sysroot`, got {}".format(tool.path, [arg for arg in action.argv if arg.startswith("--sysroot=")]),
    )

def _rustc_excludes_companion_tools_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    action = _find_action(target.actions, "Rustc")
    _assert_no_inputs_named(env, action, _RUSTDOC + _CLIPPY + _CARGO)
    _assert_single_sysroot(env, action)
    return analysistest.end(env)

rustc_excludes_companion_tools_test = analysistest.make(
    _rustc_excludes_companion_tools_test_impl,
)

def _clippy_uses_clippy_toolchain_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    action = _find_action(target.actions, "Clippy")
    _assert_tool_from_own_toolchain(env, action, ["clippy-driver", "clippy-driver.exe"])
    _assert_no_inputs_named(env, action, _RUSTDOC)
    _assert_single_sysroot(env, action)
    return analysistest.end(env)

clippy_uses_clippy_toolchain_test = analysistest.make(
    _clippy_uses_clippy_toolchain_test_impl,
    extra_target_under_test_aspects = [rust_clippy_aspect],
)

def _rustdoc_uses_rustdoc_toolchain_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    action = _find_action(target.actions, "Rustdoc")
    _assert_tool_from_own_toolchain(env, action, _RUSTDOC)
    _assert_no_inputs_named(env, action, _CLIPPY)
    _assert_single_sysroot(env, action)
    return analysistest.end(env)

rustdoc_uses_rustdoc_toolchain_test = analysistest.make(
    _rustdoc_uses_rustdoc_toolchain_test_impl,
)

def _build_script_uses_rust_sysroot_test_impl(ctx):
    """A build script runs against the `rust_toolchain` sysroot alone and gets no `RUSTDOC`."""
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    action = _find_action(target.actions, "CargoBuildScriptRun")
    _assert_no_inputs_named(env, action, _RUSTDOC + _CLIPPY)
    sysroot = _assert_single_sysroot(env, action)
    if sysroot == None:
        return analysistest.end(env)

    asserts.true(env, "RUSTC" in action.env, "build script should get RUSTC")
    if "RUSTC" in action.env:
        asserts.true(
            env,
            action.env["RUSTC"].startswith(sysroot + "/bin/"),
            "RUSTC should name the `rustc` of the build script's sysroot {}, got {}".format(sysroot, action.env["RUSTC"]),
        )
    asserts.false(env, "RUSTDOC" in action.env, "build script should not get RUSTDOC, got {}".format(action.env.get("RUSTDOC")))
    return analysistest.end(env)

build_script_uses_rust_sysroot_test = analysistest.make(
    _build_script_uses_rust_sysroot_test_impl,
)

def _flags_from_own_toolchain_test_impl(ctx):
    """A hand-written companion registered with `--extra_toolchains` supplies its flags to the action."""
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    action = _find_action(target.actions, ctx.attr.mnemonic)
    for flag in ctx.attr.expected_flags:
        asserts.true(env, flag in action.argv, "{} should pass {}, got {}".format(ctx.attr.mnemonic, flag, action.argv))
    return analysistest.end(env)

_FLAG_TEST_ATTRS = {
    "expected_flags": attr.string_list(),
    "mnemonic": attr.string(),
}

def _toolchains_setting(names):
    return {
        "//command_line_option:extra_toolchains": [
            str(Label("//test/unit/companion_toolchains:" + name))
            for name in names
        ],
    }

# The flagged companions are bound to the symlinked distribution's
# `rust_toolchain`, so that one is registered first too.
# `:symlinked_distribution_rust` is declared by `sysroot_test_suite` in the
# same package.
rustdoc_flags_from_own_toolchain_test = analysistest.make(
    _flags_from_own_toolchain_test_impl,
    attrs = _FLAG_TEST_ATTRS,
    config_settings = _toolchains_setting(["flagged_rustdoc", "symlinked_distribution_rust"]),
)

clippy_flags_from_own_toolchain_test = analysistest.make(
    _flags_from_own_toolchain_test_impl,
    attrs = _FLAG_TEST_ATTRS,
    config_settings = _toolchains_setting(["flagged_clippy", "symlinked_distribution_rust"]),
    extra_target_under_test_aspects = [rust_clippy_aspect],
)

def _define_flagged_companions():
    """Companion toolchains with `extra_*_flags`, over the symlinked distribution's `rust_toolchain`."""
    write_file(
        name = "mock_rustdoc",
        out = "mock_rustdoc.exe",
        content = [],
        is_executable = True,
    )
    rustdoc_toolchain(
        name = "flagged_rustdoc_toolchain",
        rust_toolchain = ":symlinked_distribution_rust_toolchain",
        rustdoc = ":mock_rustdoc",
        extra_rustdoc_flags = ["--cap-lints=warn", "--sysroot-marker=$(RUST_SYSROOT)"],
        tags = ["manual"],
    )
    native.toolchain(
        name = "flagged_rustdoc",
        toolchain = ":flagged_rustdoc_toolchain",
        toolchain_type = "@rules_rust//rust/rustdoc:toolchain_type",
    )

    write_file(
        name = "mock_clippy_driver",
        out = "mock_clippy_driver.exe",
        content = [],
        is_executable = True,
    )
    clippy_toolchain(
        name = "flagged_clippy_toolchain",
        clippy_driver = ":mock_clippy_driver",
        rust_toolchain = ":symlinked_distribution_rust_toolchain",
        extra_clippy_flags = ["-Aclippy::needless_return"],
        tags = ["manual"],
    )
    native.toolchain(
        name = "flagged_clippy",
        toolchain = ":flagged_clippy_toolchain",
        toolchain_type = "@rules_rust//rust/clippy:toolchain_type",
    )

def _companion_fails_test_impl(ctx):
    """A companion toolchain which cannot be tied to a `rust_toolchain` fails to analyze."""
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, ctx.attr.expected_message)
    return analysistest.end(env)

# The targets these tests analyze fail in every configuration, so outside the
# tests they are incompatible rather than broken: `manual` keeps them out of
# wildcard builds, but `cquery` and `aquery` analyze them all the same. The
# tests flip this flag through their transition.
_NEGATIVE_TESTS_FLAG = Label("//test/unit/companion_toolchains:negative_companion_tests")

companion_fails_test = analysistest.make(
    _companion_fails_test_impl,
    attrs = {"expected_message": attr.string()},
    expect_failure = True,
    config_settings = {str(_NEGATIVE_TESTS_FLAG): True},
)

def _define_untied_companions():
    """Companions which neither name a `rust_toolchain` nor match the resolved one's release."""
    bool_flag(
        name = _NEGATIVE_TESTS_FLAG.name,
        build_setting_default = False,
    )
    native.config_setting(
        name = "negative_companion_tests_enabled",
        flag_values = {str(_NEGATIVE_TESTS_FLAG): "True"},
    )
    only_under_test = {
        "tags": ["manual"],
        "target_compatible_with": select({
            ":negative_companion_tests_enabled": [],
            "//conditions:default": ["@platforms//:incompatible"],
        }),
    }

    for tool, rule in (("rustdoc", rustdoc_toolchain), ("clippy", clippy_toolchain)):
        binary = {"clippy": ":mock_clippy_driver", "rustdoc": ":mock_rustdoc"}[tool]
        binary_attr = {"clippy": "clippy_driver", "rustdoc": "rustdoc"}[tool]

        # No `rust_toolchain` and no `version`: nothing to check the resolved
        # `rust_toolchain` against.
        rule(
            name = "untied_{}_toolchain".format(tool),
            **(only_under_test | {binary_attr: binary})
        )

        # No `rust_toolchain`, and a `version` no `rust_toolchain` has.
        rule(
            name = "other_release_{}_toolchain".format(tool),
            version = "0.0.0",
            **(only_under_test | {binary_attr: binary})
        )

        # Both a `rust_toolchain` and a release: two sources of truth.
        rule(
            name = "doubly_tied_{}_toolchain".format(tool),
            rust_toolchain = ":symlinked_distribution_rust_toolchain",
            channel = "stable",
            **(only_under_test | {binary_attr: binary})
        )

def _companion_of_another_rust_toolchain_fails_test_impl(ctx):
    """A companion derived from a `rust_toolchain` other than the resolved one is rejected.

    `rust_toolchain` alone is registered ahead of the generated toolchains, so
    the generated companions, bound to their own `rust_toolchain`, still
    resolve and would load the wrong `librustc_driver`. With no deprecated
    attribute to fall back to, analysis fails.
    """
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "derives from the `rust_toolchain` sysroot")
    asserts.expect_failure(env, "sets no `" + ctx.attr.deprecated_attribute + "` to fall back to")
    return analysistest.end(env)

_MISMATCH_TEST_ATTRS = {
    "deprecated_attribute": attr.string(),
}

clippy_of_another_rust_toolchain_fails_test = analysistest.make(
    _companion_of_another_rust_toolchain_fails_test_impl,
    attrs = _MISMATCH_TEST_ATTRS,
    expect_failure = True,
    extra_target_under_test_aspects = [rust_clippy_aspect],
    config_settings = _toolchains_setting(["symlinked_distribution_rust"]),
)

rustdoc_of_another_rust_toolchain_fails_test = analysistest.make(
    _companion_of_another_rust_toolchain_fails_test_impl,
    attrs = _MISMATCH_TEST_ATTRS,
    expect_failure = True,
    config_settings = _toolchains_setting(["symlinked_distribution_rust"]),
)

def _deprecated_attributes_fallback_test_impl(ctx):
    """A lone `rust_toolchain` with the deprecated tool attributes is used over a mismatched companion.

    The tool and the single sysroot of the action both come from that
    `rust_toolchain`, as they did before the companion toolchain types.
    """
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    action = _find_action(target.actions, ctx.attr.mnemonic)
    tools = [file for file in action.inputs.to_list() if file.basename in ctx.attr.tool_names]
    asserts.equals(env, 1, len(tools), "Expected exactly one of {} among the inputs of {}".format(ctx.attr.tool_names, ctx.attr.mnemonic))
    expected_sysroot = "/legacy_distribution_rust_toolchain/"
    for tool in tools:
        asserts.true(env, expected_sysroot in tool.path, "{} should come from the `rust_toolchain` sysroot".format(tool.path))
    sysroot = _assert_single_sysroot(env, action)
    asserts.true(env, sysroot != None and sysroot.endswith("/legacy_distribution_rust_toolchain"), "{} should run from the `rust_toolchain` sysroot, got {}".format(ctx.attr.mnemonic, sysroot))
    return analysistest.end(env)

_FALLBACK_TEST_ATTRS = {
    "mnemonic": attr.string(),
    "tool_names": attr.string_list(),
}

clippy_deprecated_attributes_fallback_test = analysistest.make(
    _deprecated_attributes_fallback_test_impl,
    attrs = _FALLBACK_TEST_ATTRS,
    extra_target_under_test_aspects = [rust_clippy_aspect],
    config_settings = _toolchains_setting(["legacy_distribution_rust"]),
)

rustdoc_deprecated_attributes_fallback_test = analysistest.make(
    _deprecated_attributes_fallback_test_impl,
    attrs = _FALLBACK_TEST_ATTRS,
    config_settings = _toolchains_setting(["legacy_distribution_rust"]),
)

_SysrootLayoutInfo = provider(
    doc = "The relative layouts of the rust sysroot and of the companions derived from it.",
    fields = ["rust", "rustdoc", "clippy"],
)

def _relative_layout(root, files):
    prefix = root + "/"
    layout = {}
    for file in files.to_list():
        if not file.path.startswith(prefix):
            fail("{} is outside its sysroot {}".format(file.path, root))
        layout[file.path[len(prefix):]] = file
    return layout

def _sysroot_layouts_impl(ctx):
    rust = ctx.toolchains[rust_common.toolchain_type]
    rustdoc = ctx.toolchains[rust_common.rustdoc_toolchain_type]
    clippy = ctx.toolchains[rust_common.clippy_toolchain_type]
    return [_SysrootLayoutInfo(
        rust = _relative_layout(rust.sysroot, rust.sysroot_files),
        rustdoc = _relative_layout(rustdoc.sysroot, rustdoc.all_files),
        clippy = _relative_layout(clippy.sysroot, clippy.all_files),
    )]

sysroot_layouts = rule(
    implementation = _sysroot_layouts_impl,
    doc = "Resolves the rust toolchain and its companions and reports the relative layout of each sysroot.",
    toolchains = [
        config_common.toolchain_type(rust_common.toolchain_type),
        config_common.toolchain_type(rust_common.rustdoc_toolchain_type),
        config_common.toolchain_type(rust_common.clippy_toolchain_type),
    ],
)

def _derived_sysroot_layout_test_impl(ctx):
    """A derived sysroot mirrors every path of the rust sysroot and adds only its own binaries."""
    env = analysistest.begin(ctx)
    info = analysistest.target_under_test(env)[_SysrootLayoutInfo]

    for name, layout, added in (("rustdoc", info.rustdoc, ["rustdoc"]), ("clippy", info.clippy, ["clippy-driver", "cargo-clippy"])):
        for relative, file in info.rust.items():
            if relative == "rust.sysroot":
                continue
            asserts.true(env, relative in layout, "{} sysroot lacks {} from the rust sysroot".format(name, relative))
            if relative in layout:
                # A mirrored entry is a symlink to the rust sysroot's own entry.
                asserts.true(env, layout[relative] != file, "{} should be a new symlink, not the rust sysroot's file".format(relative))
        for binary in added:
            asserts.true(
                env,
                any([relative in ("bin/" + binary, "bin/" + binary + ".exe") for relative in layout]),
                "{} sysroot lacks bin/{}".format(name, binary),
            )
        asserts.true(env, "rust.sysroot" in layout, "{} sysroot lacks its anchor".format(name))

        extra = [
            relative
            for relative in layout
            if relative not in info.rust and relative != "rust.sysroot" and
               not any([relative in ("bin/" + binary, "bin/" + binary + ".exe") for binary in added])
        ]
        asserts.equals(env, [], extra, "{} sysroot has entries beyond the rust sysroot and its own binaries".format(name))

        # Every entry keeps the depth of the original: `bin/` next to `lib/`,
        # the standard library under `lib/rustlib/<triple>/lib`, and the
        # compiler's own library where the loader finds it from `bin/`:
        # `lib/librustc_driver-*` on Unix, `bin/rustc_driver-*.dll` on Windows.
        asserts.true(env, any([relative.startswith("lib/rustlib/") and relative.endswith(".rlib") for relative in layout]), "{} sysroot lacks the standard library".format(name))
        asserts.true(
            env,
            any([
                "rustc_driver" in relative and relative.count("/") == 1 and relative.split("/")[0] in ("lib", "bin")
                for relative in layout
            ]),
            "{} sysroot lacks lib/librustc_driver or bin/rustc_driver.dll".format(name),
        )

    return analysistest.end(env)

derived_sysroot_layout_test = analysistest.make(_derived_sysroot_layout_test_impl)

def companion_toolchains_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): The name of the test suite.
    """
    rust_library(
        name = "lib",
        srcs = ["lib.rs"],
        crate_name = "companion_toolchains",
        edition = "2021",
    )

    rust_doc(
        name = "lib_doc",
        crate = ":lib",
    )

    rustc_excludes_companion_tools_test(
        name = "rustc_excludes_companion_tools_test",
        target_under_test = ":lib",
    )

    clippy_uses_clippy_toolchain_test(
        name = "clippy_uses_clippy_toolchain_test",
        target_under_test = ":lib",
    )

    rustdoc_uses_rustdoc_toolchain_test(
        name = "rustdoc_uses_rustdoc_toolchain_test",
        target_under_test = ":lib_doc",
    )

    cargo_build_script(
        name = "build_script",
        srcs = ["build.rs"],
        edition = "2021",
    )

    build_script_uses_rust_sysroot_test(
        name = "build_script_uses_rust_sysroot_test",
        target_under_test = ":build_script",
    )

    _define_flagged_companions()
    _define_untied_companions()

    for tool in ("rustdoc", "clippy"):
        companion_fails_test(
            name = "untied_{}_toolchain_fails_test".format(tool),
            target_under_test = ":untied_{}_toolchain".format(tool),
            expected_message = "must name the `rust_toolchain` it accompanies",
        )
        companion_fails_test(
            name = "other_release_{}_toolchain_fails_test".format(tool),
            target_under_test = ":other_release_{}_toolchain".format(tool),
            expected_message = "come from different Rust releases",
        )
        companion_fails_test(
            name = "doubly_tied_{}_toolchain_fails_test".format(tool),
            target_under_test = ":doubly_tied_{}_toolchain".format(tool),
            expected_message = "`rust_toolchain` and `channel` are exclusive",
        )

    sysroot_layouts(
        name = "sysroot_layouts",
        tags = ["manual"],
    )

    derived_sysroot_layout_test(
        name = "derived_sysroot_layout_test",
        target_under_test = ":sysroot_layouts",
    )

    rustdoc_flags_from_own_toolchain_test(
        name = "rustdoc_flags_from_own_toolchain_test",
        target_under_test = ":lib_doc",
        mnemonic = "Rustdoc",
        expected_flags = ["--cap-lints=warn"],
    )

    clippy_flags_from_own_toolchain_test(
        name = "clippy_flags_from_own_toolchain_test",
        target_under_test = ":lib",
        mnemonic = "Clippy",
        expected_flags = ["-Aclippy::needless_return"],
    )

    # A `rust_toolchain` registered on its own, ahead of the generated
    # toolchains and their companions. `:symlinked_distribution_rust` is
    # declared by `sysroot_test_suite` in the same package.
    symlinked_distribution_toolchains("legacy_distribution", deprecated_tool_attributes = True)

    clippy_of_another_rust_toolchain_fails_test(
        name = "clippy_of_another_rust_toolchain_fails_test",
        target_under_test = ":lib",
        deprecated_attribute = "clippy_driver",
    )

    rustdoc_of_another_rust_toolchain_fails_test(
        name = "rustdoc_of_another_rust_toolchain_fails_test",
        target_under_test = ":lib_doc",
        deprecated_attribute = "rust_doc",
    )

    clippy_deprecated_attributes_fallback_test(
        name = "clippy_deprecated_attributes_fallback_test",
        target_under_test = ":lib",
        mnemonic = "Clippy",
        tool_names = ["clippy-driver", "clippy-driver.exe"],
    )

    rustdoc_deprecated_attributes_fallback_test(
        name = "rustdoc_deprecated_attributes_fallback_test",
        target_under_test = ":lib_doc",
        mnemonic = "Rustdoc",
        tool_names = _RUSTDOC,
    )

    native.test_suite(
        name = name,
        tests = [
            ":rustc_excludes_companion_tools_test",
            ":clippy_uses_clippy_toolchain_test",
            ":rustdoc_uses_rustdoc_toolchain_test",
            ":build_script_uses_rust_sysroot_test",
            ":rustdoc_flags_from_own_toolchain_test",
            ":clippy_flags_from_own_toolchain_test",
            ":derived_sysroot_layout_test",
            ":clippy_of_another_rust_toolchain_fails_test",
            ":rustdoc_of_another_rust_toolchain_fails_test",
            ":clippy_deprecated_attributes_fallback_test",
            ":rustdoc_deprecated_attributes_fallback_test",
            ":untied_rustdoc_toolchain_fails_test",
            ":untied_clippy_toolchain_fails_test",
            ":other_release_rustdoc_toolchain_fails_test",
            ":other_release_clippy_toolchain_fails_test",
            ":doubly_tied_rustdoc_toolchain_fails_test",
            ":doubly_tied_clippy_toolchain_fails_test",
        ],
    )

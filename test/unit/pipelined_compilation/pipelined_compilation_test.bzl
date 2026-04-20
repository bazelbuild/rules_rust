"""Unittests for rust rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_proc_macro")
load(
    "//test/unit:common.bzl",
    "assert_argv_contains",
    "assert_list_contains_adjacent_elements",
    "assert_list_contains_adjacent_elements_not",
)
load(":wrap.bzl", "wrap")

def _config(use_no_codegen):
    return {
        str(Label("//rust/settings:pipelined_compilation")): True,
        str(Label("//rust/settings:incompatible_use_unstable_no_codegen_for_pipelining")): use_no_codegen,
    }

_VARIANTS = {
    "new": struct(
        suffix = "_new",
        metadata_suffix = "_meta.rlib",
        use_no_codegen = True,
    ),
    "legacy": struct(
        suffix = "_legacy",
        metadata_suffix = ".rmeta",
        use_no_codegen = False,
    ),
}

_VARIANT_ATTRS = {"variant": attr.string()}
_CUSTOM_RULE_ATTRS = {
    "generate_metadata": attr.bool(),
    "variant": attr.string(),
}
_GUARDRAIL_ATTRS = {
    "expected_bootstrap": attr.string(default = ""),
    "expected_user_allow_features": attr.string(default = ""),
    "expect_injected_allow_features": attr.bool(default = False),
    "variant": attr.string(),
}

# TODO: Fix pipeline compilation on windows
# https://github.com/bazelbuild/rules_rust/issues/3383
_NO_WINDOWS = select({
    "@platforms//os:windows": ["@platforms//:incompatible"],
    "//conditions:default": [],
})

def _variant(ctx):
    return _VARIANTS[ctx.attr.variant]

def _action(tut, mnemonic):
    return [act for act in tut.actions if act.mnemonic == mnemonic][0]

def _is_metadata_file(variant, path):
    return path.endswith(variant.metadata_suffix)

def _is_full_rlib(variant, path):
    return path.endswith(".rlib") and not _is_metadata_file(variant, path)

def _crate_inputs(action, crate_basename_prefix):
    return [f for f in action.inputs.to_list() if f.basename.startswith(crate_basename_prefix)]

def _crate_externs(action, crate_name):
    return [arg for arg in action.argv if arg.startswith("--extern=%s=" % crate_name)]

def _has_input(action, crate_name, variant, metadata):
    for file in action.inputs.to_list():
        if crate_name not in file.path:
            continue
        if metadata and _is_metadata_file(variant, file.path):
            return True
        if not metadata and _is_full_rlib(variant, file.path):
            return True
    return False

def _has_metadata_input(action, crate_name, variant):
    return _has_input(action, crate_name, variant, True)

def _has_full_rlib_input(action, crate_name, variant):
    return _has_input(action, crate_name, variant, False)

def _second_lib_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    variant = _variant(ctx)
    rlib_action = _action(tut, "Rustc")
    metadata_action = _action(tut, "RustcMetadata")

    if variant.use_no_codegen:
        assert_argv_contains(env, rlib_action, "--emit=link")
        metadata_emit = [arg for arg in metadata_action.argv if arg.startswith("--emit=link=")]
        asserts.true(
            env,
            len(metadata_emit) == 1,
            "expected RustcMetadata to have --emit=link=<path>, got " + str(metadata_emit),
        )
        assert_argv_contains(env, metadata_action, "-Zno-codegen")
    else:
        assert_argv_contains(env, rlib_action, "--emit=dep-info,link,metadata")
        assert_argv_contains(env, metadata_action, "--emit=dep-info,link,metadata")
        assert_list_contains_adjacent_elements_not(env, rlib_action.argv, ["--rustc-quit-on-rmeta", "true"])
        assert_list_contains_adjacent_elements(env, metadata_action.argv, ["--rustc-quit-on-rmeta", "true"])

    asserts.true(
        env,
        _is_full_rlib(variant, rlib_action.outputs.to_list()[0].path),
        "expected Rustc to output a full .rlib, got " + rlib_action.outputs.to_list()[0].path,
    )
    asserts.true(
        env,
        _is_metadata_file(variant, metadata_action.outputs.to_list()[0].path),
        "expected RustcMetadata to output " + variant.metadata_suffix + ", got " + metadata_action.outputs.to_list()[0].path,
    )

    for action in [metadata_action, rlib_action]:
        externs = _crate_externs(action, "first")
        asserts.equals(env, 1, len(externs), "expected one --extern=first=... in " + action.mnemonic)
        asserts.true(
            env,
            externs[0].endswith(variant.metadata_suffix),
            "expected --extern=first to use " + variant.metadata_suffix + ", got " + externs[0],
        )

        crate_inputs = _crate_inputs(action, "libfirst")
        asserts.equals(env, 1, len(crate_inputs), "expected one libfirst input in " + action.mnemonic)
        asserts.true(
            env,
            _is_metadata_file(variant, crate_inputs[0].path),
            "expected libfirst input to use " + variant.metadata_suffix + ", got " + crate_inputs[0].path,
        )

    return analysistest.end(env)

def _bin_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    variant = _variant(ctx)
    bin_action = _action(tut, "Rustc")

    metadata_inputs = [
        i.path
        for i in bin_action.inputs.to_list()
        if _is_metadata_file(variant, i.path) and "/lib/rustlib" not in i.path
    ]
    asserts.false(
        env,
        metadata_inputs,
        "expected no metadata inputs, found " + json.encode_indent(metadata_inputs, indent = " " * 4),
    )

    return analysistest.end(env)

def _guardrail_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    rlib_action = _action(tut, "Rustc")
    metadata_action = _action(tut, "RustcMetadata")
    expected_bootstrap = ctx.attr.expected_bootstrap or None

    for action in (metadata_action, rlib_action):
        asserts.equals(
            env,
            expected_bootstrap,
            action.env.get("RUSTC_BOOTSTRAP"),
            "expected RUSTC_BOOTSTRAP=" + repr(expected_bootstrap) + " in " + action.mnemonic + ", got " + repr(action.env.get("RUSTC_BOOTSTRAP")),
        )
        has_our_flag = "-Zallow-features=" in action.argv
        if ctx.attr.expect_injected_allow_features:
            asserts.true(
                env,
                has_our_flag,
                "expected injected -Zallow-features= in " + action.mnemonic,
            )
        else:
            asserts.false(
                env,
                has_our_flag,
                "expected no injected -Zallow-features= in " + action.mnemonic,
            )
        if ctx.attr.expected_user_allow_features:
            asserts.true(
                env,
                ctx.attr.expected_user_allow_features in action.argv,
                "expected user's " + ctx.attr.expected_user_allow_features + " in " + action.mnemonic,
            )

    return analysistest.end(env)

def _rmeta_is_propagated_through_custom_rule_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    variant = _variant(ctx)
    rust_action = _action(tut, "RustcMetadata")

    seen_wrapper_metadata = _has_metadata_input(rust_action, "libwrapper", variant)
    seen_wrapper_rlib = _has_full_rlib_input(rust_action, "libwrapper", variant)
    seen_to_wrap_metadata = _has_metadata_input(rust_action, "libto_wrap", variant)
    seen_to_wrap_rlib = _has_full_rlib_input(rust_action, "libto_wrap", variant)

    if ctx.attr.generate_metadata:
        asserts.true(env, seen_wrapper_metadata, "expected dependency on metadata for 'wrapper' but not found")
        asserts.false(env, seen_wrapper_rlib, "expected no dependency on object for 'wrapper' but it was found")
    else:
        asserts.true(env, seen_wrapper_rlib, "expected dependency on object for 'wrapper' but not found")
        asserts.false(env, seen_wrapper_metadata, "expected no dependency on metadata for 'wrapper' but it was found")

    asserts.true(env, seen_to_wrap_metadata, "expected dependency on metadata for 'to_wrap' but not found")
    asserts.false(env, seen_to_wrap_rlib, "expected no dependency on object for 'to_wrap' but it was found")

    return analysistest.end(env)

def _rmeta_is_used_when_building_custom_rule_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    variant = _variant(ctx)
    rust_action = _action(tut, "Rustc")

    seen_to_wrap_metadata = _has_metadata_input(rust_action, "libto_wrap", variant)
    seen_to_wrap_rlib = _has_full_rlib_input(rust_action, "libto_wrap", variant)

    asserts.true(env, seen_to_wrap_metadata, "expected dependency on metadata for 'to_wrap' but not found")
    asserts.false(env, seen_to_wrap_rlib, "expected no dependency on object for 'to_wrap' but it was found")

    return analysistest.end(env)

def _rmeta_not_produced_if_pipelining_disabled_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    rust_action = [act for act in tut.actions if act.mnemonic == "RustcMetadata"]
    asserts.true(env, len(rust_action) == 0, "expected no metadata to be produced, but found a metadata action")

    return analysistest.end(env)

second_lib_new_test = analysistest.make(
    _second_lib_test_impl,
    attrs = _VARIANT_ATTRS,
    config_settings = _config(True),
)
second_lib_legacy_test = analysistest.make(
    _second_lib_test_impl,
    attrs = _VARIANT_ATTRS,
    config_settings = _config(False),
)

bin_new_test = analysistest.make(
    _bin_test_impl,
    attrs = _VARIANT_ATTRS,
    config_settings = _config(True),
)
bin_legacy_test = analysistest.make(
    _bin_test_impl,
    attrs = _VARIANT_ATTRS,
    config_settings = _config(False),
)

def _make_guardrail_test(config_settings):
    return analysistest.make(
        _guardrail_test_impl,
        attrs = _GUARDRAIL_ATTRS,
        config_settings = config_settings,
    )

guardrail_test = _make_guardrail_test(_config(True))

_GLOBAL_ENV_CONFIG = dict(_config(True))
_GLOBAL_ENV_CONFIG[str(Label("//rust/settings:extra_rustc_env"))] = ["RUSTC_BOOTSTRAP=global-value"]

guardrail_global_env_optout_test = _make_guardrail_test(_GLOBAL_ENV_CONFIG)

_GLOBAL_FLAG_CONFIG = dict(_config(True))
_GLOBAL_FLAG_CONFIG[str(Label("//rust/settings:extra_rustc_flag"))] = ["-Zallow-features=let_chains"]

guardrail_global_flag_optout_test = _make_guardrail_test(_GLOBAL_FLAG_CONFIG)

rmeta_is_propagated_through_custom_rule_new_test = analysistest.make(
    _rmeta_is_propagated_through_custom_rule_test_impl,
    attrs = _CUSTOM_RULE_ATTRS,
    config_settings = _config(True),
)
rmeta_is_propagated_through_custom_rule_legacy_test = analysistest.make(
    _rmeta_is_propagated_through_custom_rule_test_impl,
    attrs = _CUSTOM_RULE_ATTRS,
    config_settings = _config(False),
)

rmeta_is_used_when_building_custom_rule_new_test = analysistest.make(
    _rmeta_is_used_when_building_custom_rule_test_impl,
    attrs = _CUSTOM_RULE_ATTRS,
    config_settings = _config(True),
)
rmeta_is_used_when_building_custom_rule_legacy_test = analysistest.make(
    _rmeta_is_used_when_building_custom_rule_test_impl,
    attrs = _CUSTOM_RULE_ATTRS,
    config_settings = _config(False),
)

rmeta_not_produced_if_pipelining_disabled_test = analysistest.make(
    _rmeta_not_produced_if_pipelining_disabled_test_impl,
    config_settings = {
        str(Label("//rust/settings:pipelined_compilation")): True,
    },
)

_TESTS = {
    "new": struct(
        second_lib = second_lib_new_test,
        bin = bin_new_test,
        rmeta_propagated = rmeta_is_propagated_through_custom_rule_new_test,
        rmeta_used = rmeta_is_used_when_building_custom_rule_new_test,
    ),
    "legacy": struct(
        second_lib = second_lib_legacy_test,
        bin = bin_legacy_test,
        rmeta_propagated = rmeta_is_propagated_through_custom_rule_legacy_test,
        rmeta_used = rmeta_is_used_when_building_custom_rule_legacy_test,
    ),
}

def _pipelined_compilation_test(variant_name):
    variant = _VARIANTS[variant_name]
    tests = _TESTS[variant_name]

    rust_proc_macro(
        name = "my_macro" + variant.suffix,
        crate_name = "my_macro",
        edition = "2021",
        srcs = ["my_macro.rs"],
    )

    rust_library(
        name = "first" + variant.suffix,
        crate_name = "first",
        edition = "2021",
        srcs = ["first.rs"],
    )

    rust_library(
        name = "second" + variant.suffix,
        crate_name = "second",
        edition = "2021",
        srcs = ["second.rs"],
        deps = [":first" + variant.suffix],
        proc_macro_deps = [":my_macro" + variant.suffix],
    )

    rust_binary(
        name = "bin" + variant.suffix,
        edition = "2021",
        srcs = ["bin.rs"],
        deps = [":second" + variant.suffix],
    )

    tests.second_lib(
        name = "second_lib_test" + variant.suffix,
        target_under_test = ":second" + variant.suffix,
        target_compatible_with = _NO_WINDOWS,
        variant = variant_name,
    )
    tests.bin(
        name = "bin_test" + variant.suffix,
        target_under_test = ":bin" + variant.suffix,
        target_compatible_with = _NO_WINDOWS,
        variant = variant_name,
    )

    if variant_name == "new":
        # On nightly toolchains, rustc.bzl skips the RUSTC_BOOTSTRAP/-Zallow-features
        # injection (unstable features are already allowed), so the baseline assertions
        # flip per-channel. See `inject_allow_features_guardrail` in rust/private/rustc.bzl.
        guardrail_test(
            name = "guardrail_baseline_test" + variant.suffix,
            target_under_test = ":second" + variant.suffix,
            target_compatible_with = _NO_WINDOWS,
            expect_injected_allow_features = select({
                "@rules_rust//rust/toolchain/channel:nightly": False,
                "//conditions:default": True,
            }),
            expected_bootstrap = select({
                "@rules_rust//rust/toolchain/channel:nightly": "",
                "//conditions:default": "1",
            }),
            variant = variant_name,
        )

        rust_library(
            name = "user_env_optout" + variant.suffix,
            crate_name = "user_env_optout",
            edition = "2021",
            srcs = ["first.rs"],
            rustc_env = {"RUSTC_BOOTSTRAP": "user-value"},
        )
        guardrail_test(
            name = "guardrail_user_env_optout_test" + variant.suffix,
            target_under_test = ":user_env_optout" + variant.suffix,
            target_compatible_with = _NO_WINDOWS,
            expected_bootstrap = "user-value",
            variant = variant_name,
        )

        # tags=["manual"] prevents `:all` from trying to compile this target
        # end-to-end: the `-Z` flag would make rustc fail on stable without
        # RUSTC_BOOTSTRAP=1, but the analysistest only needs the analysis
        # phase (declared actions), which succeeds regardless.
        rust_library(
            name = "user_flag_optout" + variant.suffix,
            crate_name = "user_flag_optout",
            edition = "2021",
            srcs = ["first.rs"],
            rustc_flags = ["-Zallow-features=let_chains"],
            tags = ["manual"],
        )
        guardrail_test(
            name = "guardrail_user_flag_optout_test" + variant.suffix,
            target_under_test = ":user_flag_optout" + variant.suffix,
            target_compatible_with = _NO_WINDOWS,
            expected_user_allow_features = "-Zallow-features=let_chains",
            variant = variant_name,
        )

        # See note above on user_flag_optout for why tags=["manual"] is used.
        rust_library(
            name = "space_form_optout" + variant.suffix,
            crate_name = "space_form_optout",
            edition = "2021",
            srcs = ["first.rs"],
            rustc_flags = ["-Z", "allow-features=let_chains"],
            tags = ["manual"],
        )
        guardrail_test(
            name = "guardrail_space_form_optout_test" + variant.suffix,
            target_under_test = ":space_form_optout" + variant.suffix,
            target_compatible_with = _NO_WINDOWS,
            variant = variant_name,
        )

        # Global env/flag escape hatches reuse the baseline target but run with
        # a different config_settings dict (set inside the analysistest factory).
        guardrail_global_env_optout_test(
            name = "guardrail_global_env_optout_test" + variant.suffix,
            target_under_test = ":second" + variant.suffix,
            target_compatible_with = _NO_WINDOWS,
            expected_bootstrap = "global-value",
            variant = variant_name,
        )

        guardrail_global_flag_optout_test(
            name = "guardrail_global_flag_optout_test" + variant.suffix,
            target_under_test = ":second" + variant.suffix,
            target_compatible_with = _NO_WINDOWS,
            variant = variant_name,
        )

    labels = [
        ":second_lib_test" + variant.suffix,
        ":bin_test" + variant.suffix,
    ]
    if variant_name == "new":
        labels.append(":guardrail_baseline_test" + variant.suffix)
        labels.append(":guardrail_user_env_optout_test" + variant.suffix)
        labels.append(":guardrail_user_flag_optout_test" + variant.suffix)
        labels.append(":guardrail_space_form_optout_test" + variant.suffix)
        labels.append(":guardrail_global_env_optout_test" + variant.suffix)
        labels.append(":guardrail_global_flag_optout_test" + variant.suffix)
    return labels

def _disable_pipelining_test():
    rust_library(
        name = "lib_disable_pipelining",
        crate_name = "lib",
        srcs = ["custom_rule_test/to_wrap.rs"],
        edition = "2021",
        disable_pipelining = True,
    )
    rmeta_not_produced_if_pipelining_disabled_test(
        name = "rmeta_not_produced_if_pipelining_disabled_test",
        target_under_test = ":lib_disable_pipelining",
    )

    return [":rmeta_not_produced_if_pipelining_disabled_test"]

def _custom_rule_test(generate_metadata, variant_name):
    variant = _VARIANTS[variant_name]
    tests = _TESTS[variant_name]
    suffix = ("_with_metadata" if generate_metadata else "_without_metadata") + variant.suffix

    rust_library(
        name = "to_wrap" + suffix,
        crate_name = "to_wrap",
        srcs = ["custom_rule_test/to_wrap.rs"],
        edition = "2021",
    )
    wrap(
        name = "wrapper" + suffix,
        crate_name = "wrapper",
        target = ":to_wrap" + suffix,
        generate_metadata = generate_metadata,
    )
    rust_library(
        name = "uses_wrapper" + suffix,
        srcs = ["custom_rule_test/uses_wrapper.rs"],
        deps = [":wrapper" + suffix],
        edition = "2021",
    )

    tests.rmeta_propagated(
        name = "rmeta_is_propagated_through_custom_rule_test" + suffix,
        generate_metadata = generate_metadata,
        target_under_test = ":uses_wrapper" + suffix,
        target_compatible_with = _NO_WINDOWS,
        variant = variant_name,
    )
    tests.rmeta_used(
        name = "rmeta_is_used_when_building_custom_rule_test" + suffix,
        generate_metadata = generate_metadata,
        target_under_test = ":wrapper" + suffix,
        target_compatible_with = _NO_WINDOWS,
        variant = variant_name,
    )

    return [
        ":rmeta_is_propagated_through_custom_rule_test" + suffix,
        ":rmeta_is_used_when_building_custom_rule_test" + suffix,
    ]

def pipelined_compilation_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    tests = []

    for variant_name in _VARIANTS:
        tests.extend(_pipelined_compilation_test(variant_name))
        tests.extend(_custom_rule_test(True, variant_name))
        tests.extend(_custom_rule_test(False, variant_name))

    tests.extend(_disable_pipelining_test())

    native.test_suite(
        name = name,
        tests = tests,
    )

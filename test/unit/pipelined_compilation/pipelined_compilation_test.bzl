"""Unittests for rust rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_proc_macro")
load("//test/unit:common.bzl", "assert_argv_contains")
load(":wrap.bzl", "wrap")

ENABLE_PIPELINING = {
    str(Label("//rust/settings:pipelined_compilation")): True,
}

# TODO: Fix pipeline compilation on windows
# https://github.com/bazelbuild/rules_rust/issues/3383
_NO_WINDOWS = select({
    "@platforms//os:windows": ["@platforms//:incompatible"],
    "//conditions:default": [],
})

def _second_lib_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    rlib_action = [act for act in tut.actions if act.mnemonic == "Rustc"][0]
    metadata_action = [act for act in tut.actions if act.mnemonic == "RustcMetadata"][0]

    # The full action emits link; the metadata action emits only
    # link with an explicit path (--emit=link=<path>) and uses -Zno-codegen to
    # produce a hollow rlib (metadata-full).
    assert_argv_contains(env, rlib_action, "--emit=link")

    # RustcMetadata uses --emit=link=<path> to redirect the hollow rlib to the
    # declared .rmeta output. Check that it contains the flag with a path.
    metadata_emit = [arg for arg in metadata_action.argv if arg.startswith("--emit=link=")]
    asserts.true(
        env,
        len(metadata_emit) == 1,
        "expected RustcMetadata to have --emit=link=<path>, got " + str(metadata_emit),
    )

    # RustcMetadata must use -Zno-codegen to produce a hollow rlib
    assert_argv_contains(env, metadata_action, "-Zno-codegen")

    # The metadata action outputs a hollow .rlib (_meta.rlib), the full action a normal .rlib
    path = rlib_action.outputs.to_list()[0].path
    asserts.true(
        env,
        path.endswith(".rlib") and not path.endswith("_meta.rlib"),
        "expected Rustc to output .rlib (not _meta.rlib), got " + path,
    )
    path = metadata_action.outputs.to_list()[0].path
    asserts.true(
        env,
        path.endswith("_meta.rlib"),
        "expected RustcMetadata to output _meta.rlib, got " + path,
    )

    # Both actions should refer to the metadata artifact of :first.
    extern_metadata = [arg for arg in metadata_action.argv if arg.startswith("--extern=first=") and "libfirst" in arg and arg.endswith("_meta.rlib")]
    asserts.true(
        env,
        len(extern_metadata) == 1,
        "expected RustcMetadata --extern=first=*_meta.rlib, got " + str([a for a in metadata_action.argv if "--extern=first=" in a]),
    )
    extern_rlib = [arg for arg in rlib_action.argv if arg.startswith("--extern=first=") and "libfirst" in arg and arg.endswith("_meta.rlib")]
    asserts.true(
        env,
        len(extern_rlib) == 1,
        "expected Rustc --extern=first=*_meta.rlib, got " + str([a for a in rlib_action.argv if "--extern=first=" in a]),
    )

    # Both actions should take the metadata artifact as input.
    input_metadata = [i for i in metadata_action.inputs.to_list() if i.basename.startswith("libfirst") and i.basename.endswith("_meta.rlib")]
    asserts.true(env, len(input_metadata) == 1, "expected one libfirst _meta.rlib input to RustcMetadata, found " + str([i.path for i in metadata_action.inputs.to_list() if i.basename.startswith("libfirst")]))
    input_rlib = [i for i in rlib_action.inputs.to_list() if i.basename.startswith("libfirst") and i.basename.endswith("_meta.rlib")]
    asserts.true(env, len(input_rlib) == 1, "expected one libfirst _meta.rlib input to Rustc, found " + str([i.path for i in rlib_action.inputs.to_list() if i.basename.startswith("libfirst")]))

    return analysistest.end(env)

def _bin_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    bin_action = [act for act in tut.actions if act.mnemonic == "Rustc"][0]

    # Check that no inputs to this binary are hollow rlib (_meta.rlib) files.
    metadata_inputs = [i.path for i in bin_action.inputs.to_list() if i.path.endswith("_meta.rlib")]

    # Filter out toolchain targets. This test intends to only check for metadata files of `deps`.
    metadata_inputs = [i for i in metadata_inputs if "/lib/rustlib" not in i]

    asserts.false(env, metadata_inputs, "expected no metadata inputs, found " + json.encode_indent(metadata_inputs, indent = " " * 4))

    return analysistest.end(env)

bin_test = analysistest.make(_bin_test_impl, config_settings = ENABLE_PIPELINING)
second_lib_test = analysistest.make(_second_lib_test_impl, config_settings = ENABLE_PIPELINING)

def _pipelined_compilation_test():
    rust_proc_macro(
        name = "my_macro",
        edition = "2021",
        srcs = ["my_macro.rs"],
    )

    rust_library(
        name = "first",
        edition = "2021",
        srcs = ["first.rs"],
    )

    rust_library(
        name = "second",
        edition = "2021",
        srcs = ["second.rs"],
        deps = [":first"],
        proc_macro_deps = [":my_macro"],
    )

    rust_binary(
        name = "bin",
        edition = "2021",
        srcs = ["bin.rs"],
        deps = [":second"],
    )

    second_lib_test(
        name = "second_lib_test",
        target_under_test = ":second",
        target_compatible_with = _NO_WINDOWS,
    )
    bin_test(
        name = "bin_test",
        target_under_test = ":bin",
        target_compatible_with = _NO_WINDOWS,
    )

    return [
        ":second_lib_test",
        ":bin_test",
    ]

def _is_metadata_file(path):
    """Returns True if the path is a hollow rlib (metadata-full) file."""
    return path.endswith("_meta.rlib")

def _is_full_rlib(path):
    """Returns True if the path is a full rlib (not a hollow rlib)."""
    return path.endswith(".rlib") and not path.endswith("_meta.rlib")

def _rmeta_is_propagated_through_custom_rule_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    # This is the metadata-generating action. It should depend on metadata for the library and, if generate_metadata is set
    # also depend on metadata for 'wrapper'.
    rust_action = [act for act in tut.actions if act.mnemonic == "RustcMetadata"][0]

    seen_wrapper_metadata = False
    seen_to_wrap_metadata = False
    seen_wrapper_rlib = False
    seen_to_wrap_rlib = False
    for i in rust_action.inputs.to_list():
        if "libwrapper" in i.path:
            if _is_metadata_file(i.path):
                seen_wrapper_metadata = True
            elif _is_full_rlib(i.path):
                seen_wrapper_rlib = True
        if "libto_wrap" in i.path:
            if _is_metadata_file(i.path):
                seen_to_wrap_metadata = True
            elif _is_full_rlib(i.path):
                seen_to_wrap_rlib = True

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

    # This is the custom rule invocation of rustc.
    rust_action = [act for act in tut.actions if act.mnemonic == "Rustc"][0]

    # The custom rule invocation should depend on metadata, regardless of whether
    # the wrapper itself generates metadata.
    seen_to_wrap_rlib = False
    seen_to_wrap_metadata = False
    for act in rust_action.inputs.to_list():
        if "libto_wrap" in act.path and _is_full_rlib(act.path):
            seen_to_wrap_rlib = True
        elif "libto_wrap" in act.path and _is_metadata_file(act.path):
            seen_to_wrap_metadata = True

    asserts.true(env, seen_to_wrap_metadata, "expected dependency on metadata for 'to_wrap' but not found")
    asserts.false(env, seen_to_wrap_rlib, "expected no dependency on object for 'to_wrap' but it was found")

    return analysistest.end(env)

rmeta_is_propagated_through_custom_rule_test = analysistest.make(_rmeta_is_propagated_through_custom_rule_test_impl, attrs = {"generate_metadata": attr.bool()}, config_settings = ENABLE_PIPELINING)
rmeta_is_used_when_building_custom_rule_test = analysistest.make(_rmeta_is_used_when_building_custom_rule_test_impl, attrs = {"generate_metadata": attr.bool()}, config_settings = ENABLE_PIPELINING)

def _rmeta_not_produced_if_pipelining_disabled_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    rust_action = [act for act in tut.actions if act.mnemonic == "RustcMetadata"]
    asserts.true(env, len(rust_action) == 0, "expected no metadata to be produced, but found a metadata action")

    return analysistest.end(env)

rmeta_not_produced_if_pipelining_disabled_test = analysistest.make(_rmeta_not_produced_if_pipelining_disabled_test_impl, config_settings = ENABLE_PIPELINING)

def _disable_pipelining_test():
    rust_library(
        name = "lib",
        srcs = ["custom_rule_test/to_wrap.rs"],
        edition = "2021",
        disable_pipelining = True,
    )
    rmeta_not_produced_if_pipelining_disabled_test(
        name = "rmeta_not_produced_if_pipelining_disabled_test",
        target_under_test = ":lib",
    )

    return [
        ":rmeta_not_produced_if_pipelining_disabled_test",
    ]

def _custom_rule_test(generate_metadata, suffix):
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

    rmeta_is_propagated_through_custom_rule_test(
        name = "rmeta_is_propagated_through_custom_rule_test" + suffix,
        generate_metadata = generate_metadata,
        target_under_test = ":uses_wrapper" + suffix,
        target_compatible_with = _NO_WINDOWS,
    )

    rmeta_is_used_when_building_custom_rule_test(
        name = "rmeta_is_used_when_building_custom_rule_test" + suffix,
        generate_metadata = generate_metadata,
        target_under_test = ":wrapper" + suffix,
        target_compatible_with = _NO_WINDOWS,
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
    tests.extend(_pipelined_compilation_test())
    tests.extend(_disable_pipelining_test())
    tests.extend(_custom_rule_test(generate_metadata = True, suffix = "_with_metadata"))
    tests.extend(_custom_rule_test(generate_metadata = False, suffix = "_without_metadata"))

    native.test_suite(
        name = name,
        tests = tests,
    )

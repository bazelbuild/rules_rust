"""Unittests for rust rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_proc_macro", "rust_test")
load("//test/unit:common.bzl", "assert_argv_contains", "assert_list_contains_adjacent_elements_not")
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

    # Hollow rlib approach: Rustc action uses --emit=dep-info,link (no metadata).
    assert_argv_contains(env, rlib_action, "--emit=dep-info,link")

    # Metadata action uses --emit=link=<path>-hollow.rlib (hollow rlib, .rlib extension).
    # The .rlib extension is required so rustc reads it as an rlib archive (extracting
    # lib.rmeta with optimized MIR). Using .rmeta extension causes E0786, and using
    # --emit=metadata produces raw .rmeta without optimized MIR (causes "missing
    # optimized MIR" errors on Rust 1.85+).
    metadata_emit_link = [arg for arg in metadata_action.argv if arg.startswith("--emit=link=") and arg.endswith("-hollow.rlib")]
    asserts.true(
        env,
        len(metadata_emit_link) == 1,
        "expected --emit=link=*-hollow.rlib for hollow rlib, got: " + str([arg for arg in metadata_action.argv if arg.startswith("--emit=")]),
    )

    # The rlib action produces a .rlib; the metadata action produces a -hollow.rlib.
    path = rlib_action.outputs.to_list()[0].path
    asserts.true(
        env,
        path.endswith(".rlib") and not path.endswith("-hollow.rlib"),
        "expected Rustc to output .rlib (not hollow), got " + path,
    )
    path = metadata_action.outputs.to_list()[0].path
    asserts.true(
        env,
        path.endswith("-hollow.rlib"),
        "expected RustcMetadata to output -hollow.rlib, got " + path,
    )

    # Neither action should use --rustc-quit-on-rmeta (hollow rlib exits naturally).
    assert_list_contains_adjacent_elements_not(env, rlib_action.argv, ["--rustc-quit-on-rmeta", "true"])
    assert_list_contains_adjacent_elements_not(env, metadata_action.argv, ["--rustc-quit-on-rmeta", "true"])

    # The metadata action should use -Zno-codegen for the hollow rlib approach.
    assert_argv_contains(env, metadata_action, "-Zno-codegen")

    # The Rustc action should NOT use -Zno-codegen.
    no_codegen_in_rlib = [arg for arg in rlib_action.argv if arg == "-Zno-codegen"]
    asserts.true(env, len(no_codegen_in_rlib) == 0, "Rustc action should not have -Zno-codegen")

    # The metadata action references first's hollow rlib for --extern (pipelining: starts
    # before first's full codegen finishes). The Rustc action uses the full rlib for
    # --extern so the full rlib's embedded SVH matches the full rlib that downstream
    # binaries (without cc_common.link) see in their -Ldependency path. If both actions
    # used the hollow rlib, nondeterministic proc macros could produce different SVHs
    # for the hollow vs full rlib, causing E0460 in downstream binary builds.
    extern_metadata = [arg for arg in metadata_action.argv if arg.startswith("--extern=first=") and "libfirst" in arg and arg.endswith("-hollow.rlib")]
    asserts.true(
        env,
        len(extern_metadata) == 1,
        "did not find --extern=first=*-hollow.rlib for metadata action, got: " + str([arg for arg in metadata_action.argv if arg.startswith("--extern=first=")]),
    )
    extern_rlib_full = [arg for arg in rlib_action.argv if arg.startswith("--extern=first=") and "libfirst" in arg and not arg.endswith("-hollow.rlib")]
    asserts.true(
        env,
        len(extern_rlib_full) == 1,
        "expected --extern=first=libfirst*.rlib (full rlib) for rlib action, got: " + str([arg for arg in rlib_action.argv if arg.startswith("--extern=first=")]),
    )

    # The metadata action's input is first's hollow rlib only (no full rlib needed).
    input_metadata = [i for i in metadata_action.inputs.to_list() if i.basename.startswith("libfirst")]
    asserts.true(env, len(input_metadata) == 1, "expected only one libfirst input for metadata, found " + str([i.path for i in input_metadata]))
    asserts.true(env, input_metadata[0].basename.endswith("-hollow.rlib"), "expected hollow rlib for metadata action, found " + input_metadata[0].path)

    # The Rustc action's inputs contain the full rlib (referenced by --extern) and the
    # hollow rlib (present in the sandbox for -Ldependency=<_hollow_dir> resolution of
    # transitive deps that were compiled against hollow rlibs).
    input_rlib_full = [i for i in rlib_action.inputs.to_list() if i.basename.startswith("libfirst") and not i.basename.endswith("-hollow.rlib")]
    input_rlib_hollow = [i for i in rlib_action.inputs.to_list() if i.basename.startswith("libfirst") and i.basename.endswith("-hollow.rlib")]
    asserts.true(env, len(input_rlib_full) == 1, "expected full rlib in rlib action inputs, found " + str([i.path for i in input_rlib_full]))
    asserts.true(env, len(input_rlib_hollow) == 1, "expected hollow rlib in rlib action inputs (for sandbox), found " + str([i.path for i in input_rlib_hollow]))

    return analysistest.end(env)

def _bin_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    bin_action = [act for act in tut.actions if act.mnemonic == "Rustc"][0]

    # Check that no inputs to this binary are .rmeta files.
    metadata_inputs = [i.path for i in bin_action.inputs.to_list() if i.path.endswith(".rmeta")]

    # Filter out toolchain targets. This test intends to only check for rmeta files of `deps`.
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
    hollow_rlib_env_test(
        name = "hollow_rlib_env_test",
        target_under_test = ":second",
        target_compatible_with = _NO_WINDOWS,
    )

    return [
        ":second_lib_test",
        ":bin_test",
        ":hollow_rlib_env_test",
    ]

def _rmeta_is_propagated_through_custom_rule_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    # This is the metadata-generating action. It should depend on metadata for the library and, if generate_metadata is set
    # also depend on metadata for 'wrapper'.
    rust_action = [act for act in tut.actions if act.mnemonic == "RustcMetadata"][0]

    metadata_inputs = [i for i in rust_action.inputs.to_list() if i.path.endswith("-hollow.rlib")]
    rlib_inputs = [i for i in rust_action.inputs.to_list() if i.path.endswith(".rlib") and not i.path.endswith("-hollow.rlib")]

    seen_wrapper_metadata = False
    seen_to_wrap_metadata = False
    for mi in metadata_inputs:
        if "libwrapper" in mi.path:
            seen_wrapper_metadata = True
        if "libto_wrap" in mi.path:
            seen_to_wrap_metadata = True

    seen_wrapper_rlib = False
    seen_to_wrap_rlib = False
    for ri in rlib_inputs:
        if "libwrapper" in ri.path:
            seen_wrapper_rlib = True
        if "libto_wrap" in ri.path:
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

    seen_to_wrap_rlib = False
    seen_to_wrap_hollow = False
    for act in rust_action.inputs.to_list():
        if "libto_wrap" in act.path and act.path.endswith("-hollow.rlib"):
            seen_to_wrap_hollow = True
        elif "libto_wrap" in act.path and act.path.endswith(".rlib") and not act.path.endswith("-hollow.rlib"):
            seen_to_wrap_rlib = True

    if ctx.attr.generate_metadata:
        # When wrapper generates its own hollow rlib, the Rustc action uses the full
        # rlib of to_wrap for --extern (SVH consistency) and also has the hollow rlib
        # in the sandbox for -Ldependency= resolution.
        asserts.true(env, seen_to_wrap_hollow, "expected hollow rlib in inputs (for sandbox) when generate_metadata=True")
        asserts.true(env, seen_to_wrap_rlib, "expected full rlib in inputs for --extern when generate_metadata=True")
    else:
        # When wrapper does not generate its own hollow rlib, the Rustc action uses
        # hollow rlib deps via normal _depend_on_metadata logic (pipelined rlib deps).
        asserts.true(env, seen_to_wrap_hollow, "expected dependency on metadata for 'to_wrap' but not found")
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

def _hollow_rlib_env_test_impl(ctx):
    """Verify RUSTC_BOOTSTRAP=1 is set consistently on both Rustc and RustcMetadata actions.

    RUSTC_BOOTSTRAP=1 changes the crate hash (SVH), so it must be set on both actions
    to keep the hollow rlib and full rlib SVHs consistent."""
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    metadata_action = [act for act in tut.actions if act.mnemonic == "RustcMetadata"][0]
    rlib_action = [act for act in tut.actions if act.mnemonic == "Rustc"][0]

    asserts.equals(
        env,
        "1",
        metadata_action.env.get("RUSTC_BOOTSTRAP", ""),
        "Metadata action should have RUSTC_BOOTSTRAP=1 for hollow rlib approach",
    )
    asserts.equals(
        env,
        "1",
        rlib_action.env.get("RUSTC_BOOTSTRAP", ""),
        "Rustc action should have RUSTC_BOOTSTRAP=1 for SVH compatibility with hollow rlib",
    )

    return analysistest.end(env)

hollow_rlib_env_test = analysistest.make(_hollow_rlib_env_test_impl, config_settings = ENABLE_PIPELINING)

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

def _svh_mismatch_test():
    """Creates a rust_test demonstrating SVH mismatch with non-deterministic proc macros.

    Without pipelining (default): each library is compiled exactly once, SVH
    is consistent across the dependency graph, and the test builds and passes.

    With pipelining (//rust/settings:pipelined_compilation=true): rules_rust
    compiles svh_lib twice in separate rustc invocations — once for the hollow
    metadata (.rmeta), once for the full .rlib. Because the proc macro uses
    HashMap with OS-seeded randomness, these two invocations typically produce
    different token streams and therefore different SVH values. The consumer is
    compiled against the hollow .rmeta (recording SVH_1); when rustc links the
    test binary against the full .rlib (SVH_2), it detects SVH_1 ≠ SVH_2 and
    fails with E0460. The test is therefore expected to FAIL TO BUILD most of
    the time (~99.2% with 5 HashMap entries) when pipelining is enabled.

    The test is marked flaky because the SVH mismatch is non-deterministic:
    on rare occasions (~0.8%) both rustc invocations produce the same HashMap
    iteration order and the build succeeds even with pipelining enabled.
    """

    rust_proc_macro(
        name = "svh_nondeterministic_macro",
        srcs = ["svh_mismatch/svh_mismatch_nondeterministic_macro.rs"],
        crate_name = "nondeterministic_macro",
        edition = "2021",
    )

    rust_library(
        name = "svh_lib",
        srcs = ["svh_mismatch/svh_mismatch_lib.rs"],
        edition = "2021",
        proc_macro_deps = [":svh_nondeterministic_macro"],
    )

    rust_library(
        name = "svh_consumer",
        srcs = ["svh_mismatch/svh_mismatch_consumer.rs"],
        edition = "2021",
        deps = [":svh_lib"],
    )

    rust_test(
        name = "svh_mismatch_test",
        srcs = ["svh_mismatch/svh_mismatch_test.rs"],
        edition = "2021",
        deps = [":svh_consumer"],
        flaky = True,
        target_compatible_with = _NO_WINDOWS,
    )

    return [":svh_mismatch_test"]

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
    tests.extend(_svh_mismatch_test())

    native.test_suite(
        name = name,
        tests = tests,
    )

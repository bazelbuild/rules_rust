"""Analysis tests for the cargo-auditable integration."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load(
    "//rust:defs.bzl",
    "rust_binary",
    "rust_library",
)
# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _find_actions(tut, mnemonic):
    return [a for a in tut.actions if a.mnemonic == mnemonic]

def _get_json_content(tut):
    """Return the content string written by the FileWrite that produces the audit JSON."""
    for a in tut.actions:
        if a.mnemonic != "FileWrite":
            continue
        for out in a.outputs.to_list():
            if out.basename.endswith("_audit_deps.json"):
                return a.content
    return None

# ---------------------------------------------------------------------------
# Test 1: RustAuditable action present when enabled
# ---------------------------------------------------------------------------

def _auditable_action_present_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    auditable_actions = _find_actions(tut, "RustAuditable")
    asserts.equals(
        env,
        1,
        len(auditable_actions),
        "Expected exactly one RustAuditable action, got {}".format(len(auditable_actions)),
    )
    return analysistest.end(env)

auditable_action_present_test = analysistest.make(
    _auditable_action_present_test_impl,
    config_settings = {str(Label("//rust/settings:auditable")): True},
)

# ---------------------------------------------------------------------------
# Test 2: No RustAuditable action when setting is disabled
# ---------------------------------------------------------------------------

def _auditable_action_absent_disabled_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    auditable_actions = _find_actions(tut, "RustAuditable")
    asserts.equals(
        env,
        0,
        len(auditable_actions),
        "Expected no RustAuditable action when setting is disabled",
    )
    return analysistest.end(env)

auditable_action_absent_disabled_test = analysistest.make(
    _auditable_action_absent_disabled_test_impl,
)

# ---------------------------------------------------------------------------
# Test 3: No RustAuditable on rust_library
# ---------------------------------------------------------------------------

def _library_no_auditable_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    auditable_actions = _find_actions(tut, "RustAuditable")
    asserts.equals(
        env,
        0,
        len(auditable_actions),
        "rust_library should never produce RustAuditable actions",
    )
    return analysistest.end(env)

library_no_auditable_test = analysistest.make(
    _library_no_auditable_test_impl,
    config_settings = {str(Label("//rust/settings:auditable")): True},
)

# ---------------------------------------------------------------------------
# Test 4: Linker flags injected into Rustc action
# ---------------------------------------------------------------------------

def _linker_flags_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    rustc_actions = _find_actions(tut, "Rustc")
    asserts.true(env, len(rustc_actions) > 0, "Expected at least one Rustc action")

    found = False
    for action in rustc_actions:
        for arg in action.argv:
            if arg.startswith("--codegen=link-arg=") and "_audit_data.o" in arg:
                found = True
                break
        if found:
            break
    asserts.true(
        env,
        found,
        "Expected --codegen=link-arg=..._audit_data.o in a Rustc action's argv",
    )
    return analysistest.end(env)

linker_flags_test = analysistest.make(
    _linker_flags_test_impl,
    config_settings = {str(Label("//rust/settings:auditable")): True},
)

# ---------------------------------------------------------------------------
# Test 5: JSON content correctness
# ---------------------------------------------------------------------------

def _json_content_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)

    json = _get_json_content(tut)
    asserts.true(env, json != None, "Expected a FileWrite action producing *_audit_deps.json")

    asserts.true(
        env,
        '"name":"lib_a"' in json,
        "JSON should contain lib_a dependency",
    )
    asserts.true(
        env,
        '"version":"1.0.0"' in json,
        "JSON should contain lib_a's version 1.0.0",
    )
    asserts.true(
        env,
        '"source":"CratesIo"' in json,
        "JSON should contain lib_a's source CratesIo",
    )
    asserts.true(
        env,
        '"name":"lib_b"' in json,
        "JSON should contain transitive dep lib_b",
    )
    asserts.true(
        env,
        '"root":true' in json,
        "JSON should contain exactly one root entry",
    )
    asserts.true(
        env,
        '"format":0' in json,
        "JSON should contain format:0",
    )

    # The root crate should have non-empty dependencies (it depends on lib_a).
    root_start = json.find('"root":true')
    asserts.true(env, root_start > 0, "root entry should exist")
    pkg_start = json.rfind("{", 0, root_start)
    pkg_str = json[pkg_start:root_start + len('"root":true') + 1]
    asserts.true(
        env,
        '"dependencies":[]' not in pkg_str,
        "Root package should have non-empty dependencies, got: " + pkg_str,
    )

    return analysistest.end(env)

json_content_test = analysistest.make(
    _json_content_test_impl,
    config_settings = {str(Label("//rust/settings:auditable")): True},
)

# ---------------------------------------------------------------------------
# Subjects and test suite
# ---------------------------------------------------------------------------

def _auditable_test_subjects():
    """Create the test subject targets."""

    rust_library(
        name = "lib_b",
        srcs = ["lib_b.rs"],
        edition = "2021",
        version = "0.1.0",
        source = "CratesIo",
    )

    rust_library(
        name = "lib_a",
        srcs = ["lib.rs"],
        edition = "2021",
        deps = [":lib_b"],
        version = "1.0.0",
        source = "CratesIo",
    )

    rust_binary(
        name = "auditable_bin",
        srcs = ["main.rs"],
        edition = "2021",
        deps = [":lib_a"],
        version = "2.0.0",
        auditable_injector = "//tools/auditable:auditable_injector",
    )

def auditable_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _auditable_test_subjects()

    auditable_action_present_test(
        name = "auditable_action_present_test",
        target_under_test = ":auditable_bin",
    )

    auditable_action_absent_disabled_test(
        name = "auditable_action_absent_disabled_test",
        target_under_test = ":auditable_bin",
    )

    library_no_auditable_test(
        name = "library_no_auditable_test",
        target_under_test = ":lib_a",
    )

    linker_flags_test(
        name = "linker_flags_test",
        target_under_test = ":auditable_bin",
    )

    json_content_test(
        name = "json_content_test",
        target_under_test = ":auditable_bin",
    )

    native.test_suite(
        name = name,
        tests = [
            ":auditable_action_present_test",
            ":auditable_action_absent_disabled_test",
            ":library_no_auditable_test",
            ":linker_flags_test",
            ":json_content_test",
        ],
    )

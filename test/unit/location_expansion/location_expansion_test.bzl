"""Unittest to verify location expansion in rustc flags"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("//cargo:defs.bzl", "cargo_build_script")
load("//rust:defs.bzl", "rust_library", "rust_test")
load("//test/unit:common.bzl", "assert_action_mnemonic", "assert_argv_contains", "assert_env_value")

def _find_action(tut, mnemonic):
    for action in tut.actions:
        if action.mnemonic == mnemonic:
            return action
    return None

def _location_expansion_rustc_flags_test(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = tut.actions[1]
    assert_action_mnemonic(env, action, "Rustc")

    # Because target `rustc_flags` use location macros, the action does
    # not advertise `supports-path-mapping`, so file paths remain at their
    # configuration-specific `ctx.bin_dir` locations.
    assert_argv_contains(env, action, ctx.bin_dir.path + "/test/unit/location_expansion/mylibrary.rs")

    # All four forms must be prefixed with @${pwd}/ so that process_wrapper
    # can resolve them to absolute paths at run time. Each form references a
    # distinct generated file so every assertion targets a unique path.
    base = "@${pwd}/" + ctx.bin_dir.path + "/test/unit/location_expansion/"
    assert_argv_contains(env, action, base + "flag_execpath.data")
    assert_argv_contains(env, action, base + "flag_execpaths.data")
    assert_argv_contains(env, action, base + "flag_location.data")
    assert_argv_contains(env, action, base + "flag_locations.data")
    return analysistest.end(env)

location_expansion_rustc_flags_test = analysistest.make(_location_expansion_rustc_flags_test)

def _location_expansion_rustc_env_test(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = _find_action(tut, "Rustc")
    if not action:
        fail("No Rustc action found")

    # Sanity-check: `$(execpaths ...)` in `rustc_env` is expanded at
    # analysis time and surfaces as a configuration-specific path in
    # the env value. The build-time guard against path-mapping
    # mismatches lives in `mylibrary_env` itself: it pulls the env
    # path in via `include_bytes!(env!("MY_DATA"))`, so any path under
    # `--experimental_output_paths=strip` that doesn't match the
    # sandbox layout fails the build — see the comment in
    # `mylibrary_env.rs`.
    expected = "${pwd}/" + ctx.bin_dir.path + "/test/unit/location_expansion/flag_execpaths.data"
    assert_env_value(env, action, "MY_DATA", expected)
    return analysistest.end(env)

location_expansion_rustc_env_test = analysistest.make(_location_expansion_rustc_env_test)

def _location_expansion_build_script_env_test(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = _find_action(tut, "CargoBuildScriptRun")
    expected = "${pwd}/" + ctx.bin_dir.path + "/test/unit/location_expansion/flag_execpaths.data"
    assert_env_value(env, action, "MY_DATA", expected)
    return analysistest.end(env)

location_expansion_build_script_env_test = analysistest.make(_location_expansion_build_script_env_test)

def _location_expansion_test():
    for suffix in ("execpath", "execpaths", "location", "locations"):
        write_file(
            name = "flag_generator_" + suffix,
            out = "flag_" + suffix + ".data",
            content = [
                "--cfg=test_flag",
                "",
            ],
            newline = "unix",
        )

    rust_library(
        name = "mylibrary",
        srcs = ["mylibrary.rs"],
        edition = "2018",
        rustc_flags = [
            "@$(execpath :flag_generator_execpath)",
            "@$(execpaths :flag_generator_execpaths)",
            "@$(location :flag_generator_location)",
            "@$(locations :flag_generator_locations)",
        ],
        compile_data = [
            ":flag_generator_execpath",
            ":flag_generator_execpaths",
            ":flag_generator_location",
            ":flag_generator_locations",
        ],
    )

    # A library whose location expansion lives ONLY in `rustc_env` (not
    # in `rustc_flags`). Exercises the path-mapping interaction with
    # rustc_env specifically.
    rust_library(
        name = "mylibrary_env",
        srcs = ["mylibrary_env.rs"],
        edition = "2018",
        rustc_env = {
            "MY_DATA": "$(execpaths :flag_generator_execpaths)",
        },
        compile_data = [
            ":flag_generator_execpaths",
        ],
    )

    # Same shape as `mylibrary_env` but built through `rust_test`, which
    # takes a different `crate_info.rustc_env` code path — see
    # `mytest_env.rs` for the details of why PR #4117 doesn't cover it.
    rust_test(
        name = "mytest_env",
        srcs = ["mytest_env.rs"],
        edition = "2018",
        rustc_env = {
            "MY_DATA": "$(execpaths :flag_generator_execpaths)",
        },
        compile_data = [
            ":flag_generator_execpaths",
        ],
    )

    cargo_build_script(
        name = "mybuildscript",
        srcs = ["build_script.rs"],
        edition = "2018",
        data = [":flag_generator_execpaths"],
        build_script_env = {
            "MY_DATA": "$(execpaths :flag_generator_execpaths)",
        },
    )

    location_expansion_rustc_flags_test(
        name = "location_expansion_rustc_flags_test",
        target_under_test = ":mylibrary",
    )

    location_expansion_rustc_env_test(
        name = "location_expansion_rustc_env_test",
        target_under_test = ":mylibrary_env",
    )

    location_expansion_build_script_env_test(
        name = "location_expansion_build_script_env_test",
        target_under_test = ":mybuildscript",
    )

def location_expansion_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _location_expansion_test()

    native.test_suite(
        name = name,
        tests = [
            ":location_expansion_rustc_flags_test",
            ":location_expansion_rustc_env_test",
            ":location_expansion_build_script_env_test",
        ],
    )

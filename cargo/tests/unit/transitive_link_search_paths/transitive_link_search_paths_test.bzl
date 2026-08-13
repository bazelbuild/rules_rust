"""Unittests for rust rules."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//cargo:defs.bzl", "cargo_build_script")
load("//rust:defs.bzl", "rust_binary", "rust_common", "rust_library", "rust_proc_macro")
load("//test/unit:common.bzl", "assert_action_mnemonic", "assert_list_contains")

_TOOLCHAIN_NATIVE_SEARCH_PATH = "toolchain-native-search-path"

def _transitive_link_search_paths_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    link_search_path_files = tut[rust_common.dep_info].link_search_path_files.to_list()
    link_search_path_basenames = [f.basename for f in link_search_path_files]

    # Checks that this contains the dep build script, but not the build script
    # of the dep of the proc_macro.
    asserts.equals(env, link_search_path_basenames, ["dep_build_script.linksearchpaths"])

    return analysistest.end(env)

transitive_link_search_paths_test = analysistest.make(_transitive_link_search_paths_test_impl)

def _transitive_out_dir_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    action = tut.actions[0]
    assert_action_mnemonic(env, action, "Rustc")
    inputs = action.inputs.to_list()
    input_basenames = [f.basename for f in inputs]
    assert_list_contains(env, input_basenames, "dep_build_script.out_dir")

    return analysistest.end(env)

transitive_out_dir_test = analysistest.make(_transitive_out_dir_test_impl)

def _toolchain_link_search_path_precedes_build_script_paths_test_impl(ctx):
    env = analysistest.begin(ctx)
    action = analysistest.target_under_test(env).actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    argv = action.argv
    rustc_launch_index = -1
    build_script_arg_file_index = -1
    toolchain_search_path_index = -1
    for index, arg in enumerate(argv):
        if arg == "--":
            rustc_launch_index = index
        elif arg == "--arg-file" and index + 1 < len(argv):
            if argv[index + 1].endswith("/dep_build_script.linksearchpaths"):
                build_script_arg_file_index = index
        elif arg == "-Lnative=" + _TOOLCHAIN_NATIVE_SEARCH_PATH:
            toolchain_search_path_index = index

    asserts.true(env, rustc_launch_index >= 0, "Expected process_wrapper to launch rustc after '--'")
    asserts.true(
        env,
        build_script_arg_file_index >= 0 and build_script_arg_file_index < rustc_launch_index,
        "Expected dep_build_script.linksearchpaths as a process_wrapper --arg-file: {}".format(argv),
    )
    asserts.true(
        env,
        rustc_launch_index < toolchain_search_path_index,
        "Expected the C-toolchain search path as a rustc -Lnative argument: {}".format(argv),
    )
    asserts.false(
        env,
        "--codegen=link-arg=-L" + _TOOLCHAIN_NATIVE_SEARCH_PATH in argv,
        "C-toolchain search paths must not remain late linker arguments",
    )

    return analysistest.end(env)

toolchain_link_search_path_precedes_build_script_paths_test = analysistest.make(
    _toolchain_link_search_path_precedes_build_script_paths_test_impl,
    config_settings = {
        "//command_line_option:linkopt": ["-L" + _TOOLCHAIN_NATIVE_SEARCH_PATH],
    },
)

def _transitive_link_search_paths_test():
    cargo_build_script(
        name = "proc_macro_build_script",
        srcs = ["proc_macro_build.rs"],
        edition = "2018",
    )

    rust_proc_macro(
        name = "proc_macro",
        srcs = ["proc_macro.rs"],
        edition = "2018",
        deps = [":proc_macro_build_script"],
    )

    cargo_build_script(
        name = "dep_build_script",
        srcs = ["dep_build.rs"],
        edition = "2018",
    )

    rust_library(
        name = "dep",
        srcs = ["dep.rs"],
        edition = "2018",
        proc_macro_deps = [":proc_macro"],
        deps = [":dep_build_script"],
    )

    rust_binary(
        name = "bin",
        srcs = ["bin.rs"],
        edition = "2018",
        deps = [":dep"],
    )

    transitive_link_search_paths_test(
        name = "transitive_link_search_paths_test",
        target_under_test = ":dep",
    )

    transitive_out_dir_test(
        name = "transitive_out_dir_test",
        target_under_test = ":bin",
    )

    toolchain_link_search_path_precedes_build_script_paths_test(
        name = "toolchain_link_search_path_precedes_build_script_paths_test",
        target_under_test = ":bin",
    )

def transitive_link_search_paths_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name: Name of the macro.
    """
    _transitive_link_search_paths_test()

    native.test_suite(
        name = name,
        tests = [
            ":transitive_link_search_paths_test",
            ":transitive_out_dir_test",
            ":toolchain_link_search_path_precedes_build_script_paths_test",
        ],
    )

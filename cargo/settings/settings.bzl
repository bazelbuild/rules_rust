"""# Cargo settings

Definitions for all `@rules_rust//cargo` settings
"""

load("@bazel_skylib//rules:common_settings.bzl", "bool_flag", "string_list_flag")

def experimental_symlink_execroot():
    """A flag for which causes `cargo_build_script` to symlink the execroot of the action to \
    the `CARGO_MANIFEST_DIR` where the scripts are run.
    """
    bool_flag(
        name = "experimental_symlink_execroot",
        build_setting_default = False,
    )

def cargo_manifest_dir_filename_suffixes_to_retain():
    """A flag which determines what files are retained in `CARGO_MANIFEST_DIR` directories \
    that are created in `CargoBuildScriptRun` actions.
    """
    string_list_flag(
        name = "cargo_manifest_dir_filename_suffixes_to_retain",
        build_setting_default = [
            ".lib",
            ".so",
        ],
    )

def debug_std_streams_output_group():
    """A flag which adds a `streams` output group to `cargo_build_script` targets that contain \
    the raw `stderr` and `stdout` streams from the build script.
    """
    bool_flag(
        name = "debug_std_streams_output_group",
        build_setting_default = False,
    )

def use_default_shell_env():
    """A flag which controls the global default of `ctx.actions.run.use_default_shell_env` for `cargo_build_script` targets.
    """
    bool_flag(
        name = "use_default_shell_env",
        build_setting_default = True,
    )

def out_dir_volatile_file_basenames():
    """A flag which determines what file basenames are removed from `OUT_DIR` by `cargo_build_script` actions to make the `_bs.out_dir` TreeArtifact deterministic.

    Files whose names appear in this list, as well as files with a `.d` or `.pc`
    extension, are deleted from `OUT_DIR` after the build script runs and before Bazel
    captures the directory. Files like `config.log` and `Makefile` embed the Bazel
    sandbox path, so their content changes on every action invocation, causing cache
    misses for all downstream `rustc` compilations.
    """
    string_list_flag(
        name = "out_dir_volatile_file_basenames",
        build_setting_default = [
            "config.log",
            "config.log.old",
            "config.status",
            "Makefile",
            "Makefile.config",
            "config.cache",
            "commit_hash",
        ],
    )

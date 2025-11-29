""" CC Archive ActionConfigs for llvm-ar """

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "action_config",
    "flag_group",
    "flag_set",
    "tool",
    "variable_with_value",
)

BASE_ARCHIVER_FLAG_SET = flag_set(
    flag_groups = [
        flag_group(
            flags = ["-rcsD", "%{output_execpath}"],
            expand_if_available = "output_execpath",
        ),
        flag_group(
            iterate_over = "libraries_to_link",
            flag_groups = [
                flag_group(
                    flags = ["%{libraries_to_link.name}"],
                    expand_if_equal = variable_with_value(
                        name = "libraries_to_link.type",
                        value = "object_file",
                    ),
                ),
                flag_group(
                    flags = ["%{libraries_to_link.object_files}"],
                    iterate_over = "libraries_to_link.object_files",
                    expand_if_equal = variable_with_value(
                        name = "libraries_to_link.type",
                        value = "object_file_group",
                    ),
                ),
            ],
            expand_if_available = "libraries_to_link",
        ),
    ],
)

def archive_action_configs(llvm, archive_flags):
    """
    Generates CC Archive ActionConfigs

    Args:
        llvm (string): Path to LLVM binaries.
        archive_flags (List): List of flags to always be passed to the archiver.

    Returns:
        List of CC Archive ActionConfigs
    """

    archive_flag_set = flag_set(
        flag_groups = ([
            flag_group(flags = archive_flags),
        ] if archive_flags else []),
    )

    return [action_config(
        action_name = ACTION_NAMES.cpp_link_static_library,
        tools = [tool(path = "{}/bin/llvm-ar".format(llvm))],
        flag_sets = [
            # Mandatory, no link flags come through on command line.
            flag_set(
                flag_groups = [
                    flag_group(
                        flags = ["@%{linker_param_file}"],
                        expand_if_available = "linker_param_file",
                    ),
                ],
            ),
            archive_flag_set,
            BASE_ARCHIVER_FLAG_SET,
        ],
    )]

""" CC Strip ActionConfigs for llvm-strip """

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "action_config",
    "flag_group",
    "flag_set",
    "tool",
)

def strip_action_configs(llvm):
    """
    Generates CC Strip ActionConfigs

    Args:
        llvm (string): Path to LLVM binaries.

    Returns:
        List of CC Strip ActionConfigs
    """

    return [action_config(
        action_name = ACTION_NAMES.strip,
        tools = [tool(path = "{}/bin/llvm-strip".format(llvm))],
        flag_sets = [
            flag_set(
                flag_groups = [
                    flag_group(
                        flags = ["-S", "-p", "-o", "%{output_file}"],
                    ),
                    flag_group(
                        iterate_over = "stripopts",
                        flags = ["%{stripopts}"],
                    ),
                    flag_group(
                        flags = ["%{input_file}"],
                    ),
                ],
            ),
        ],
    )]

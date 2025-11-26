""" CC Link ActionConfigs for lld-link """

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "action_config",
    "flag_group",
    "flag_set",
    "tool",
    "variable_with_value",
    "with_feature_set",
)

BAZEL_LINK_FLAG_SET = flag_set(
    flag_groups = [
        flag_group(
            flags = ["%{linkstamp_paths}"],
            iterate_over = "linkstamp_paths",
            expand_if_available = "linkstamp_paths",
        ),
        flag_group(
            iterate_over = "runtime_library_search_directories",
            flag_groups = [
                flag_group(
                    flags = [
                        "-Xlinker",
                        "-rpath",
                        "-Xlinker",
                        "$ORIGIN/%{runtime_library_search_directories}",
                    ],
                ),
            ],
            expand_if_available =
                "runtime_library_search_directories",
        ),
        flag_group(
            flags = ["/libpath:%{library_search_directories}"],
            iterate_over = "library_search_directories",
            expand_if_available = "library_search_directories",
        ),
        flag_group(
            iterate_over = "libraries_to_link",
            flag_groups = [
                flag_group(
                    flags = ["/start-lib"],
                    expand_if_equal = variable_with_value(
                        name = "libraries_to_link.type",
                        value = "object_file_group",
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
                flag_group(
                    flags = ["%{libraries_to_link.name}"],
                    expand_if_equal = variable_with_value(
                        name = "libraries_to_link.type",
                        value = "object_file",
                    ),
                ),
                flag_group(
                    flags = ["%{libraries_to_link.name}"],
                    expand_if_equal = variable_with_value(
                        name = "libraries_to_link.type",
                        value = "interface_library",
                    ),
                ),
                flag_group(
                    flag_groups = [
                        flag_group(
                            flags = ["%{libraries_to_link.name}"],
                            expand_if_false = "libraries_to_link.is_whole_archive",
                        ),
                        flag_group(
                            flags = ["/wholearchive:%{libraries_to_link.name}"],
                            expand_if_true = "libraries_to_link.is_whole_archive",
                        ),
                    ],
                    expand_if_equal = variable_with_value(
                        name = "libraries_to_link.type",
                        value = "static_library",
                    ),
                ),
                flag_group(
                    flags = ["%{libraries_to_link.name}"],
                    expand_if_equal = variable_with_value(
                        name = "libraries_to_link.type",
                        value = "dynamic_library",
                    ),
                ),
                flag_group(
                    flags = ["%{libraries_to_link.name}"],
                    expand_if_equal = variable_with_value(
                        name = "libraries_to_link.type",
                        value = "versioned_dynamic_library",
                    ),
                ),
                flag_group(
                    flags = ["/end-lib"],
                    expand_if_equal = variable_with_value(
                        name = "libraries_to_link.type",
                        value = "object_file_group",
                    ),
                ),
            ],
            expand_if_available = "libraries_to_link",
        ),
        flag_group(
            flags = ["@%{thinlto_param_file}"],
            expand_if_true = "thinlto_param_file",
        ),
        flag_group(
            flags = ["%{user_link_flags}"],
            iterate_over = "user_link_flags",
            expand_if_available = "user_link_flags",
        ),
        flag_group(
            flags = ["/out:%{output_execpath}"],
            expand_if_available = "output_execpath",
        ),
    ],
)

def link_action_configs(
        llvm,
        builtin_executable_objects,
        builtin_library_directories,
        builtin_libraries,
        builtin_framework_directories,
        builtin_frameworks,
        link_flags,
        dbg_link_flags,
        fastbuild_link_flags,
        opt_link_flags):
    """
    Generates CC Link ActionConfigs

    Args:
        llvm (string): Path to LLVM binaries.
        builtin_library_directories (List): List of library directories to always be passed to the linker.
        builtin_libraries (List): List of libraries to always be passed to the linker.
        builtin_framework_directories (List): List of Apple framework directories to always be passed to the linker.
        builtin_frameworks (List): List of Apple frameworks to always be passed to the linker.
        builtin_executable_objects (List): List of object files to always be passed to the linker.
        link_flags (List): List of flags to always be passed to the linker.
        dbg_link_flags (List): List of additional flags to always be passed to the linker in dbg configuration.
        fastbuild_link_flags (List): List of additional flags to always be passed to the linker in fastbuild configuration.
        opt_link_flags (List): List of additional flags to always be passed to the linker in opt configuration.

    Returns:
        List of CC Link ActionConfigs
    """

    builtin_library_directory_link_flags = []
    for builtin_library_directory in builtin_library_directories:
        builtin_library_directory_link_flags.append("/libpath:{}".format(builtin_library_directory))

    builtin_library_link_flags = []
    for builtin_library in builtin_libraries:
        builtin_library_link_flags.append(builtin_library)

    if builtin_framework_directories:
        fail("Frameworks not supported by `lld-link`")

    if builtin_frameworks:
        fail("Frameworks not supported by `lld-link`")

    builtin_executable_objects_link_flags = []
    for builtin_executable_object in builtin_executable_objects:
        builtin_executable_objects_link_flags.append(builtin_executable_object)

    required_link_flags = (["/nodefaultlib"] +
                           builtin_library_directory_link_flags +
                           builtin_library_link_flags)
    required_link_flag_set = flag_set(
        flag_groups = ([
            flag_group(flags = required_link_flags),
        ] if required_link_flags else []),
    )

    required_executable_link_flags = (builtin_executable_objects_link_flags)
    required_executable_link_flag_set = flag_set(
        flag_groups = ([
            flag_group(flags = required_executable_link_flags),
        ] if required_executable_link_flags else []),
    )

    link_flag_set = flag_set(
        flag_groups = ([
            flag_group(flags = link_flags),
        ] if link_flags else []),
    )

    dbg_link_flag_set = flag_set(
        flag_groups = ([
            flag_group(flags = dbg_link_flags),
        ] if dbg_link_flags else []),
        with_features = [with_feature_set(features = ["dbg"])],
    )

    fastbuild_link_flag_set = flag_set(
        flag_groups = ([
            flag_group(flags = fastbuild_link_flags),
        ] if fastbuild_link_flags else []),
        with_features = [with_feature_set(features = ["fastbuild"])],
    )

    opt_link_flag_set = flag_set(
        flag_groups = ([
            flag_group(flags = opt_link_flags),
        ] if opt_link_flags else []),
        with_features = [with_feature_set(features = ["opt"])],
    )

    return [
        action_config(
            action_name = ACTION_NAMES.cpp_link_dynamic_library,
            tools = [tool(path = "{}/bin/lld-link".format(llvm))],
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
                required_link_flag_set,
                link_flag_set,
                dbg_link_flag_set,
                fastbuild_link_flag_set,
                opt_link_flag_set,
                BAZEL_LINK_FLAG_SET,
                flag_set(
                    flag_groups = [
                        flag_group(
                            flags = ["/dll"],
                        ),
                    ],
                ),
            ],
        ),
        action_config(
            action_name = ACTION_NAMES.cpp_link_nodeps_dynamic_library,
            tools = [tool(path = "{}/bin/lld-link".format(llvm))],
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
                required_link_flag_set,
                link_flag_set,
                dbg_link_flag_set,
                fastbuild_link_flag_set,
                opt_link_flag_set,
                BAZEL_LINK_FLAG_SET,
                flag_set(
                    flag_groups = [
                        flag_group(
                            flags = ["/dll"],
                        ),
                    ],
                ),
            ],
        ),
        action_config(
            action_name = ACTION_NAMES.cpp_link_executable,
            tools = [tool(path = "{}/bin/lld-link".format(llvm))],
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
                required_link_flag_set,
                required_executable_link_flag_set,
                link_flag_set,
                dbg_link_flag_set,
                fastbuild_link_flag_set,
                opt_link_flag_set,
                BAZEL_LINK_FLAG_SET,
            ],
        ),
    ]

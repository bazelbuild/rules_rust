# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Functionality for constructing actions that invoke the Rust compiler"""

load(
    "@bazel_tools//tools/build_defs/cc:action_names.bzl",
    "CPP_LINK_EXECUTABLE_ACTION_NAME",
)
load("//rust/private:common.bzl", "rust_common")
load("//rust/private:providers.bzl", _BuildInfo = "BuildInfo")
load("//rust/private:stamp.bzl", "is_stamping_enabled")
load(
    "//rust/private:utils.bzl",
    "expand_dict_value_locations",
    "expand_list_element_locations",
    "find_cc_toolchain",
    "get_lib_name",
    "get_preferred_artifact",
    "is_exec_configuration",
    "make_static_lib_symlink",
    "relativize",
)

BuildInfo = _BuildInfo

AliasableDepInfo = provider(
    doc = "A provider mapping an alias name to a Crate's information.",
    fields = {
        "dep": "CrateInfo",
        "name": "str",
    },
)

_error_format_values = ["human", "json", "short"]

ErrorFormatInfo = provider(
    doc = "Set the --error-format flag for all rustc invocations",
    fields = {"error_format": "(string) [" + ", ".join(_error_format_values) + "]"},
)

ExtraRustcFlagsInfo = provider(
    doc = "Pass each value as an additional flag to non-exec rustc invocations",
    fields = {"extra_rustc_flags": "List[string] Extra flags to pass to rustc in non-exec configuration"},
)

ExtraExecRustcFlagsInfo = provider(
    doc = "Pass each value as an additional flag to exec rustc invocations",
    fields = {"extra_exec_rustc_flags": "List[string] Extra flags to pass to rustc in exec configuration"},
)

def _get_rustc_env(attr, toolchain, crate_name):
    """Gathers rustc environment variables

    Args:
        attr (struct): The current target's attributes
        toolchain (rust_toolchain): The current target's rust toolchain context
        crate_name (str): The name of the crate to be compiled

    Returns:
        dict: Rustc environment variables
    """
    version = attr.version if hasattr(attr, "version") else "0.0.0"
    major, minor, patch = version.split(".", 2)
    if "-" in patch:
        patch, pre = patch.split("-", 1)
    else:
        pre = ""
    return {
        "CARGO_CFG_TARGET_ARCH": toolchain.target_arch,
        "CARGO_CFG_TARGET_OS": toolchain.os,
        "CARGO_CRATE_NAME": crate_name,
        "CARGO_PKG_AUTHORS": "",
        "CARGO_PKG_DESCRIPTION": "",
        "CARGO_PKG_HOMEPAGE": "",
        "CARGO_PKG_NAME": attr.name,
        "CARGO_PKG_VERSION": version,
        "CARGO_PKG_VERSION_MAJOR": major,
        "CARGO_PKG_VERSION_MINOR": minor,
        "CARGO_PKG_VERSION_PATCH": patch,
        "CARGO_PKG_VERSION_PRE": pre,
    }

def get_compilation_mode_opts(ctx, toolchain):
    """Gathers rustc flags for the current compilation mode (opt/debug)

    Args:
        ctx (ctx): The current rule's context object
        toolchain (rust_toolchain): The current rule's `rust_toolchain`

    Returns:
        struct: See `_rust_toolchain_impl` for more details
    """
    comp_mode = ctx.var["COMPILATION_MODE"]
    if not comp_mode in toolchain.compilation_mode_opts:
        fail("Unrecognized compilation mode {} for toolchain.".format(comp_mode))

    return toolchain.compilation_mode_opts[comp_mode]

def _are_linkstamps_supported(feature_configuration, has_grep_includes):
    # Are linkstamps supported by the C++ toolchain?
    return (cc_common.is_enabled(feature_configuration = feature_configuration, feature_name = "linkstamps") and
            # Is Bazel recent enough to support Starlark linkstamps?
            hasattr(cc_common, "register_linkstamp_compile_action") and
            # The current rule doesn't define _grep_includes attribute; this
            # attribute is required for compiling linkstamps.
            has_grep_includes)

def collect_deps(
        label,
        deps,
        proc_macro_deps,
        aliases,
        are_linkstamps_supported = False,
        remove_transitive_libs_from_dep_info = False):
    """Walks through dependencies and collects the transitive dependencies.

    Args:
        label (str): Label of the current target.
        deps (list): The deps from ctx.attr.deps.
        proc_macro_deps (list): The proc_macro deps from ctx.attr.proc_macro_deps.
        aliases (dict): A dict mapping aliased targets to their actual Crate information.
        are_linkstamps_supported (bool): Whether the current rule and the toolchain support building linkstamps..
        remove_transitive_libs_from_dep_info (bool): Whether
            --incompatible_remove_transitive_libs_from_dep_info has been flipped.

    Returns:
        tuple: Returns a tuple of:
            DepInfo,
            BuildInfo,
            linkstamps (depset[CcLinkstamp]): A depset of CcLinkstamps that need to be compiled and linked into all linked binaries.

    """
    direct_crates = []
    transitive_crates = []
    transitive_noncrates = []
    transitive_noncrate_libs = []
    transitive_build_infos = []
    build_info = None
    linkstamps = []
    transitive_crate_outputs = []

    aliases = {k.label: v for k, v in aliases.items()}
    for dep in depset(transitive = [deps, proc_macro_deps]).to_list():
        (crate_info, dep_info) = _get_crate_and_dep_info(dep)
        cc_info = _get_cc_info(dep)
        dep_build_info = _get_build_info(dep)

        if cc_info and are_linkstamps_supported:
            linkstamps.append(cc_info.linking_context.linkstamps())

        if crate_info:
            # This dependency is a rust_library

            # When crate_info.owner is set, we use it. When the dep type is Target we get the
            # label from dep.label
            owner = getattr(crate_info, "owner", dep.label if type(dep) == "Target" else None)

            direct_crates.append(AliasableDepInfo(
                name = aliases.get(owner, crate_info.name),
                dep = crate_info,
            ))

            transitive_crates.append(depset([crate_info], transitive = [dep_info.transitive_crates]))
            transitive_crate_outputs.append(
                depset(
                    [crate_info.output],
                    transitive = [dep_info.transitive_crate_outputs],
                ),
            )
            transitive_noncrates.append(dep_info.transitive_noncrates)
            if not remove_transitive_libs_from_dep_info:
                transitive_noncrate_libs.append(dep_info.transitive_libs)
            transitive_build_infos.append(dep_info.transitive_build_infos)
        elif cc_info:
            # This dependency is a cc_library
            transitive_noncrates.append(cc_info.linking_context.linker_inputs)
            if not remove_transitive_libs_from_dep_info:
                transitive_noncrate_libs.append(depset(
                    _collect_libs_from_linker_inputs(cc_info.linking_context.linker_inputs.to_list()),
                ))
        elif dep_build_info:
            if build_info:
                fail("Several deps are providing build information, " +
                     "only one is allowed in the dependencies")
            build_info = dep_build_info
            transitive_build_infos.append(depset([build_info]))
        else:
            fail("rust targets can only depend on rust_library, rust_*_library or cc_library " +
                 "targets.")

    transitive_crates_depset = depset(transitive = transitive_crates)
    transitive_libs = depset([])
    if not remove_transitive_libs_from_dep_info:
        transitive_libs = depset(
            [c.output for c in transitive_crates_depset.to_list()],
            transitive = transitive_noncrate_libs,
        )

    return (
        rust_common.dep_info(
            direct_crates = depset(direct_crates),
            transitive_crates = transitive_crates_depset,
            transitive_noncrates = depset(
                transitive = transitive_noncrates,
                order = "topological",  # dylib link flag ordering matters.
            ),
            transitive_crate_outputs = depset(transitive = transitive_crate_outputs),
            transitive_libs = transitive_libs,
            transitive_build_infos = depset(transitive = transitive_build_infos),
            dep_env = build_info.dep_env if build_info else None,
        ),
        build_info,
        depset(transitive = linkstamps),
    )

def _collect_libs_from_linker_inputs(linker_inputs):
    # TODO: We could let the user choose how to link, instead of always preferring to link static libraries.
    return [
        get_preferred_artifact(lib)
        for li in linker_inputs
        for lib in li.libraries
    ]

def _get_crate_and_dep_info(dep):
    if type(dep) == "Target" and rust_common.crate_info in dep:
        return (dep[rust_common.crate_info], dep[rust_common.dep_info])
    elif type(dep) == "struct" and hasattr(dep, "crate_info"):
        return (dep.crate_info, dep.dep_info)
    return (None, None)

def _get_cc_info(dep):
    if type(dep) == "Target" and CcInfo in dep:
        return dep[CcInfo]
    elif type(dep) == "struct" and hasattr(dep, "cc_info"):
        return dep.cc_info
    return None

def _get_build_info(dep):
    if type(dep) == "Target" and BuildInfo in dep:
        return dep[BuildInfo]
    elif type(dep) == "struct" and hasattr(dep, "build_info"):
        return dep.build_info
    return None

def get_cc_user_link_flags(ctx):
    """Get the current target's linkopt flags

    Args:
        ctx (ctx): The current rule's context object

    Returns:
        depset: The flags passed to Bazel by --linkopt option.
    """
    return ctx.fragments.cpp.linkopts

def get_linker_and_args(ctx, attr, cc_toolchain, feature_configuration, rpaths):
    """Gathers cc_common linker information

    Args:
        ctx (ctx): The current target's context object
        attr (struct): Attributes to use in gathering linker args
        cc_toolchain (CcToolchain): cc_toolchain for which we are creating build variables.
        feature_configuration (FeatureConfiguration): Feature configuration to be queried.
        rpaths (depset): Depset of directories where loader will look for libraries at runtime.


    Returns:
        tuple: A tuple of the following items:
            - (str): The tool path for given action.
            - (sequence): A flattened command line flags for given action.
            - (dict): Environment variables to be set for given action.
    """
    user_link_flags = get_cc_user_link_flags(ctx)

    # Add linkopt's from dependencies. This includes linkopts from transitive
    # dependencies since they get merged up.
    for dep in getattr(attr, "deps", []):
        if CcInfo in dep and dep[CcInfo].linking_context:
            for linker_input in dep[CcInfo].linking_context.linker_inputs.to_list():
                for flag in linker_input.user_link_flags:
                    user_link_flags.append(flag)
    link_variables = cc_common.create_link_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        is_linking_dynamic_library = False,
        runtime_library_search_directories = rpaths,
        user_link_flags = user_link_flags,
    )
    link_args = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_EXECUTABLE_ACTION_NAME,
        variables = link_variables,
    )
    link_env = cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_EXECUTABLE_ACTION_NAME,
        variables = link_variables,
    )
    ld = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_EXECUTABLE_ACTION_NAME,
    )

    return ld, link_args, link_env

def _process_build_scripts(
        ctx,
        file,
        crate_info,
        build_info,
        dep_info,
        compile_inputs):
    """Gathers the outputs from a target's `cargo_build_script` action.

    Args:
        ctx (ctx): The rule's context object
        file (File): A struct containing files defined in label type attributes marked as `allow_single_file`.
        crate_info (CrateInfo): The Crate information of the crate to process build scripts for.
        build_info (BuildInfo): The target Build's dependency info.
        dep_info (Depinfo): The target Crate's dependency info.
        compile_inputs (depset): A set of all files that will participate in the build.

    Returns:
        tuple: A tuple: A tuple of the following items:
            - (list): A list of all build info `OUT_DIR` File objects
            - (str): The `OUT_DIR` of the current build info
            - (File): An optional path to a generated environment file from a `cargo_build_script` target
            - (list): All direct and transitive build flags from the current build info.
    """
    extra_inputs, out_dir, build_env_file, build_flags_files = _create_extra_input_args(ctx, file, build_info, dep_info)
    if extra_inputs:
        compile_inputs = depset(extra_inputs, transitive = [compile_inputs])
    return compile_inputs, out_dir, build_env_file, build_flags_files

def collect_inputs(
        ctx,
        file,
        files,
        linkstamps,
        toolchain,
        cc_toolchain,
        feature_configuration,
        crate_info,
        dep_info,
        build_info,
        stamp = False):
    """Gather's the inputs and required input information for a rustc action

    Args:
        ctx (ctx): The rule's context object.
        file (struct): A struct containing files defined in label type attributes marked as `allow_single_file`.
        files (list): A list of all inputs (`ctx.files`).
        linkstamps (depset): A depset of CcLinkstamps that need to be compiled and linked into all linked binaries.
        toolchain (rust_toolchain): The current `rust_toolchain`.
        cc_toolchain (CcToolchainInfo): The current `cc_toolchain`.
        feature_configuration (FeatureConfiguration): Feature configuration to be queried.
        crate_info (CrateInfo): The Crate information of the crate to process build scripts for.
        dep_info (DepInfo): The target Crate's dependency information.
        build_info (BuildInfo): The target Crate's build settings.
        stamp (bool, optional): Whether or not workspace status stamping is enabled. For more details see
            https://docs.bazel.build/versions/main/user-manual.html#flag--stamp

    Returns:
        tuple: A tuple: A tuple of the following items:
            - (list): A list of all build info `OUT_DIR` File objects
            - (str): The `OUT_DIR` of the current build info
            - (File): An optional path to a generated environment file from a `cargo_build_script` target
            - (list): All direct and transitive build flags from the current build info
            - (list[File]): Linkstamp outputs.
    """
    linker_script = getattr(file, "linker_script") if hasattr(file, "linker_script") else None

    linker_depset = cc_toolchain.all_files

    # Pass linker inputs only for linking-like actions, not for example where
    # the output is rlib. This avoids quadratic behavior where transitive noncrates are
    # flattened on each transitive rust_library dependency.
    additional_transitive_inputs = []
    if crate_info.type in ("staticlib", "proc-macro"):
        additional_transitive_inputs = _collect_libs_from_linker_inputs(
            dep_info.transitive_noncrates.to_list(),
        )
    elif crate_info.type in ("bin", "dylib", "cdylib"):
        linker_inputs = dep_info.transitive_noncrates.to_list()
        additional_transitive_inputs = _collect_libs_from_linker_inputs(linker_inputs) + [
            additional_input
            for linker_input in linker_inputs
            for additional_input in linker_input.additional_inputs
        ]

    # Compute linkstamps. Use the inputs of the binary as inputs to the
    # linkstamp action to ensure linkstamps are rebuilt whenever binary inputs
    # change.
    linkstamp_outs = []

    nolinkstamp_compile_inputs = depset(
        getattr(files, "data", []) +
        [toolchain.rustc] +
        toolchain.crosstool_files +
        ([build_info.rustc_env, build_info.flags] if build_info else []) +
        ([toolchain.target_json] if toolchain.target_json else []) +
        ([] if linker_script == None else [linker_script]),
        transitive = [
            toolchain.rustc_lib,
            toolchain.rust_std,
            linker_depset,
            crate_info.srcs,
            dep_info.transitive_crate_outputs,
            depset(additional_transitive_inputs),
            crate_info.compile_data,
        ],
    )

    if crate_info.type in ("bin", "cdylib"):
        # There is no other way to register an action for each member of a depset than
        # flattening the depset as of 2021-10-12. Luckily, usually there is only one linkstamp
        # in a build, and we only flatten the list on binary targets that perform transitive linking,
        # so it's extremely unlikely that this call to `to_list()` will ever be a performance
        # problem.
        for linkstamp in linkstamps.to_list():
            # The linkstamp output path is based on the binary crate
            # name and the input linkstamp path. This is to disambiguate
            # the linkstamp outputs produced by multiple binary crates
            # that depend on the same linkstamp. We use the same pattern
            # for the output name as the one used by native cc rules.
            out_name = "_objs/" + crate_info.output.basename + "/" + linkstamp.file().path[:-len(linkstamp.file().extension)] + "o"
            linkstamp_out = ctx.actions.declare_file(out_name)
            linkstamp_outs.append(linkstamp_out)
            cc_common.register_linkstamp_compile_action(
                actions = ctx.actions,
                cc_toolchain = cc_toolchain,
                feature_configuration = feature_configuration,
                grep_includes = ctx.file._grep_includes,
                source_file = linkstamp.file(),
                output_file = linkstamp_out,
                compilation_inputs = linkstamp.hdrs(),
                inputs_for_validation = nolinkstamp_compile_inputs,
                label_replacement = str(ctx.label),
                output_replacement = crate_info.output.path,
            )

    # If stamping is enabled include the volatile status info file
    stamp_info = [ctx.version_file] if stamp else []

    compile_inputs = depset(
        linkstamp_outs + stamp_info,
        transitive = [
            nolinkstamp_compile_inputs,
        ],
    )

    build_env_files = getattr(files, "rustc_env_files", [])
    compile_inputs, out_dir, build_env_file, build_flags_files = _process_build_scripts(ctx, file, crate_info, build_info, dep_info, compile_inputs)
    if build_env_file:
        build_env_files = [f for f in build_env_files] + [build_env_file]
    compile_inputs = depset(build_env_files, transitive = [compile_inputs])

    return compile_inputs, out_dir, build_env_files, build_flags_files, linkstamp_outs

def construct_arguments(
        ctx,
        attr,
        file,
        toolchain,
        tool_path,
        cc_toolchain,
        feature_configuration,
        crate_info,
        dep_info,
        linkstamp_outs,
        output_hash,
        rust_flags,
        out_dir,
        build_env_files,
        build_flags_files,
        emit = ["dep-info", "link"],
        force_all_deps_direct = False,
        force_link = False,
        stamp = False,
        remap_path_prefix = "."):
    """Builds an Args object containing common rustc flags

    Args:
        ctx (ctx): The rule's context object
        attr (struct): The attributes for the target. These may be different from ctx.attr in an aspect context.
        file (struct): A struct containing files defined in label type attributes marked as `allow_single_file`.
        toolchain (rust_toolchain): The current target's `rust_toolchain`
        tool_path (str): Path to rustc
        cc_toolchain (CcToolchain): The CcToolchain for the current target.
        feature_configuration (FeatureConfiguration): Class used to construct command lines from CROSSTOOL features.
        crate_info (CrateInfo): The CrateInfo provider of the target crate
        dep_info (DepInfo): The DepInfo provider of the target crate
        linkstamp_outs (list): Linkstamp outputs of native dependencies
        output_hash (str): The hashed path of the crate root
        rust_flags (list): Additional flags to pass to rustc
        out_dir (str): The path to the output directory for the target Crate.
        build_env_files (list): Files containing rustc environment variables, for instance from `cargo_build_script` actions.
        build_flags_files (list): The output files of a `cargo_build_script` actions containing rustc build flags
        emit (list): Values for the --emit flag to rustc.
        force_all_deps_direct (bool, optional): Whether to pass the transitive rlibs with --extern
            to the commandline as opposed to -L.
        force_link (bool, optional): Whether to add link flags to the command regardless of `emit`.
        stamp (bool, optional): Whether or not workspace status stamping is enabled. For more details see
            https://docs.bazel.build/versions/main/user-manual.html#flag--stamp
        remap_path_prefix (str, optional): A value used to remap `${pwd}` to. If set to a falsey value, no prefix will be set.

    Returns:
        tuple: A tuple of the following items
            - (struct): A struct of arguments used to run the `Rustc` action
                - process_wrapper_flags (Args): Arguments for the process wrapper
                - rustc_path (Args): Arguments for invoking rustc via the process wrapper
                - rustc_flags (Args): Rust flags for the Rust compiler
                - all (list): A list of all `Args` objects in the order listed above.
                    This is to be passed to the `arguments` parameter of actions
            - (dict): Common rustc environment variables
    """
    output_dir = getattr(crate_info.output, "dirname", None)
    linker_script = getattr(file, "linker_script", None)

    env = _get_rustc_env(attr, toolchain, crate_info.name)

    # Wrapper args first
    process_wrapper_flags = ctx.actions.args()

    for build_env_file in build_env_files:
        process_wrapper_flags.add("--env-file", build_env_file)

    process_wrapper_flags.add_all(build_flags_files, before_each = "--arg-file")

    # Certain rust build processes expect to find files from the environment
    # variable `$CARGO_MANIFEST_DIR`. Examples of this include pest, tera,
    # asakuma.
    #
    # The compiler and by extension proc-macros see the current working
    # directory as the Bazel exec root. This is what `$CARGO_MANIFEST_DIR`
    # would default to but is often the wrong value (e.g. if the source is in a
    # sub-package or if we are building something in an external repository).
    # Hence, we need to set `CARGO_MANIFEST_DIR` explicitly.
    #
    # Since we cannot get the `exec_root` from starlark, we cheat a little and
    # use `${pwd}` which resolves the `exec_root` at action execution time.
    process_wrapper_flags.add("--subst", "pwd=${pwd}")

    # If stamping is enabled, enable the functionality in the process wrapper
    if stamp:
        process_wrapper_flags.add("--volatile-status-file", ctx.version_file)

    # Both ctx.label.workspace_root and ctx.label.package are relative paths
    # and either can be empty strings. Avoid trailing/double slashes in the path.
    components = "${{pwd}}/{}/{}".format(ctx.label.workspace_root, ctx.label.package).split("/")
    env["CARGO_MANIFEST_DIR"] = "/".join([c for c in components if c])

    if out_dir != None:
        env["OUT_DIR"] = "${pwd}/" + out_dir

    # Handle that the binary name and crate name may be different.
    #
    # If a target name contains a - then cargo (and rules_rust) will generate a
    # crate name with _ instead.  Accordingly, rustc will generate a output
    # file (executable, or rlib, or whatever) with _ not -.  But when cargo
    # puts a binary in the target/${config} directory, and sets environment
    # variables like `CARGO_BIN_EXE_${binary_name}` it will use the - version
    # not the _ version.  So we rename the rustc-generated file (with _s) to
    # have -s if needed.
    emit_with_paths = emit
    if crate_info.type == "bin" and crate_info.output != None:
        generated_file = crate_info.name + toolchain.binary_ext
        src = "/".join([crate_info.output.dirname, generated_file])
        dst = crate_info.output.path
        if src != dst:
            emit_with_paths = [("link=" + dst if val == "link" else val) for val in emit]

    # Arguments for launching rustc from the process wrapper
    rustc_path = ctx.actions.args()
    rustc_path.add("--")
    rustc_path.add(tool_path)

    # Rustc arguments
    rustc_flags = ctx.actions.args()
    rustc_flags.set_param_file_format("multiline")
    rustc_flags.use_param_file("@%s", use_always = False)
    rustc_flags.add(crate_info.root)
    rustc_flags.add("--crate-name=" + crate_info.name)
    rustc_flags.add("--crate-type=" + crate_info.type)
    if hasattr(attr, "_error_format"):
        rustc_flags.add("--error-format=" + attr._error_format[ErrorFormatInfo].error_format)

    # Mangle symbols to disambiguate crates with the same name
    extra_filename = "-" + output_hash if output_hash else ""
    rustc_flags.add("--codegen=metadata=" + extra_filename)
    if output_dir:
        rustc_flags.add("--out-dir=" + output_dir)
    rustc_flags.add("--codegen=extra-filename=" + extra_filename)

    compilation_mode = get_compilation_mode_opts(ctx, toolchain)
    rustc_flags.add("--codegen=opt-level=" + compilation_mode.opt_level)
    rustc_flags.add("--codegen=debuginfo=" + compilation_mode.debug_info)

    # For determinism to help with build distribution and such
    if remap_path_prefix:
        rustc_flags.add("--remap-path-prefix=${{pwd}}={}".format(remap_path_prefix))

    if emit:
        rustc_flags.add("--emit=" + ",".join(emit_with_paths))
    rustc_flags.add("--color=always")
    rustc_flags.add("--target=" + toolchain.target_flag_value)
    if hasattr(attr, "crate_features"):
        rustc_flags.add_all(getattr(attr, "crate_features"), before_each = "--cfg", format_each = 'feature="%s"')
    if linker_script:
        rustc_flags.add(linker_script.path, format = "--codegen=link-arg=-T%s")

    # Gets the paths to the folders containing the standard library (or libcore)
    rust_std_paths = toolchain.rust_std_paths.to_list()

    # Tell Rustc where to find the standard library
    rustc_flags.add_all(rust_std_paths, before_each = "-L", format_each = "%s")
    rustc_flags.add_all(rust_flags)

    # Deduplicate data paths due to https://github.com/bazelbuild/bazel/issues/14681
    data_paths = depset(direct = getattr(attr, "data", []) + getattr(attr, "compile_data", [])).to_list()

    rustc_flags.add_all(
        expand_list_element_locations(
            ctx,
            getattr(attr, "rustc_flags", []),
            data_paths,
        ),
    )
    add_edition_flags(rustc_flags, crate_info)

    # Link!
    if ("link" in emit and crate_info.type not in ["rlib", "lib"]) or force_link:
        # Rust's built-in linker can handle linking wasm files. We don't want to attempt to use the cc
        # linker since it won't understand.
        if toolchain.target_arch != "wasm32":
            if output_dir:
                rpaths = _compute_rpaths(toolchain, output_dir, dep_info)
            else:
                rpaths = depset([])
            ld, link_args, link_env = get_linker_and_args(ctx, attr, cc_toolchain, feature_configuration, rpaths)
            env.update(link_env)
            rustc_flags.add("--codegen=linker=" + ld)
            rustc_flags.add_joined("--codegen", link_args, join_with = " ", format_joined = "link-args=%s")

        _add_native_link_flags(rustc_flags, dep_info, linkstamp_outs, crate_info.type, toolchain, cc_toolchain, feature_configuration)

    # These always need to be added, even if not linking this crate.
    add_crate_link_flags(rustc_flags, dep_info, force_all_deps_direct)

    needs_extern_proc_macro_flag = "proc-macro" in [crate_info.type, crate_info.wrapped_crate_type] and \
                                   crate_info.edition != "2015"
    if needs_extern_proc_macro_flag:
        rustc_flags.add("--extern")
        rustc_flags.add("proc_macro")

    # Make bin crate data deps available to tests.
    for data in getattr(attr, "data", []):
        if rust_common.crate_info in data:
            dep_crate_info = data[rust_common.crate_info]
            if dep_crate_info.type == "bin":
                # Trying to make CARGO_BIN_EXE_{} canonical across platform by strip out extension if exists
                env_basename = dep_crate_info.output.basename[:-(1 + len(dep_crate_info.output.extension))] if len(dep_crate_info.output.extension) > 0 else dep_crate_info.output.basename
                env["CARGO_BIN_EXE_" + env_basename] = dep_crate_info.output.short_path

    # Update environment with user provided variables.
    env.update(expand_dict_value_locations(
        ctx,
        crate_info.rustc_env,
        data_paths,
    ))

    # Set the SYSROOT to the directory of the rust_std files passed to the toolchain
    env["SYSROOT"] = toolchain.sysroot

    env["RULES_RUST_RENAME_FIRST_PARTY_CRATES"] = str(toolchain._rename_first_party_crates).lower()
    env["RULES_RUST_THIRD_PARTY_DIR"] = str(toolchain._third_party_dir).lower()

    # extra_rustc_flags apply to the target configuration, not the exec configuration.
    if hasattr(ctx.attr, "_extra_rustc_flags") and not is_exec_configuration(ctx):
        rustc_flags.add_all(ctx.attr._extra_rustc_flags[ExtraRustcFlagsInfo].extra_rustc_flags)

    if hasattr(ctx.attr, "_extra_exec_rustc_flags") and is_exec_configuration(ctx):
        rustc_flags.add_all(ctx.attr._extra_exec_rustc_flags[ExtraExecRustcFlagsInfo].extra_exec_rustc_flags)

    # Create a struct which keeps the arguments separate so each may be tuned or
    # replaced where necessary
    args = struct(
        process_wrapper_flags = process_wrapper_flags,
        rustc_path = rustc_path,
        rustc_flags = rustc_flags,
        all = [process_wrapper_flags, rustc_path, rustc_flags],
    )

    return args, env

def rustc_compile_action(
        ctx,
        attr,
        toolchain,
        crate_info,
        output_hash = None,
        rust_flags = [],
        environ = {},
        force_all_deps_direct = False):
    """Create and run a rustc compile action based on the current rule's attributes

    Args:
        ctx (ctx): The rule's context object
        attr (struct): Attributes to use for the rust compile action
        toolchain (rust_toolchain): The current `rust_toolchain`
        crate_info (CrateInfo): The CrateInfo provider for the current target.
        output_hash (str, optional): The hashed path of the crate root. Defaults to None.
        rust_flags (list, optional): Additional flags to pass to rustc. Defaults to [].
        environ (dict, optional): A set of makefile expandable environment variables for the action
        force_all_deps_direct (bool, optional): Whether to pass the transitive rlibs with --extern
            to the commandline as opposed to -L.

    Returns:
        list: A list of the following providers:
            - (CrateInfo): info for the crate we just built; same as `crate_info` parameter.
            - (DepInfo): The transitive dependencies of this crate.
            - (DefaultInfo): The output file for this crate, and its runfiles.
    """
    cc_toolchain, feature_configuration = find_cc_toolchain(ctx)

    remove_transitive_libs_from_dep_info = toolchain._incompatible_remove_transitive_libs_from_dep_info

    dep_info, build_info, linkstamps = collect_deps(
        label = ctx.label,
        deps = crate_info.deps,
        proc_macro_deps = crate_info.proc_macro_deps,
        aliases = crate_info.aliases,
        are_linkstamps_supported = _are_linkstamps_supported(
            feature_configuration = feature_configuration,
            has_grep_includes = hasattr(ctx.attr, "_grep_includes"),
        ),
        remove_transitive_libs_from_dep_info = remove_transitive_libs_from_dep_info,
    )

    # Determine if the build is currently running with --stamp
    stamp = is_stamping_enabled(attr)

    compile_inputs, out_dir, build_env_files, build_flags_files, linkstamp_outs = collect_inputs(
        ctx = ctx,
        file = ctx.file,
        files = ctx.files,
        linkstamps = linkstamps,
        toolchain = toolchain,
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        crate_info = crate_info,
        dep_info = dep_info,
        build_info = build_info,
        stamp = stamp,
    )

    args, env_from_args = construct_arguments(
        ctx = ctx,
        attr = attr,
        file = ctx.file,
        toolchain = toolchain,
        tool_path = toolchain.rustc.path,
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        crate_info = crate_info,
        dep_info = dep_info,
        linkstamp_outs = linkstamp_outs,
        output_hash = output_hash,
        rust_flags = rust_flags,
        out_dir = out_dir,
        build_env_files = build_env_files,
        build_flags_files = build_flags_files,
        force_all_deps_direct = force_all_deps_direct,
        stamp = stamp,
    )

    env = dict(ctx.configuration.default_shell_env)
    env.update(env_from_args)

    if hasattr(attr, "version") and attr.version != "0.0.0":
        formatted_version = " v{}".format(attr.version)
    else:
        formatted_version = ""

    outputs = [crate_info.output]

    # For a cdylib that might be added as a dependency to a cc_* target on Windows, it is important to include the
    # interface library that rustc generates in the output files.
    interface_library = None
    if toolchain.os == "windows" and crate_info.type == "cdylib":
        # Rustc generates the import library with a `.dll.lib` extension rather than the usual `.lib` one that msvc
        # expects (see https://github.com/rust-lang/rust/pull/29520 for more context).
        interface_library = ctx.actions.declare_file(crate_info.output.basename + ".lib")
        outputs.append(interface_library)

    # The action might generate extra output that we don't want to include in the `DefaultInfo` files.
    action_outputs = list(outputs)

    # Rustc generates a pdb file (on Windows) or a dsym folder (on macos) so provide it in an output group for crate
    # types that benefit from having debug information in a separate file.
    pdb_file = None
    dsym_folder = None
    if crate_info.type in ("cdylib", "bin") and not crate_info.is_test:
        if toolchain.os == "windows":
            pdb_file = ctx.actions.declare_file(crate_info.output.basename[:-len(crate_info.output.extension)] + "pdb")
            action_outputs.append(pdb_file)
        elif toolchain.os == "darwin":
            dsym_folder = ctx.actions.declare_directory(crate_info.output.basename + ".dSYM")
            action_outputs.append(dsym_folder)

    ctx.actions.run(
        executable = ctx.executable._process_wrapper,
        inputs = compile_inputs,
        outputs = action_outputs,
        env = env,
        arguments = args.all,
        mnemonic = "Rustc",
        progress_message = "Compiling Rust {} {}{} ({} files)".format(
            crate_info.type,
            ctx.label.name,
            formatted_version,
            len(crate_info.srcs.to_list()),
        ),
    )

    runfiles = ctx.runfiles(
        files = getattr(ctx.files, "data", []),
        collect_data = True,
    )

    # TODO: Remove after some resolution to
    # https://github.com/bazelbuild/rules_rust/issues/771
    out_binary = getattr(attr, "out_binary", False)

    providers = [
        crate_info,
        dep_info,
        DefaultInfo(
            # nb. This field is required for cc_library to depend on our output.
            files = depset(outputs),
            runfiles = runfiles,
            executable = crate_info.output if crate_info.type == "bin" or crate_info.is_test or out_binary else None,
        ),
    ]
    if toolchain.target_arch != "wasm32":
        providers += establish_cc_info(ctx, attr, crate_info, toolchain, cc_toolchain, feature_configuration, interface_library)
    if pdb_file:
        providers.append(OutputGroupInfo(pdb_file = depset([pdb_file])))
    if dsym_folder:
        providers.append(OutputGroupInfo(dsym_folder = depset([dsym_folder])))

    return providers

def _is_dylib(dep):
    return not bool(dep.static_library or dep.pic_static_library)

def establish_cc_info(ctx, attr, crate_info, toolchain, cc_toolchain, feature_configuration, interface_library):
    """If the produced crate is suitable yield a CcInfo to allow for interop with cc rules

    Args:
        ctx (ctx): The rule's context object
        attr (struct): Attributes to use in gathering CcInfo
        crate_info (CrateInfo): The CrateInfo provider of the target crate
        toolchain (rust_toolchain): The current `rust_toolchain`
        cc_toolchain (CcToolchainInfo): The current `CcToolchainInfo`
        feature_configuration (FeatureConfiguration): Feature configuration to be queried.
        interface_library (File): Optional interface library for cdylib crates on Windows.

    Returns:
        list: A list containing the CcInfo provider
    """

    # A test will not need to produce CcInfo as nothing can depend on test targets
    if crate_info.is_test:
        return []

    # Only generate CcInfo for particular crate types
    if crate_info.type not in ("staticlib", "cdylib", "rlib", "lib"):
        return []

    # TODO: Remove after some resolution to
    # https://github.com/bazelbuild/rules_rust/issues/771
    if getattr(attr, "out_binary", False):
        return []

    if crate_info.type == "staticlib":
        library_to_link = cc_common.create_library_to_link(
            actions = ctx.actions,
            feature_configuration = feature_configuration,
            cc_toolchain = cc_toolchain,
            static_library = crate_info.output,
            # TODO(hlopko): handle PIC/NOPIC correctly
            pic_static_library = crate_info.output,
        )
    elif crate_info.type in ("rlib", "lib"):
        # bazel hard-codes a check for endswith((".a", ".pic.a",
        # ".lib")) in create_library_to_link, so we work around that
        # by creating a symlink to the .rlib with a .a extension.
        dot_a = make_static_lib_symlink(ctx.actions, crate_info.output)

        # TODO(hlopko): handle PIC/NOPIC correctly
        library_to_link = cc_common.create_library_to_link(
            actions = ctx.actions,
            feature_configuration = feature_configuration,
            cc_toolchain = cc_toolchain,
            static_library = dot_a,
            # TODO(hlopko): handle PIC/NOPIC correctly
            pic_static_library = dot_a,
        )
    elif crate_info.type == "cdylib":
        library_to_link = cc_common.create_library_to_link(
            actions = ctx.actions,
            feature_configuration = feature_configuration,
            cc_toolchain = cc_toolchain,
            dynamic_library = crate_info.output,
            interface_library = interface_library,
        )
    else:
        fail("Unexpected case")

    link_input = cc_common.create_linker_input(
        owner = ctx.label,
        libraries = depset([library_to_link]),
    )

    linking_context = cc_common.create_linking_context(
        # TODO - What to do for no_std?
        linker_inputs = depset([link_input]),
    )

    cc_infos = [
        CcInfo(linking_context = linking_context),
        toolchain.stdlib_linkflags,
    ]
    for dep in getattr(attr, "deps", []):
        if CcInfo in dep:
            cc_infos.append(dep[CcInfo])

    if crate_info.type in ("rlib", "lib") and toolchain.libstd_and_allocator_ccinfo:
        # TODO: if we already have an rlib in our deps, we could skip this
        cc_infos.append(toolchain.libstd_and_allocator_ccinfo)

    return [cc_common.merge_cc_infos(cc_infos = cc_infos)]

def add_edition_flags(args, crate):
    """Adds the Rust edition flag to an arguments object reference

    Args:
        args (Args): A reference to an Args object
        crate (CrateInfo): A CrateInfo provider
    """
    if crate.edition != "2015":
        args.add("--edition={}".format(crate.edition))

def _create_extra_input_args(ctx, file, build_info, dep_info):
    """Gather additional input arguments from transitive dependencies

    Args:
        ctx (ctx): The rule's context object
        file (struct): A struct containing files defined in label type attributes marked as `allow_single_file`.
        build_info (BuildInfo): The BuildInfo provider from the target Crate's set of inputs.
        dep_info (DepInfo): The Depinfo provider form the target Crate's set of inputs.

    Returns:
        tuple: A tuple of the following items:
            - (list): A list of all build info `OUT_DIR` File objects
            - (str): The `OUT_DIR` of the current build info
            - (File): An optional generated environment file from a `cargo_build_script` target
            - (list): All direct and transitive build flags from the current build info.
    """
    input_files = []

    # Arguments to the commandline line wrapper that are going to be used
    # to create the final command line
    out_dir = None
    build_env_file = None
    build_flags_files = []

    if build_info:
        out_dir = build_info.out_dir.path
        build_env_file = build_info.rustc_env
        build_flags_files.append(build_info.flags.path)
        build_flags_files.append(build_info.link_flags.path)
        input_files.append(build_info.out_dir)
        input_files.append(build_info.link_flags)

    return input_files, out_dir, build_env_file, build_flags_files

def _compute_rpaths(toolchain, output_dir, dep_info):
    """Determine the artifact's rpaths relative to the bazel root for runtime linking of shared libraries.

    Args:
        toolchain (rust_toolchain): The current `rust_toolchain`
        output_dir (str): The output directory of the current target
        dep_info (DepInfo): The current target's dependency info

    Returns:
        depset: A set of relative paths from the output directory to each dependency
    """

    # Windows has no rpath equivalent, so always return an empty depset.
    if toolchain.os == "windows":
        return depset([])

    dylibs = [
        get_preferred_artifact(lib)
        for linker_input in dep_info.transitive_noncrates.to_list()
        for lib in linker_input.libraries
        if _is_dylib(lib)
    ]
    if not dylibs:
        return depset([])

    # For darwin, dylibs compiled by Bazel will fail to be resolved at runtime
    # without a version of Bazel that includes
    # https://github.com/bazelbuild/bazel/pull/13427. This is known to not be
    # included in Bazel 4.1 and below.
    if toolchain.os != "linux" and toolchain.os != "darwin":
        fail("Runtime linking is not supported on {}, but found {}".format(
            toolchain.os,
            dep_info.transitive_noncrates,
        ))

    # Multiple dylibs can be present in the same directory, so deduplicate them.
    return depset([
        relativize(lib_dir, output_dir)
        for lib_dir in _get_dir_names(dylibs)
    ])

def _get_dir_names(files):
    """Returns a list of directory names from the given list of File objects

    Args:
        files (list): A list of File objects

    Returns:
        list: A list of directory names for all files
    """
    dirs = {}
    for f in files:
        dirs[f.dirname] = None
    return dirs.keys()

def add_crate_link_flags(args, dep_info, force_all_deps_direct = False):
    """Adds link flags to an Args object reference

    Args:
        args (Args): An arguments object reference
        dep_info (DepInfo): The current target's dependency info
        force_all_deps_direct (bool, optional): Whether to pass the transitive rlibs with --extern
            to the commandline as opposed to -L.
    """

    if force_all_deps_direct:
        args.add_all(
            depset(
                transitive = [
                    dep_info.direct_crates,
                    dep_info.transitive_crates,
                ],
            ),
            uniquify = True,
            map_each = _crate_to_link_flag,
        )
    else:
        # nb. Direct crates are linked via --extern regardless of their crate_type
        args.add_all(dep_info.direct_crates, map_each = _crate_to_link_flag)
    args.add_all(
        dep_info.transitive_crates,
        map_each = _get_crate_dirname,
        uniquify = True,
        format_each = "-Ldependency=%s",
    )

def _crate_to_link_flag(crate):
    """A helper macro used by `add_crate_link_flags` for adding crate link flags to a Arg object

    Args:
        crate (CrateInfo|AliasableDepInfo): A CrateInfo or an AliasableDepInfo provider

    Returns:
        list: Link flags for the given provider
    """

    # This is AliasableDepInfo, we should use the alias as a crate name
    if hasattr(crate, "dep"):
        name = crate.name
        crate_info = crate.dep
    else:
        name = crate.name
        crate_info = crate
    return ["--extern={}={}".format(name, crate_info.output.path)]

def _get_crate_dirname(crate):
    """A helper macro used by `add_crate_link_flags` for getting the directory name of the current crate's output path

    Args:
        crate (CrateInfo): A CrateInfo provider from the current rule

    Returns:
        str: The directory name of the the output File that will be produced.
    """
    return crate.output.dirname

def _portable_link_flags(lib):
    if lib.static_library or lib.pic_static_library:
        return ["-C", "link-arg=%s" % get_preferred_artifact(lib).path]
    elif _is_dylib(lib):
        # TODO: Consider switching dylibs to use -Clink-arg as above.
        return [
            "-Lnative=%s" % get_preferred_artifact(lib).dirname,
            "-ldylib=%s" % get_lib_name(get_preferred_artifact(lib)),
        ]

    return []

def _make_link_flags_windows(linker_input):
    ret = []
    for lib in linker_input.libraries:
        if lib.alwayslink:
            ret.extend(["-C", "link-arg=/WHOLEARCHIVE:%s" % get_preferred_artifact(lib).path])
        else:
            ret.extend(_portable_link_flags(lib))
    return ret

def _make_link_flags_darwin(linker_input):
    ret = []
    for lib in linker_input.libraries:
        if lib.alwayslink:
            ret.extend([
                "-C",
                ("link-arg=-Wl,-force_load,%s" % get_preferred_artifact(lib).path),
            ])
        else:
            ret.extend(_portable_link_flags(lib))
    return ret

def _make_link_flags_default(linker_input):
    ret = []
    for lib in linker_input.libraries:
        if lib.alwayslink:
            ret.extend([
                "-C",
                "link-arg=-Wl,--whole-archive",
                "-C",
                ("link-arg=%s" % get_preferred_artifact(lib).path),
                "-C",
                "link-arg=-Wl,--no-whole-archive",
            ])
        else:
            ret.extend(_portable_link_flags(lib))
    return ret

def _libraries_dirnames(linker_input):
    return [get_preferred_artifact(lib).dirname for lib in linker_input.libraries]

def _add_native_link_flags(args, dep_info, linkstamp_outs, crate_type, toolchain, cc_toolchain, feature_configuration):
    """Adds linker flags for all dependencies of the current target.

    Args:
        args (Args): The Args struct for a ctx.action
        dep_info (DepInfo): Dependency Info provider
        linkstamp_outs (list): Linkstamp outputs of native dependencies
        crate_type: Crate type of the current target
        toolchain (rust_toolchain): The current `rust_toolchain`
        cc_toolchain (CcToolchainInfo): The current `cc_toolchain`
        feature_configuration (FeatureConfiguration): feature configuration to use with cc_toolchain

    """
    if crate_type in ["lib", "rlib"]:
        return

    if toolchain.os == "windows":
        make_link_flags = _make_link_flags_windows
    elif toolchain.os.startswith("mac") or toolchain.os.startswith("darwin"):
        make_link_flags = _make_link_flags_darwin
    else:
        make_link_flags = _make_link_flags_default

    args.add_all(dep_info.transitive_noncrates, map_each = make_link_flags)

    for linkstamp_out in linkstamp_outs:
        args.add_all(["-C", "link-arg=%s" % linkstamp_out.path])

    if crate_type in ["dylib", "cdylib"]:
        # For shared libraries we want to link C++ runtime library dynamically
        # (for example libstdc++.so or libc++.so).
        args.add_all(
            cc_toolchain.dynamic_runtime_lib(feature_configuration = feature_configuration),
            map_each = _get_dirname,
            format_each = "-Lnative=%s",
        )
        args.add_all(
            cc_toolchain.dynamic_runtime_lib(feature_configuration = feature_configuration),
            map_each = get_lib_name,
            format_each = "-ldylib=%s",
        )
    else:
        # For all other crate types we want to link C++ runtime library statically
        # (for example libstdc++.a or libc++.a).
        args.add_all(
            cc_toolchain.static_runtime_lib(feature_configuration = feature_configuration),
            map_each = _get_dirname,
            format_each = "-Lnative=%s",
        )
        args.add_all(
            cc_toolchain.static_runtime_lib(feature_configuration = feature_configuration),
            map_each = get_lib_name,
            format_each = "-lstatic=%s",
        )

def _get_dirname(file):
    """A helper function for `_add_native_link_flags`.

    Args:
        file (File): The target file

    Returns:
        str: Directory name of `file`
    """
    return file.dirname

def _error_format_impl(ctx):
    """Implementation of the `error_format` rule

    Args:
        ctx (ctx): The rule's context object

    Returns:
        list: A list containing the ErrorFormatInfo provider
    """
    raw = ctx.build_setting_value
    if raw not in _error_format_values:
        fail("{} expected a value in `{}` but got `{}`".format(
            ctx.label,
            _error_format_values,
            raw,
        ))
    return [ErrorFormatInfo(error_format = raw)]

error_format = rule(
    doc = (
        "Change the [--error-format](https://doc.rust-lang.org/rustc/command-line-arguments.html#option-error-format) " +
        "flag from the command line with `--@rules_rust//:error_format`. See rustc documentation for valid values."
    ),
    implementation = _error_format_impl,
    build_setting = config.string(flag = True),
)

def _extra_rustc_flags_impl(ctx):
    return ExtraRustcFlagsInfo(extra_rustc_flags = ctx.build_setting_value)

extra_rustc_flags = rule(
    doc = (
        "Add additional rustc_flags from the command line with `--@rules_rust//:extra_rustc_flags`. " +
        "This flag should only be used for flags that need to be applied across the entire build. For options that " +
        "apply to individual crates, use the rustc_flags attribute on the individual crate's rule instead. NOTE: " +
        "These flags not applied to the exec configuration (proc-macros, cargo_build_script, etc); " +
        "use `--@rules_rust//:extra_exec_rustc_flags` to apply flags to the exec configuration."
    ),
    implementation = _extra_rustc_flags_impl,
    build_setting = config.string_list(flag = True),
)

def _extra_exec_rustc_flags_impl(ctx):
    return ExtraExecRustcFlagsInfo(extra_exec_rustc_flags = ctx.build_setting_value)

extra_exec_rustc_flags = rule(
    doc = (
        "Add additional rustc_flags in the exec configuration from the command line with `--@rules_rust//:extra_exec_rustc_flags`. " +
        "This flag should only be used for flags that need to be applied across the entire build. " +
        "These flags only apply to the exec configuration (proc-macros, cargo_build_script, etc)."
    ),
    implementation = _extra_exec_rustc_flags_impl,
    build_setting = config.string_list(flag = True),
)

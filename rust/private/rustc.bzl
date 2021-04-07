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

# buildifier: disable=module-docstring
load(
    "@bazel_tools//tools/build_defs/cc:action_names.bzl",
    "CPP_LINK_EXECUTABLE_ACTION_NAME",
)
load("//rust/private:common.bzl", "rust_common")
load(
    "//rust/private:utils.bzl",
    "crate_name_from_attr",
    "expand_locations",
    "find_cc_toolchain",
    "get_lib_name",
    "get_preferred_artifact",
    "relativize",
)

BuildInfo = provider(
    doc = "A provider containing `rustc` build settings for a given Crate.",
    fields = {
        "dep_env": "File: extra build script environment varibles to be set to direct dependencies.",
        "flags": "File: file containing additional flags to pass to rustc",
        "link_flags": "File: file containing flags to pass to the linker",
        "out_dir": "File: directory containing the result of a build script",
        "rustc_env": "File: file containing additional environment variables to set for rustc.",
    },
)

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

def _get_rustc_env(attr, toolchain):
    """Gathers rustc environment variables

    Args:
        attr (struct): The current target's attributes
        toolchain (rust_toolchain): The current target's rust toolchain context

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
        "CARGO_CRATE_NAME": crate_name_from_attr(attr),
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

def collect_deps(label, deps, proc_macro_deps, aliases, toolchain):
    """Walks through dependencies and collects the transitive dependencies.

    Args:
        label (str): Label of the current target.
        deps (list): The deps from ctx.attr.deps.
        proc_macro_deps (list): The proc_macro deps from ctx.attr.proc_macro_deps.
        aliases (dict): A dict mapping aliased targets to their actual Crate information.
        toolchain (rust_toolchain): The current `rust_toolchain`.

    Returns:
        tuple: Returns a tuple (DepInfo, BuildInfo) of providers.
    """
    direct_crates = []
    transitive_crates = []
    transitive_noncrates = []
    transitive_noncrate_libs = []
    transitive_build_infos = []
    build_info = None

    aliases = {k.label: v for k, v in aliases.items()}
    for dep in depset(transitive = [deps, proc_macro_deps]).to_list():
        if rust_common.crate_info in dep:
            # This dependency is a rust_library
            direct_dep = dep[rust_common.crate_info]
            direct_crates.append(AliasableDepInfo(
                name = aliases.get(dep.label, direct_dep.name),
                dep = direct_dep,
            ))

            transitive_crates.append(depset([dep[rust_common.crate_info]], transitive = [dep[rust_common.dep_info].transitive_crates]))
            transitive_noncrates.append(dep[rust_common.dep_info].transitive_noncrates)
            transitive_noncrate_libs.append(depset(dep[rust_common.dep_info].transitive_libs))
            transitive_build_infos.append(dep[rust_common.dep_info].transitive_build_infos)
        elif CcInfo in dep:
            # This dependency is a cc_library

            # TODO: We could let the user choose how to link, instead of always preferring to link static libraries.
            linker_inputs = dep[CcInfo].linking_context.linker_inputs.to_list()
            libs = [get_preferred_artifact(lib) for li in linker_inputs for lib in li.libraries]
            transitive_noncrate_libs.append(depset(libs))
            transitive_noncrates.append(dep[CcInfo].linking_context.linker_inputs)
        elif BuildInfo in dep:
            if build_info:
                fail("Several deps are providing build information, only one is allowed in the dependencies", "deps")
            build_info = dep[BuildInfo]
            transitive_build_infos.append(depset([build_info]))
        else:
            fail("rust targets can only depend on rust_library, rust_*_library or cc_library targets." + str(dep), "deps")

    transitive_crates_depset = depset(transitive = transitive_crates)
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
            transitive_libs = transitive_libs,
            transitive_build_infos = depset(transitive = transitive_build_infos),
            dep_env = build_info.dep_env if build_info else None,
        ),
        build_info,
    )

def get_cc_user_link_flags(ctx):
    """Get the current target's linkopt flags

    Args:
        ctx (ctx): The current rule's context object

    Returns:
        depset: The flags passed to Bazel by --linkopt option.
    """
    return ctx.fragments.cpp.linkopts

def get_linker_and_args(ctx, cc_toolchain, feature_configuration, rpaths):
    """Gathers cc_common linker information

    Args:
        ctx (ctx): The current target's context object
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
        toolchain,
        cc_toolchain,
        crate_info,
        dep_info,
        build_info):
    """Gather's the inputs and required input information for a rustc action

    Args:
        ctx (ctx): The rule's context object.
        file (struct): A struct containing files defined in label type attributes marked as `allow_single_file`.
        files (list): A list of all inputs.
        toolchain (rust_toolchain): The current `rust_toolchain`.
        cc_toolchain (CcToolchainInfo): The current `cc_toolchain`.
        crate_info (CrateInfo): The Crate information of the crate to process build scripts for.
        dep_info (DepInfo): The target Crate's dependency information.
        build_info (BuildInfo): The target Crate's build settings.

    Returns:
        tuple: See `_process_build_scripts`
    """
    linker_script = getattr(file, "linker_script") if hasattr(file, "linker_script") else None

    linker_depset = cc_toolchain.all_files

    compile_inputs = depset(
        getattr(files, "data", []) +
        getattr(files, "compile_data", []) +
        [toolchain.rustc] +
        toolchain.crosstool_files +
        ([build_info.rustc_env, build_info.flags] if build_info else []) +
        ([] if linker_script == None else [linker_script]),
        transitive = [
            toolchain.rustc_lib.files,
            toolchain.rust_lib.files,
            linker_depset,
            crate_info.srcs,
            dep_info.transitive_libs,
        ],
    )
    build_env_files = getattr(files, "rustc_env_files", [])
    compile_inputs, out_dir, build_env_file, build_flags_files = _process_build_scripts(ctx, file, crate_info, build_info, dep_info, compile_inputs)
    if build_env_file:
        build_env_files = [f for f in build_env_files] + [build_env_file]
    compile_inputs = depset(build_env_files, transitive = [compile_inputs])
    return compile_inputs, out_dir, build_env_files, build_flags_files

def construct_arguments(
        ctx,
        attr,
        file,
        toolchain,
        tool_path,
        cc_toolchain,
        feature_configuration,
        crate_type,
        crate_info,
        dep_info,
        output_hash,
        rust_flags,
        out_dir,
        build_env_files,
        build_flags_files,
        maker_path = None,
        emit = ["dep-info", "link"]):
    """Builds an Args object containing common rustc flags

    Args:
        ctx (ctx): The rule's context object
        attr (struct): The attributes for the target. These may be different from ctx.attr in an aspect context.
        file (struct): A struct containing files defined in label type attributes marked as `allow_single_file`.
        toolchain (rust_toolchain): The current target's `rust_toolchain`
        tool_path (str): Path to rustc
        cc_toolchain (CcToolchain): The CcToolchain for the current target.
        feature_configuration (FeatureConfiguration): Class used to construct command lines from CROSSTOOL features.
        crate_type (str): Crate type of the current target.
        crate_info (CrateInfo): The CrateInfo provider of the target crate
        dep_info (DepInfo): The DepInfo provider of the target crate
        output_hash (str): The hashed path of the crate root
        rust_flags (list): Additional flags to pass to rustc
        out_dir (str): The path to the output directory for the target Crate.
        build_env_files (list): Files containing rustc environment variables, for instance from `cargo_build_script` actions.
        build_flags_files (list): The output files of a `cargo_build_script` actions containing rustc build flags
        maker_path (File): An optional clippy marker file
        emit (list): Values for the --emit flag to rustc.

    Returns:
        tuple: A tuple of the following items
            - (Args): An Args object with common Rust flags
            - (dict): Common rustc environment variables
    """
    output_dir = getattr(crate_info.output, "dirname") if hasattr(crate_info.output, "dirname") else None

    linker_script = getattr(file, "linker_script") if hasattr(file, "linker_script") else None

    env = _get_rustc_env(attr, toolchain)

    # Wrapper args first
    args = ctx.actions.args()

    for build_env_file in build_env_files:
        args.add("--env-file", build_env_file)

    args.add_all(build_flags_files, before_each = "--arg-file")

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
    args.add("--subst", "pwd=${pwd}")

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

    if maker_path != None:
        args.add("--touch-file", maker_path)

    args.add("--")
    args.add(tool_path)

    # Rustc arguments
    args.add(crate_info.root)
    args.add("--crate-name=" + crate_info.name)
    args.add("--crate-type=" + crate_info.type)
    if hasattr(attr, "_error_format"):
        args.add("--error-format=" + attr._error_format[ErrorFormatInfo].error_format)

    # Mangle symbols to disambiguate crates with the same name
    extra_filename = "-" + output_hash if output_hash else ""
    args.add("--codegen=metadata=" + extra_filename)
    if output_dir:
        args.add("--out-dir=" + output_dir)
    args.add("--codegen=extra-filename=" + extra_filename)

    compilation_mode = get_compilation_mode_opts(ctx, toolchain)
    args.add("--codegen=opt-level=" + compilation_mode.opt_level)
    args.add("--codegen=debuginfo=" + compilation_mode.debug_info)

    # For determinism to help with build distribution and such
    args.add("--remap-path-prefix=${pwd}=.")

    args.add("--emit=" + ",".join(emit_with_paths))
    args.add("--color=always")
    args.add("--target=" + toolchain.target_triple)
    if hasattr(attr, "crate_features"):
        args.add_all(getattr(attr, "crate_features"), before_each = "--cfg", format_each = 'feature="%s"')
    if linker_script:
        args.add(linker_script.path, format = "--codegen=link-arg=-T%s")

    # Gets the paths to the folders containing the standard library (or libcore)
    rust_lib_paths = depset([file.dirname for file in toolchain.rust_lib.files.to_list()]).to_list()

    # Tell Rustc where to find the standard library
    args.add_all(rust_lib_paths, before_each = "-L", format_each = "%s")

    args.add_all(rust_flags)
    args.add_all(getattr(attr, "rustc_flags", []))
    add_edition_flags(args, crate_info)

    # Link!
    if "link" in emit:
        # Rust's built-in linker can handle linking wasm files. We don't want to attempt to use the cc
        # linker since it won't understand.
        if toolchain.target_arch != "wasm32":
            rpaths = _compute_rpaths(toolchain, output_dir, dep_info)
            ld, link_args, link_env = get_linker_and_args(ctx, cc_toolchain, feature_configuration, rpaths)
            env.update(link_env)
            args.add("--codegen=linker=" + ld)
            args.add_joined("--codegen", link_args, join_with = " ", format_joined = "link-args=%s")

        _add_native_link_flags(args, dep_info, crate_type, toolchain, cc_toolchain, feature_configuration)

    # These always need to be added, even if not linking this crate.
    add_crate_link_flags(args, dep_info)

    if crate_info.type == "proc-macro" and crate_info.edition != "2015":
        args.add("--extern")
        args.add("proc_macro")

    # Make bin crate data deps available to tests.
    for data in getattr(attr, "data", []):
        if rust_common.crate_info in data:
            dep_crate_info = data[rust_common.crate_info]
            if dep_crate_info.type == "bin":
                env["CARGO_BIN_EXE_" + dep_crate_info.output.basename] = dep_crate_info.output.short_path

    # Update environment with user provided variables.
    env.update(expand_locations(
        ctx,
        crate_info.rustc_env,
        getattr(attr, "data", []) +
        getattr(attr, "compile_data", []),
    ))

    # This empty value satisfies Clippy, which otherwise complains about the
    # sysroot being undefined.
    env["SYSROOT"] = ""

    return args, env

def rustc_compile_action(
        ctx,
        toolchain,
        crate_type,
        crate_info,
        output_hash = None,
        rust_flags = [],
        environ = {}):
    """Create and run a rustc compile action based on the current rule's attributes

    Args:
        ctx (ctx): The rule's context object
        toolchain (rust_toolchain): The current `rust_toolchain`
        crate_type (str): Crate type of the current target
        crate_info (CrateInfo): The CrateInfo provider for the current target.
        output_hash (str, optional): The hashed path of the crate root. Defaults to None.
        rust_flags (list, optional): Additional flags to pass to rustc. Defaults to [].
        environ (dict, optional): A set of makefile expandable environment variables for the action

    Returns:
        list: A list of the following providers:
            - (CrateInfo): info for the crate we just built; same as `crate_info` parameter.
            - (DepInfo): The transitive dependencies of this crate.
            - (DefaultInfo): The output file for this crate, and its runfiles.
    """
    cc_toolchain, feature_configuration = find_cc_toolchain(ctx)

    dep_info, build_info = collect_deps(
        ctx.label,
        crate_info.deps,
        crate_info.proc_macro_deps,
        crate_info.aliases,
        toolchain,
    )

    compile_inputs, out_dir, build_env_files, build_flags_files = collect_inputs(
        ctx,
        ctx.file,
        ctx.files,
        toolchain,
        cc_toolchain,
        crate_info,
        dep_info,
        build_info,
    )

    args, env = construct_arguments(
        ctx,
        ctx.attr,
        ctx.file,
        toolchain,
        toolchain.rustc.path,
        cc_toolchain,
        feature_configuration,
        crate_type,
        crate_info,
        dep_info,
        output_hash,
        rust_flags,
        out_dir,
        build_env_files,
        build_flags_files,
    )

    if hasattr(ctx.attr, "version") and ctx.attr.version != "0.0.0":
        formatted_version = " v{}".format(ctx.attr.version)
    else:
        formatted_version = ""

    ctx.actions.run(
        executable = ctx.executable._process_wrapper,
        inputs = compile_inputs,
        outputs = [crate_info.output],
        env = env,
        arguments = [args],
        mnemonic = "Rustc",
        progress_message = "Compiling Rust {} {}{} ({} files)".format(
            crate_info.type,
            ctx.label.name,
            formatted_version,
            len(crate_info.srcs.to_list()),
        ),
    )

    dylibs = [get_preferred_artifact(lib) for linker_input in dep_info.transitive_noncrates.to_list() for lib in linker_input.libraries if _is_dylib(lib)]

    runfiles = ctx.runfiles(
        files = dylibs + getattr(ctx.files, "data", []),
        collect_data = True,
    )

    out_binary = False
    if hasattr(ctx.attr, "out_binary"):
        out_binary = getattr(ctx.attr, "out_binary")

    return establish_cc_info(ctx, crate_info, toolchain, cc_toolchain, feature_configuration) + [
        crate_info,
        dep_info,
        DefaultInfo(
            # nb. This field is required for cc_library to depend on our output.
            files = depset([crate_info.output]),
            runfiles = runfiles,
            executable = crate_info.output if crate_info.type == "bin" or crate_info.is_test or out_binary else None,
        ),
    ]

def _is_dylib(dep):
    return not bool(dep.static_library or dep.pic_static_library)

def establish_cc_info(ctx, crate_info, toolchain, cc_toolchain, feature_configuration):
    """If the produced crate is suitable yield a CcInfo to allow for interop with cc rules

    Args:
        ctx (ctx): The rule's context object
        crate_info (CrateInfo): The CrateInfo provider of the target crate
        toolchain (rust_toolchain): The current `rust_toolchain`
        cc_toolchain (CcToolchainInfo): The current `CcToolchainInfo`
        feature_configuration (FeatureConfiguration): Feature configuration to be queried.

    Returns:
        list: A list containing the CcInfo provider
    """

    if crate_info.is_test or crate_info.type not in ("staticlib", "cdylib", "rlib", "lib") or getattr(ctx.attr, "out_binary", False):
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
        dot_a = ctx.actions.declare_file(crate_info.name + ".a", sibling = crate_info.output)
        ctx.actions.symlink(output = dot_a, target_file = crate_info.output)

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
        )
    else:
        fail("Unexpected case")

    link_input = cc_common.create_linker_input(
        owner = ctx.label,
        libraries = depset([library_to_link]),
        user_link_flags = depset(toolchain.stdlib_linkflags),
    )

    linking_context = cc_common.create_linking_context(
        # TODO - What to do for no_std?
        linker_inputs = depset([link_input]),
    )

    cc_infos = [CcInfo(linking_context = linking_context)]
    for dep in ctx.attr.deps:
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
    preferreds = [get_preferred_artifact(lib) for linker_input in dep_info.transitive_noncrates.to_list() for lib in linker_input.libraries]

    # TODO(augie): I don't understand why this can't just be filtering on
    # _is_dylib(lib), but doing that causes failures on darwin and windows
    # examples that otherwise work.
    dylibs = [lib for lib in preferreds if lib.basename.endswith(toolchain.dylib_ext) or lib.basename.split(".", 2)[1] == toolchain.dylib_ext[1:]]
    if not dylibs:
        return depset([])
    if toolchain.os != "linux":
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

def add_crate_link_flags(args, dep_info):
    """Adds link flags to an Args object reference

    Args:
        args (Args): An arguments object reference
        dep_info (DepInfo): The current target's dependency info
    """

    # nb. Crates are linked via --extern regardless of their crate_type
    args.add_all(dep_info.direct_crates, map_each = _crate_to_link_flag)
    args.add_all(
        dep_info.transitive_crates,
        map_each = _get_crate_dirname,
        uniquify = True,
        format_each = "-Ldependency=%s",
    )

def _crate_to_link_flag(crate_info):
    """A helper macro used by `add_crate_link_flags` for adding crate link flags to a Arg object

    Args:
        crate_info (CrateInfo): A CrateInfo provider from the current rule

    Returns:
        list: Link flags for the current crate info
    """
    return ["--extern", "{}={}".format(crate_info.name, crate_info.dep.output.path)]

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
        return ["-lstatic=%s" % get_lib_name(get_preferred_artifact(lib))]
    elif _is_dylib(lib):
        return ["-ldylib=%s" % get_lib_name(get_preferred_artifact(lib))]
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

def _add_native_link_flags(args, dep_info, crate_type, toolchain, cc_toolchain, feature_configuration):
    """Adds linker flags for all dependencies of the current target.

    Args:
        args (Args): The Args struct for a ctx.action
        dep_info (DepInfo): Dependency Info provider
        crate_type: Crate type of the current target
        toolchain (rust_toolchain): The current `rust_toolchain`
        cc_toolchain (CcToolchainInfo): The current `cc_toolchain`
        feature_configuration (FeatureConfiguration): feature configuration to use with cc_toolchain

    """
    args.add_all(dep_info.transitive_noncrates, map_each = _libraries_dirnames, uniquify = True, format_each = "-Lnative=%s")

    if crate_type in ["lib", "rlib"]:
        return

    if toolchain.os == "windows":
        make_link_flags = _make_link_flags_windows
    elif toolchain.os.startswith("mac") or toolchain.os.startswith("darwin"):
        make_link_flags = _make_link_flags_darwin
    else:
        make_link_flags = _make_link_flags_default

    args.add_all(dep_info.transitive_noncrates, map_each = make_link_flags)

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
        "A helper rule for controlling the rustc " +
        "[--error-format](https://doc.rust-lang.org/rustc/command-line-arguments.html#option-error-format) " +
        "flag."
    ),
    implementation = _error_format_impl,
    build_setting = config.string(flag = True),
)

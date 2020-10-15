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

load("@bazel_skylib//lib:versions.bzl", "versions")
load(
    "@bazel_tools//tools/build_defs/cc:action_names.bzl",
    "CPP_LINK_EXECUTABLE_ACTION_NAME",
    "C_COMPILE_ACTION_NAME",
)
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@bazel_version//:def.bzl", "BAZEL_VERSION")
load("@io_bazel_rules_rust//rust:private/legacy_cc_starlark_api_shim.bzl", "get_libs_for_static_executable")
load("@io_bazel_rules_rust//rust:private/utils.bzl", "get_lib_name", "relativize")

CrateInfo = provider(
    doc = "A provider containing general Crate information.",
    fields = {
        "name": "str: The name of this crate.",
        "type": "str: The type of this crate. eg. lib or bin",
        "root": "File: The source File entrypoint to this crate, eg. lib.rs",
        "srcs": "List[File]: All source Files that are part of the crate.",
        "deps": "List[Provider]: This crate's (rust or cc) dependencies' providers.",
        "proc_macro_deps": "List[CrateInfo]: This crate's rust proc_macro dependencies' providers.",
        "aliases": "Dict[Label, String]: Renamed and aliased crates",
        "output": "File: The output File that will be produced, depends on crate type.",
        "edition": "str: The edition of this crate.",
        "rustc_env": "Dict[String, String]: Additional `\"key\": \"value\"` environment variables to set for rustc.",
        "is_test": "bool: If the crate is being compiled in a test context",
    },
)

BuildInfo = provider(
    doc = "A provider containing `rustc` build settings for a given Crate.",
    fields = {
        "flags": "File: file containing additional flags to pass to rustc",
        "out_dir": "File: directory containing the result of a build script",
        "rustc_env": "File: file containing additional environment variables to set for rustc.",
        "dep_env": "File: extra build script environment varibles to be set to direct dependencies.",
        "link_flags": "File: file containing flags to pass to the linker",
    },
)

AliasableDepInfo = provider(
    doc = "A provider mapping an alias name to a Crate's information.",
    fields = {
        "name": "str",
        "dep": "CrateInfo",
    },
)

DepInfo = provider(
    doc = "A provider contianing information about a Crate's dependencies.",
    fields = {
        "direct_crates": "depset[CrateInfo]",
        "transitive_crates": "depset[CrateInfo]",
        "transitive_dylibs": "depset[File]",
        "transitive_staticlibs": "depset[File]",
        "transitive_libs": "List[File]: All transitive dependencies, not filtered by type.",
        "transitive_build_infos": "depset[BuildInfo]",
        "dep_env": "File: File with environment variables direct dependencies build scripts rely upon.",
    },
)

def _get_rustc_env(ctx, toolchain):
    """Gathers rustc environment variables

    Args:
        ctx (ctx): The current target's rule context object
        toolchain (rust_toolchain): The current target's rust toolchain context

    Returns:
        dict: Rustc environment variables
    """
    version = ctx.attr.version if hasattr(ctx.attr, "version") else "0.0.0"
    major, minor, patch = version.split(".", 2)
    if "-" in patch:
        patch, pre = patch.split("-", 1)
    else:
        pre = ""
    return {
        "CARGO_CFG_TARGET_ARCH": toolchain.target_arch,
        "CARGO_CFG_TARGET_OS": toolchain.os,
        "CARGO_PKG_AUTHORS": "",
        "CARGO_PKG_DESCRIPTION": "",
        "CARGO_PKG_HOMEPAGE": "",
        "CARGO_PKG_NAME": ctx.label.name,
        "CARGO_PKG_VERSION_MAJOR": major,
        "CARGO_PKG_VERSION_MINOR": minor,
        "CARGO_PKG_VERSION_PATCH": patch,
        "CARGO_PKG_VERSION_PRE": pre,
        "CARGO_PKG_VERSION": version,
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

    for dep in deps:
        if CrateInfo in dep:
            if dep[CrateInfo].type == "proc-macro":
                fail(
                    "{} listed {} in its deps, but it is a proc-macro. It should instead be in the bazel property proc_macro_deps.".format(
                        label,
                        dep.label,
                    ),
                )
    for dep in proc_macro_deps:
        type = dep[CrateInfo].type
        if type != "proc-macro":
            fail(
                "{} listed {} in its proc_macro_deps, but it is not proc-macro, it is a {}. It should probably instead be listed in deps.".format(
                    label,
                    dep.label,
                    type,
                ),
            )

    # TODO: Fix depset union (https://docs.bazel.build/versions/master/skylark/depsets.html)
    direct_crates = []
    transitive_crates = depset()
    transitive_dylibs = depset(order = "topological")  # dylib link flag ordering matters.
    transitive_staticlibs = depset()
    transitive_build_infos = depset()
    build_info = None

    aliases = {k.label: v for k, v in aliases.items()}
    for dep in deps + proc_macro_deps:
        if CrateInfo in dep:
            # This dependency is a rust_library
            direct_dep = dep[CrateInfo]
            aliasable_dep = AliasableDepInfo(
                name = aliases.get(dep.label, direct_dep.name),
                dep = direct_dep,
            )
            direct_crates.append(aliasable_dep)
            transitive_crates = depset([dep[CrateInfo]], transitive = [transitive_crates])
            transitive_crates = depset(transitive = [transitive_crates, dep[DepInfo].transitive_crates])
            transitive_dylibs = depset(transitive = [transitive_dylibs, dep[DepInfo].transitive_dylibs])
            transitive_staticlibs = depset(transitive = [transitive_staticlibs, dep[DepInfo].transitive_staticlibs])
            transitive_build_infos = depset(transitive = [transitive_build_infos, dep[DepInfo].transitive_build_infos])
        elif CcInfo in dep:
            # This dependency is a cc_library

            # TODO: We could let the user choose how to link, instead of always preferring to link static libraries.
            libs = get_libs_for_static_executable(dep)
            dylibs = [lib for lib in libs.to_list() if lib.basename.endswith(toolchain.dylib_ext)]
            staticlibs = [lib for lib in libs.to_list() if lib.basename.endswith(toolchain.staticlib_ext)]
            transitive_dylibs = depset(transitive = [transitive_dylibs, depset(dylibs)])
            transitive_staticlibs = depset(transitive = [transitive_staticlibs, depset(staticlibs)])
        elif BuildInfo in dep:
            if build_info:
                fail("Several deps are providing build information, only one is allowed in the dependencies", "deps")
            build_info = dep[BuildInfo]
            transitive_build_infos = depset([build_info], transitive = [transitive_build_infos])
        else:
            fail("rust targets can only depend on rust_library, rust_*_library or cc_library targets." + str(dep), "deps")

    transitive_libs = depset(
        [c.output for c in transitive_crates.to_list()],
        transitive = [transitive_staticlibs, transitive_dylibs],
    )

    return (
        DepInfo(
            direct_crates = depset(direct_crates),
            transitive_crates = transitive_crates,
            transitive_dylibs = transitive_dylibs,
            transitive_staticlibs = transitive_staticlibs,
            transitive_libs = transitive_libs.to_list(),
            transitive_build_infos = transitive_build_infos,
            dep_env = build_info.dep_env if build_info else None,
        ),
        build_info,
    )

def get_cc_toolchain(ctx):
    """Extracts a CcToolchain from the current target's context

    Args:
        ctx (ctx): The current target's rule context object

    Returns:
        tuple: A tuple of (CcToolchain, FeatureConfiguration)
    """
    cc_toolchain = find_cpp_toolchain(ctx)

    kwargs = {
        "ctx": ctx,
    } if len(BAZEL_VERSION) == 0 or versions.is_at_least(
        "0.25.0",
        BAZEL_VERSION,
    ) else {}
    feature_configuration = cc_common.configure_features(
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
        **kwargs
    )
    return cc_toolchain, feature_configuration

def get_cc_compile_env(cc_toolchain, feature_configuration):
    compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
    )
    return cc_common.get_environment_variables(
        feature_configuration = feature_configuration,
        action_name = C_COMPILE_ACTION_NAME,
        variables = compile_variables,
    )

def get_cc_user_link_flags(ctx):
    """Get the current target's linkopt flags

    Args:
        ctx (ctx): The current rule's context object

    Returns:
        depset: The flags passed to Bazel by --linkopt option.
    """
    if (len(BAZEL_VERSION) == 0 or
        versions.is_at_least("0.18.0", BAZEL_VERSION)):
        return ctx.fragments.cpp.linkopts
    else:
        return depset(ctx.fragments.cpp.linkopts)

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
            - (str): An optional path to a generated environment file from a `cargo_build_script` target
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
        crate_info,
        dep_info,
        build_info):
    """Gather's the inputs and required input information for a rustc action

    Args:
        ctx (ctx): The rule's context object
        file (struct): A struct containing files defined in label type attributes marked as `allow_single_file`.
        files (list): A list of all inputs
        toolchain (rust_toolchain): The current `rust_toolchain`
        crate_info (CrateInfo): The Crate information of the crate to process build scripts for.
        dep_info (DepInfo): The target Crate's dependency information.
        build_info (BuildInfo): The target Crate's build settings.

    Returns:
        tuple: See `_process_build_scripts`
    """
    linker_script = getattr(file, "linker_script") if hasattr(file, "linker_script") else None

    if (len(BAZEL_VERSION) == 0 or
        versions.is_at_least("0.25.0", BAZEL_VERSION)):
        linker_depset = find_cpp_toolchain(ctx).all_files
    else:
        linker_depset = depset(files._cc_toolchain)

    compile_inputs = depset(
        crate_info.srcs +
        getattr(files, "data", []) +
        dep_info.transitive_libs +
        [toolchain.rustc] +
        toolchain.crosstool_files +
        ([build_info.rustc_env, build_info.flags] if build_info else []) +
        ([] if linker_script == None else [linker_script]),
        transitive = [
            toolchain.rustc_lib.files,
            toolchain.rust_lib.files,
            linker_depset,
        ],
    )
    return _process_build_scripts(ctx, file, crate_info, build_info, dep_info, compile_inputs)

def construct_arguments(
        ctx,
        file,
        toolchain,
        tool_path,
        cc_toolchain,
        feature_configuration,
        crate_info,
        dep_info,
        output_hash,
        rust_flags,
        out_dir,
        build_env_file,
        build_flags_files,
        maker_path = None):
    """Builds an Args object containing common rustc flags

    Args:
        ctx (ctx): The rule's context object
        file (struct): A struct containing files defined in label type attributes marked as `allow_single_file`.
        toolchain (rust_toolchain): The current target's `rust_toolchain`
        tool_path (str): Path to rustc
        cc_toolchain (CcToolchain): The CcToolchain for the current target.
        feature_configuration (FeatureConfiguration): Class used to construct command lines from CROSSTOOL features.
        crate_info (CrateInfo): The CrateInfo provider of the target crate
        dep_info (DepInfo): The DepInfo provider of the target crate
        output_hash (str): The hashed path of the crate root
        rust_flags (list): Additional flags to pass to rustc
        out_dir (str): The path to the output directory for the target Crate.
        build_env_file (str): The output file of a `cargo_build_script` action containing rustc environment variables
        build_flags_files (list): The output files of a `cargo_build_script` actions containing rustc build flags
        maker_path (File): An optional clippy marker file

    Returns:
        tuple: A tuple of the following items
            - (Args): An Args object with common Rust flags
            - (dict): Common rustc environment variables
    """
    output_dir = getattr(crate_info.output, "dirname") if hasattr(crate_info.output, "dirname") else None

    linker_script = getattr(file, "linker_script") if hasattr(file, "linker_script") else None

    env = _get_rustc_env(ctx, toolchain)

    # Wrapper args first
    args = ctx.actions.args()

    if build_env_file != None:
        args.add("--env-file", build_env_file)

    args.add_all(build_flags_files, before_each = "--arg-file")

    # Certain rust build processes expect to find files from the environment variable
    # `$CARGO_MANIFEST_DIR`. Examples of this include pest, tera, asakuma.
    #
    # The compiler and by extension proc-macros see the current working directory as the Bazel exec
    # root. Therefore, in order to fix this without an upstream code change, we have to set
    # `$CARGO_MANIFEST_DIR`.
    #
    # As such we attempt to infer `$CARGO_MANIFEST_DIR`.
    # Inference cannot be derived from `attr.crate_root`, as this points at a source file which may or
    # may not follow the `src/lib.rs` convention. As such we use `ctx.build_file_path` mapped into the
    # `exec_root`. Since we cannot (seemingly) get the `exec_root` from starlark, we cheat a little
    # and use `${pwd}` which resolves the `exec_root` at action execution time.
    args.add("--subst", "pwd=${pwd}")

    env["CARGO_MANIFEST_DIR"] = "${pwd}/" + ctx.build_file_path[:ctx.build_file_path.rfind("/")]

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
    maybe_rename = ""
    if crate_info.type == "bin" and crate_info.output != None:
        generated_file = crate_info.name + toolchain.binary_ext
        src = "/".join([crate_info.output.dirname, generated_file])
        dst = crate_info.output.path
        if src != dst:
            args.add_all(["--copy-output", src, dst])

    if maker_path != None:
        args.add("--touch-file", maker_path)

    args.add("--")
    args.add(tool_path)

    # Rustc arguments
    args.add(crate_info.root)
    args.add("--crate-name=" + crate_info.name)
    args.add("--crate-type=" + crate_info.type)

    # Mangle symbols to disambiguate crates with the same name
    extra_filename = "-" + output_hash if output_hash else ""
    args.add("--codegen=metadata=" + extra_filename)
    if output_dir:
        args.add("--out-dir=" + output_dir)
    args.add("--codegen=extra-filename=" + extra_filename)

    compilation_mode = get_compilation_mode_opts(ctx, toolchain)
    args.add("--codegen=opt-level=" + compilation_mode.opt_level)
    args.add("--codegen=debuginfo=" + compilation_mode.debug_info)

    args.add("--emit=dep-info,link")
    args.add("--color=always")
    args.add("--target=" + toolchain.target_triple)
    if hasattr(ctx.attr, "crate_features"):
        args.add_all(getattr(ctx.attr, "crate_features"), before_each = "--cfg", format_each = 'feature="%s"')
    if linker_script:
        args.add(linker_script.path, format = "--codegen=link-arg=-T%s")

    # Gets the paths to the folders containing the standard library (or libcore)
    rust_lib_paths = depset([file.dirname for file in toolchain.rust_lib.files.to_list()]).to_list()

    # Tell Rustc where to find the standard library
    args.add_all(rust_lib_paths, before_each = "-L", format_each = "%s")

    args.add_all(rust_flags)
    args.add_all(getattr(ctx.attr, "rustc_flags", []))
    add_edition_flags(args, crate_info)

    # Link!

    # Rust's built-in linker can handle linking wasm files. We don't want to attempt to use the cc
    # linker since it won't understand.
    if toolchain.target_arch != "wasm32":
        rpaths = _compute_rpaths(toolchain, output_dir, dep_info)
        ld, link_args, link_env = get_linker_and_args(ctx, cc_toolchain, feature_configuration, rpaths)
        env.update(link_env)
        args.add("--codegen=linker=" + ld)
        args.add_joined("--codegen", link_args, join_with = " ", format_joined = "link-args=%s")

    add_native_link_flags(args, dep_info)
    add_crate_link_flags(args, dep_info)

    if crate_info.type == "proc-macro" and crate_info.edition != "2015":
        args.add("--extern")
        args.add("proc_macro")

    # Make bin crate data deps available to tests.
    for data in getattr(ctx.attr, "data", []):
        if CrateInfo in data:
            dep_crate_info = data[CrateInfo]
            if dep_crate_info.type == "bin":
                env["CARGO_BIN_EXE_" + dep_crate_info.output.basename] = dep_crate_info.output.short_path

    # Update environment with user provided variables.
    env.update(crate_info.rustc_env)

    # This empty value satisfies Clippy, which otherwise complains about the
    # sysroot being undefined.
    env["SYSROOT"] = ""

    return args, env

def rustc_compile_action(
        ctx,
        toolchain,
        crate_info,
        output_hash = None,
        rust_flags = []):
    """Create and run a rustc compile action based on the current rule's attributes

    Args:
        ctx (ctx): The rule's context object
        toolchain (rust_toolchain): The current `rust_toolchain`
        crate_info (CrateInfo): The CrateInfo provider for the current target.
        output_hash (str, optional): The hashed path of the crate root. Defaults to None.
        rust_flags (list, optional): Additional flags to pass to rustc. Defaults to [].

    Returns:
        list: A list of the following providers:
            - (CrateInfo): info for the crate we just built; same as `crate_info` parameter.
            - (DepInfo): The transitive dependencies of this crate.
            - (DefaultInfo): The output file for this crate, and its runfiles.
    """
    dep_info, build_info = collect_deps(
        ctx.label,
        crate_info.deps,
        crate_info.proc_macro_deps,
        crate_info.aliases,
        toolchain,
    )

    compile_inputs, out_dir, build_env_file, build_flags_files = collect_inputs(
        ctx,
        ctx.file,
        ctx.files,
        toolchain,
        crate_info,
        dep_info,
        build_info,
    )

    cc_toolchain, feature_configuration = get_cc_toolchain(ctx)

    args, env = construct_arguments(
        ctx,
        ctx.file,
        toolchain,
        toolchain.rustc.path,
        cc_toolchain,
        feature_configuration,
        crate_info,
        dep_info,
        output_hash,
        rust_flags,
        out_dir,
        build_env_file,
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
            len(crate_info.srcs),
        ),
    )

    runfiles = ctx.runfiles(
        files = dep_info.transitive_dylibs.to_list() + getattr(ctx.files, "data", []),
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

def establish_cc_info(ctx, crate_info, toolchain, cc_toolchain, feature_configuration):
    """If the produced crate is suitable yield a CcInfo to allow for interop with cc rules 

    Args:
        ctx (ctx): The rule's context object
        crate_info (CrateInfo): The CrateInfo provider of the target crate
        toolchain (rust_toolchain): The current `rust_toolchain`
        cc_toolchain (CcToolchainInfo): The current CcToolchainInfo
        feature_configuration (FeatureConfiguration): Feature configuration to be queried.

    Returns:
        list: A list containing the CcInfo provider
    """

    if crate_info.is_test or crate_info.type not in ("staticlib", "cdylib") or getattr(ctx.attr, "out_binary", False):
        return []

    if crate_info.type == "staticlib":
        library_to_link = cc_common.create_library_to_link(
            actions = ctx.actions,
            feature_configuration = feature_configuration,
            cc_toolchain = cc_toolchain,
            static_library = crate_info.output,
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

    cc_infos = [dep[CcInfo] for dep in ctx.attr.deps if CcInfo in dep]
    cc_infos.append(CcInfo(linking_context = linking_context))

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
            - (str): An optional path to a generated environment file from a `cargo_build_script` target
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
        build_env_file = build_info.rustc_env.path

        # out_dir will be added as input by the transitive_build_infos loop below.
        build_flags_files.append(build_info.flags.path)

    # This should probably only actually be exposed to actions which link.
    for dep_build_info in dep_info.transitive_build_infos.to_list():
        input_files.append(dep_build_info.out_dir)
        build_flags_files.append(dep_build_info.link_flags.path)
        input_files.append(dep_build_info.link_flags)

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
    if not dep_info.transitive_dylibs:
        return depset([])
    if toolchain.os != "linux":
        fail("Runtime linking is not supported on {}, but found {}".format(
            toolchain.os,
            dep_info.transitive_dylibs,
        ))

    # Multiple dylibs can be present in the same directory, so deduplicate them.
    return depset([
        relativize(lib_dir, output_dir)
        for lib_dir in _get_dir_names(dep_info.transitive_dylibs.to_list())
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

def add_native_link_flags(args, dep_info):
    """Adds linker flags for all dependencies of the current target.

    Args:
        args (Args): The Args struct for a ctx.action
        dep_info (DepInfo): Dependeincy Info provider
    """
    native_libs = depset(transitive = [dep_info.transitive_dylibs, dep_info.transitive_staticlibs])
    args.add_all(native_libs, map_each = _get_dirname, uniquify = True, format_each = "-Lnative=%s")
    args.add_all(dep_info.transitive_dylibs, map_each = get_lib_name, format_each = "-ldylib=%s")
    args.add_all(dep_info.transitive_staticlibs, map_each = get_lib_name, format_each = "-lstatic=%s")

def _get_dirname(file):
    """A helper function for `add_native_link_flags`.

    Args:
        file (File): The target file

    Returns:
        [str]: Directory name of `file`
    """
    return file.dirname

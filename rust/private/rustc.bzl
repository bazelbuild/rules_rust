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

load("@io_bazel_rules_rust//rust:private/utils.bzl", "relative_path")
load("@io_bazel_rules_rust//rust:private/legacy_cc_starlark_api_shim.bzl", "get_libs_for_static_executable")
load(
    "@bazel_tools//tools/build_defs/cc:action_names.bzl",
    "CPP_LINK_EXECUTABLE_ACTION_NAME",
)
load(
    "@bazel_tools//tools/cpp:toolchain_utils.bzl",
    "find_cpp_toolchain",
)
load("@bazel_skylib//lib:versions.bzl", "versions")
load("@bazel_version//:def.bzl", "BAZEL_VERSION")

CrateInfo = provider(
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
        "rustc_env": """Dict[String, String]: Additional `"key": "value"` environment variables to set for rustc.""",
    },
)

BuildInfo = provider(
    fields = {
        "flags": """File: file containing additional flags to pass to rustc""",
        "out_dir": """File: directory containing the result of a build script""",
        "rustc_env": """File: file containing additional environment variables to set for rustc.""",
        "dep_env": """File: extra build script environment varibles to be set to direct dependencies.""",
    },
)

AliasableDep = provider(
    fields = {
        "name": "str",
        "dep": "CrateInfo",
    },
)

DepInfo = provider(
    fields = {
        "direct_crates": "depset[CrateInfo]",
        "transitive_crates": "depset[CrateInfo]",
        "transitive_dylibs": "depset[File]",
        "transitive_staticlibs": "depset[File]",
        "transitive_libs": "List[File]: All transitive dependencies, not filtered by type.",
        "dep_env": """File: File with environment variables direct dependencies build scripts rely upon.""",
    },
)

def _get_rustc_env(ctx, toolchain):
    version = ctx.attr.version if hasattr(ctx.attr, "version") else "0.0.0"
    major, minor, patch = version.split(".", 2)
    if "-" in patch:
        patch, pre = patch.split("-", 1)
    else:
        pre = ""
    return {
        "CARGO_PKG_VERSION": version,
        "CARGO_PKG_VERSION_MAJOR": major,
        "CARGO_PKG_VERSION_MINOR": minor,
        "CARGO_PKG_VERSION_PATCH": patch,
        "CARGO_PKG_VERSION_PRE": pre,
        "CARGO_PKG_AUTHORS": "",
        "CARGO_PKG_NAME": ctx.label.name,
        "CARGO_PKG_DESCRIPTION": "",
        "CARGO_PKG_HOMEPAGE": "",
        "CARGO_CFG_TARGET_OS": toolchain.os,
        "CARGO_CFG_TARGET_ARCH": toolchain.target_arch,
    }

def get_compilation_mode_opts(ctx, toolchain):
    comp_mode = ctx.var["COMPILATION_MODE"]
    if not comp_mode in toolchain.compilation_mode_opts:
        fail("Unrecognized compilation mode {} for toolchain.".format(comp_mode))

    return toolchain.compilation_mode_opts[comp_mode]

def get_lib_name(lib):
    """Returns the name of a library artifact, eg. libabc.a -> abc"""
    libname, ext = lib.basename.split(".", 2)

    if libname.startswith("lib"):
        return libname[3:]
    else:
        return libname

def collect_deps(label, deps, proc_macro_deps, aliases, toolchain):
    """
    Walks through dependencies and collects the transitive dependencies.

    Args:
      label: str: Label of the current target.
      deps: List[Label]: The deps from ctx.attr.deps.
      proc_macro_deps: List[Label]: The proc_macro deps from ctx.attr.proc_macro_deps.

    Returns:
      Returns a DepInfo provider.
    """

    for dep in deps:
        if CrateInfo in dep:
            if dep[CrateInfo].type == "proc-macro":
              fail(
                  "{} listed {} in its deps, but it is a proc-macro. It should instead be in proc-macro-deps.".format(
                      label,
                      dep.label,
                  )
              )
    for dep in proc_macro_deps:
        type = dep[CrateInfo].type
        if type != "proc-macro":
          fail(
              "{} listed {} in its proc_macro_deps, but it is not proc-macro, it is a {}. It should probably instead be listed in deps.".format(
                  label,
                  dep.label,
                  type,
              )
          )


    # TODO: Fix depset union (https://docs.bazel.build/versions/master/skylark/depsets.html)
    direct_crates = []
    transitive_crates = depset()
    transitive_dylibs = depset(order = "topological")  # dylib link flag ordering matters.
    transitive_staticlibs = depset()
    build_info = None

    aliases = {k.label: v for k,v in aliases.items()}
    for dep in deps + proc_macro_deps:
        if CrateInfo in dep:
            # This dependency is a rust_library
            direct_dep = dep[CrateInfo]
            aliasable_dep = AliasableDep(
                name = aliases.get(dep.label, direct_dep.name),
                dep = direct_dep,
            )
            direct_crates += [aliasable_dep]
            transitive_crates = depset([dep[CrateInfo]], transitive = [transitive_crates])
            transitive_crates = depset(transitive = [transitive_crates, dep[DepInfo].transitive_crates])
            transitive_dylibs = depset(transitive = [transitive_dylibs, dep[DepInfo].transitive_dylibs])
            transitive_staticlibs = depset(transitive = [transitive_staticlibs, dep[DepInfo].transitive_staticlibs])
        elif CcInfo in dep:
            # This dependency is a cc_library

            # TODO: We could let the user choose how to link, instead of always preferring to link static libraries.
            libs = get_libs_for_static_executable(dep)
            dylibs = [l for l in libs.to_list() if l.basename.endswith(toolchain.dylib_ext)]
            staticlibs = [l for l in libs.to_list() if l.basename.endswith(toolchain.staticlib_ext)]
            transitive_dylibs = depset(transitive = [transitive_dylibs, depset(dylibs)])
            transitive_staticlibs = depset(transitive = [transitive_staticlibs, depset(staticlibs)])
        elif BuildInfo in dep:
            if build_info:
                fail("Several deps are providing build information, only one is allowed in the dependencies", "deps")
            build_info = dep[BuildInfo]
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
            dep_env = build_info.dep_env if build_info else None,
        ),
        build_info,
    )

def _get_linker_and_args(ctx, rpaths):
    if (len(BAZEL_VERSION) == 0 or
        versions.is_at_least("0.18.0", BAZEL_VERSION)):
        user_link_flags = ctx.fragments.cpp.linkopts
    else:
        user_link_flags = depset(ctx.fragments.cpp.linkopts)

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

def _add_out_dir_to_compile_inputs(
        ctx,
        file,
        build_info,
        compile_inputs):
    out_dir = _create_out_dir_action(ctx, file, build_info.out_dir if build_info else None)
    if out_dir:
        compile_inputs = depset([out_dir], transitive = [compile_inputs])
    return compile_inputs, out_dir

def collect_inputs(
        ctx,
        file,
        files,
        toolchain,
        crate_info,
        dep_info,
        build_info):
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
    return _add_out_dir_to_compile_inputs(ctx, file, build_info, compile_inputs)

def construct_arguments(
        ctx,
        file,
        toolchain,
        crate_info,
        dep_info,
        output_hash,
        rust_flags):
    output_dir = getattr(crate_info.output, "dirname") if hasattr(crate_info.output, "dirname") else None

    linker_script = getattr(file, "linker_script") if hasattr(file, "linker_script") else None

    env = _get_rustc_env(ctx, toolchain)

    args = ctx.actions.args()
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
        ld, link_args, link_env = _get_linker_and_args(ctx, rpaths)
        env.update(link_env)
        args.add("--codegen=linker=" + ld)
        args.add_joined("--codegen", link_args, join_with = " ", format_joined = "link-args=%s")

    add_native_link_flags(args, dep_info)
    add_crate_link_flags(args, dep_info)

    # Make bin crate data deps available to tests.
    for data in getattr(ctx.attr, "data", []):
        if CrateInfo in data:
            dep_crate_info = data[CrateInfo]
            if dep_crate_info.type == "bin":
                env["CARGO_BIN_EXE_" + dep_crate_info.output.basename] = dep_crate_info.output.short_path

    # Update environment with user provided variables.
    env.update(crate_info.rustc_env)

    return args, env

def _create_command_env(ctx, out_dir):
    if out_dir:
        # We awkwardly construct this command because we cannot reference $PWD
        # from ctx.actions.run(executable=toolchain.rustc)
        out_dir_env = "OUT_DIR=$(pwd)/{} ".format(out_dir.path)
    else:
        out_dir_env = ""

    # Similar awkward construction to prepend execroot to the crate-root to set `CARGO_MANIFEST_DIR`
    #
    # See https://github.com/google/cargo-raze/issues/71#issuecomment-433225853 for the rationale as
    # to why
    #
    # In brief:
    #
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
    # `exec_root`. Since we cannot (seemingly) get the `exec_root` from skylark, we cheat a little
    # and use `$(pwd)` which resolves the `exec_root` at action execution time.
    package_dir = ctx.build_file_path[:ctx.build_file_path.rfind("/")]
    manifest_dir_env = "CARGO_MANIFEST_DIR=$(pwd)/{} ".format(package_dir)

    # This empty value satisfies Clippy, which otherwise complains about the
    # sysroot being undefined.
    sysroot_env= "SYSROOT= "

    return out_dir_env + manifest_dir_env + sysroot_env

def construct_compile_command(
        ctx,
        command,
        toolchain,
        crate_info,
        build_info,
        out_dir):
    rustc_env_expansion = ("export $(cat %s);" % build_info.rustc_env.path) if build_info else ""
    command_env = _create_command_env(ctx, out_dir)
    build_flags_expansion = (" $(cat '%s')" % build_info.flags.path) if build_info else ""
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
        generated_file = crate_info.name
        if toolchain.target_arch == "wasm32":
            generated_file = generated_file + ".wasm"
        src = "/".join([crate_info.output.dirname, generated_file])
        dst = crate_info.output.path
        if src != dst:
            maybe_rename = " && /bin/mv {src} {dst}".format(src=src, dst=dst)

    return '{}{}{} "$@" --remap-path-prefix="$(pwd)"=__bazel_redacted_pwd{}{}'.format(
        rustc_env_expansion,
        command_env,
        command,
        build_flags_expansion,
        maybe_rename,
    )

def rustc_compile_action(
        ctx,
        toolchain,
        crate_info,
        output_hash = None,
        rust_flags = []):
    """
    Constructs the rustc command used to build the current target.

    Returns:
      List[Provider]: A list of the following providers:
                     - CrateInfo: info for the crate we just built; same as `crate_info` parameter.
                     - DepInfo: The transitive dependencies of this crate.
                     - DefaultInfo: The output file for this crate, and its runfiles.
    """
    dep_info, build_info = collect_deps(
        ctx.label,
        crate_info.deps,
        crate_info.proc_macro_deps,
        crate_info.aliases,
        toolchain,
    )

    compile_inputs, out_dir = collect_inputs(
        ctx,
        ctx.file,
        ctx.files,
        toolchain,
        crate_info,
        dep_info,
        build_info
    )

    args, env = construct_arguments(
        ctx,
        ctx.file,
        toolchain,
        crate_info,
        dep_info,
        output_hash,
        rust_flags
    )

    command = construct_compile_command(
        ctx,
        toolchain.rustc.path,
        toolchain,
        crate_info,
        build_info,
        out_dir,
    )

    if hasattr(ctx.attr, "version") and ctx.attr.version != "0.0.0":
        formatted_version = " v{}".format(ctx.attr.version)
    else:
        formatted_version = ""

    ctx.actions.run_shell(
        command = command,
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

    return [
        crate_info,
        dep_info,
        DefaultInfo(
            # nb. This field is required for cc_library to depend on our output.
            files = depset([crate_info.output]),
            runfiles = runfiles,
            executable = crate_info.output if crate_info.type == "bin" or out_binary else None,
        ),
    ]

def add_edition_flags(args, crate):
    if crate.edition != "2015":
        args.add("--edition={}".format(crate.edition))

def _create_out_dir_action(ctx, file, build_info_out_dir = None):
    tar_file = getattr(file, "out_dir_tar", None)
    if not tar_file:
        return build_info_out_dir
    else:
        out_dir = ctx.actions.declare_directory(ctx.label.name + ".out_dir")
        ctx.actions.run_shell(
            # TODO: Remove system tar usage
            command = ";".join([
                "rm -fr {dir} && mkdir {dir} && tar -xzf {tar} -C {dir}".format(tar = tar_file.path, dir = out_dir.path),
            ] + (
                ["pushd {dir}; cp -fr {in_dir}; popd".format(dir = out_dir.path, in_dir = build_info_out_dir.path)
                ] if build_info_out_dir else []
            )),
            progress_message = "Creating OUT_DIR = %s" % out_dir.path,
            inputs = [tar_file] + (build_info_out_dir or []),
            outputs = [out_dir],
            use_default_shell_env = True,  # Sets PATH for tar and gzip (tar's dependency)
        )
    return out_dir

def _compute_rpaths(toolchain, output_dir, dep_info):
    """
    Determine the artifact's rpaths relative to the bazel root
    for runtime linking of shared libraries.
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
        relative_path(output_dir, lib_dir)
        for lib_dir in _get_dir_names(dep_info.transitive_dylibs.to_list())
    ])

def _get_dir_names(files):
    dirs = {}
    for f in files:
        dirs[f.dirname] = None
    return dirs.keys()

def add_crate_link_flags(args, dep_info):
    # nb. Crates are linked via --extern regardless of their crate_type
    args.add_all(dep_info.direct_crates, map_each = _crate_to_link_flag)
    args.add_all(
        dep_info.transitive_crates,
        map_each = _get_crate_dirname,
        uniquify = True,
        format_each = "-Ldependency=%s",
    )

def _crate_to_link_flag(crate_info):
    return ["--extern", "{}={}".format(crate_info.name, crate_info.dep.output.path)]

def _get_crate_dirname(crate):
    return crate.output.dirname

def add_native_link_flags(args, dep_info):
    native_libs = depset(transitive = [dep_info.transitive_dylibs, dep_info.transitive_staticlibs])
    args.add_all(native_libs, map_each = _get_dirname, uniquify = True, format_each = "-Lnative=%s")
    args.add_all(dep_info.transitive_dylibs, map_each = get_lib_name, format_each = "-ldylib=%s")
    args.add_all(dep_info.transitive_staticlibs, map_each = get_lib_name, format_each = "-lstatic=%s")

def _get_dirname(file):
    return file.dirname

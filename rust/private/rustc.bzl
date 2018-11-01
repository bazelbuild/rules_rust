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

load("@io_bazel_rules_rust//rust:private/utils.bzl", "find_toolchain", "relative_path")
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
        "output": "File: The output File that will be produced, depends on crate type.",
    },
)

DepInfo = provider(
    fields = {
        "direct_crates": "",
        "setup_cmd": "",
        "link_search_flags": "",
        "link_flags": "",
        "transitive_crates": "",
        "transitive_dylibs": "",
        "transitive_staticlibs": "",
        "transitive_libs": "List[File]: All transitive dependencies, not filtered by type.",
    },
)

def _get_rustc_env(ctx):
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
    }

def _get_compilation_mode_opts(ctx, toolchain):
    comp_mode = ctx.var["COMPILATION_MODE"]
    if not comp_mode in toolchain.compilation_mode_opts:
        fail("Unrecognized compilation mode %s for toolchain." % comp_mode)

    return toolchain.compilation_mode_opts[comp_mode]

def _get_lib_name(lib):
    """Returns the name of a library artifact, eg. libabc.a -> abc"""
    libname, ext = lib.basename.split(".", 2)
    if not libname.startswith("lib"):
        fail("Expected {} to start with 'lib' prefix.".format(lib))
    return libname[3:]

def _symlink_dep_cmd(lib, deps_dir, in_runfiles):
    """
    Helper function to construct a command for symlinking a library into the
    deps directory.
    """
    lib_path = lib.short_path if in_runfiles else lib.path
    return (
        "ln -sf " + relative_path(deps_dir, lib_path) + " " +
        deps_dir + "/" + lib.basename + "\n"
    )

def setup_deps(
        deps,
        name,
        working_dir,
        toolchain,
        in_runfiles = False):
    """
    Walks through dependencies and constructs the necessary commands for linking
    to all the necessary dependencies.

    Args:
      deps: List of Labels containing deps from ctx.attr.deps.
      name: Name of the current target.
      working_dir: The output directory for the current target's outputs.
      in_runfiles: True if the setup commands will be run in a .runfiles
          directory. In this case, the working dir should be '.', and the deps
          will be symlinked into the .deps dir from the runfiles tree.

    Returns:
      Returns a DepInfo provider.
    """
    direct_crates = depset()
    transitive_crates = depset()
    transitive_dylibs = depset(order = "topological")  # dylib link flag ordering matters.
    transitive_staticlibs = depset()
    for dep in deps:
        if CrateInfo in dep:
            # This dependency is a rust_library
            direct_crates += [dep[CrateInfo]]
            transitive_crates += [dep[CrateInfo]]
            transitive_crates += dep[DepInfo].transitive_crates
            transitive_dylibs += dep[DepInfo].transitive_dylibs
            transitive_staticlibs += dep[DepInfo].transitive_staticlibs
        elif hasattr(dep, "cc"):
            # This dependency is a cc_library
            transitive_dylibs += [l for l in dep.cc.libs if l.basename.endswith(toolchain.dylib_ext)]
            transitive_staticlibs += [l for l in dep.cc.libs if l.basename.endswith(toolchain.staticlib_ext)]
        else:
            fail("rust targets can only depend on rust_library or cc_library targets." + str(dep), "deps")

    transitive_libs = depset([c.output for c in transitive_crates]) + transitive_staticlibs + transitive_dylibs

    # Create symlinks pointing to each transitive lib in deps_dir.
    deps_dir = working_dir + "/" + name + ".deps"
    setup_cmd = ["rm -rf " + deps_dir + "; mkdir " + deps_dir + "\n"]
    for lib in transitive_libs:
        setup_cmd += [_symlink_dep_cmd(lib, deps_dir, in_runfiles)]

    link_search_flags = []
    if transitive_crates:
        link_search_flags += ["-L dependency={}".format(deps_dir)]
    if transitive_dylibs or transitive_staticlibs:
        link_search_flags += ["-L native={}".format(deps_dir)]

    link_flags = []

    # nb. Crates are linked via --extern regardless of their crate_type
    link_flags += ["--extern " + crate.name + "=" + deps_dir + "/" + crate.output.basename for crate in direct_crates]
    link_flags += ["-l dylib=" + _get_lib_name(lib) for lib in transitive_dylibs.to_list()]
    link_flags += ["-l static=" + _get_lib_name(lib) for lib in transitive_staticlibs.to_list()]

    return DepInfo(
        direct_crates = direct_crates,
        setup_cmd = setup_cmd,
        link_search_flags = link_search_flags,
        link_flags = link_flags,
        transitive_crates = transitive_crates,
        transitive_dylibs = transitive_dylibs,
        transitive_staticlibs = transitive_staticlibs,
        transitive_libs = list(transitive_libs),
    )

def rustc_compile_action(
        ctx,
        toolchain,
        crate_info,
        output_hash = None,
        rust_flags = []):
    """
    Constructs the rustc command used to build the current target.
    """
    output_dir = crate_info.output.dirname

    dep_info = setup_deps(
        crate_info.deps,
        crate_info.name,
        output_dir,
        toolchain,
    )

    compile_inputs = (
        crate_info.srcs +
        ctx.files.data +
        dep_info.transitive_libs +
        [toolchain.rustc] +
        toolchain.rustc_lib +
        toolchain.rust_lib +
        toolchain.crosstool_files
    )

    rpaths = _compute_rpaths(toolchain, output_dir, dep_info)

    if (len(BAZEL_VERSION) == 0 or
        versions.is_at_least("0.18.0", BAZEL_VERSION)):
        user_link_flags = ctx.fragments.cpp.linkopts
    else:
        user_link_flags = depset(ctx.fragments.cpp.linkopts)

    # Paths to cc (for linker) and ar
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    ld = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_EXECUTABLE_ACTION_NAME,
    )
    link_variables = cc_common.create_link_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        is_linking_dynamic_library = False,
        runtime_library_search_directories = rpaths,
        user_link_flags = user_link_flags,
    )
    cc_link_options = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = CPP_LINK_EXECUTABLE_ACTION_NAME,
        variables = link_variables,
    )

    extra_filename = ""
    if output_hash:
        extra_filename = "-%s" % output_hash

    env = _get_rustc_env(ctx)
    out_dir_tar = ctx.file.out_dir_tar
    if out_dir_tar:
        # genfile?
        out_dir = ctx.actions.declare_directory(ctx.label.name + ".out_dir") #, sibling=)
        ctx.actions.run_shell(
            # TODO: Remove /bin/tar usage
            command = "mkdir {dir} && /bin/tar -xzf {tar} -C {dir}".format(tar=out_dir_tar.path, dir=out_dir.path),
            ### && OUT_DIR=$(pwd)/ ... rustc
            inputs = [out_dir_tar],
            outputs = [out_dir],
            use_default_shell_env = True, # For tar and it's dependencies.
        )
        compile_inputs.append(out_dir)

        env["OUT_DIR"] = "/proc/self/cwd/" + out_dir.path #TODO: This probably breaks on OSX; find some other PWD variant.

    args = ctx.actions.args()
    args.add(crate_info.root)
    args.add("--crate-name", crate_info.name)
    args.add("--crate-type", crate_info.type)

    compilation_mode = _get_compilation_mode_opts(ctx, toolchain)
    args.add("--codegen", "opt-level=" + compilation_mode.opt_level)
    args.add("--codegen", "debuginfo=" + compilation_mode.debug_info)

    # Mangle symbols to disambiguate crates with the same name
    args.add("--codegen", "metadata=" + extra_filename)
    args.add("--codegen", "extra-filename={}".format(extra_filename))
    args.add("--codegen", "linker=" + ld)
    args.add("--codegen", "link-args={}".format(" ".join(cc_link_options)))
    # TODO: How get PWD?
    # args.add("--remap-path-prefix", "{}={}".format("$(pwd)", "__bazel_redacted_pwd"))
    args.add("--out-dir", output_dir)
    args.add("--emit=dep-info,link")
    args.add("--color", "always")
    args.add("--target=" + toolchain.target_triple)

    args.add_all(_get_features_flags(ctx.attr.crate_features))
    args.add_all(rust_flags)
    args.add_all(ctx.attr.rustc_flags)

    # Native link flags
    native_libs = depset(transitive=[dep_info.transitive_dylibs, dep_info.transitive_staticlibs])
    native_link_dirs = [lib.dirname for lib in native_libs]
    args.add_all(native_link_dirs, uniquify = True, format_each = "-Lnative=%s")
    args.add_all(dep_info.transitive_dylibs, map_each=_get_lib_name, format_each="-ldylib=%s")
    args.add_all(dep_info.transitive_staticlibs, map_each=_get_lib_name, format_each="-lstatic=%s")

    # Rust link flags
    # nb. transitive
    rust_link_dirs = [crate.output.dirname for crate in dep_info.transitive_crates]
    args.add_all(rust_link_dirs, uniquify = True, format_each = "-Ldependency=%s")
    args.add_all(dep_info.direct_crates, before_each = "--extern", map_each = _crate_to_link_flag)

    ctx.actions.run(
        executable = toolchain.rustc,
        inputs = compile_inputs,
        outputs = [crate_info.output],
        arguments = [args],
        env = env,
        mnemonic = "Rustc",
        progress_message = "Compiling Rust {} {} ({} files)".format(crate_info.type, ctx.label.name, len(ctx.files.srcs)),
    )

    runfiles = ctx.runfiles(
        files = dep_info.transitive_dylibs.to_list() + ctx.files.data,
        collect_data = True,
    )

    return [
        crate_info,
        dep_info,
        DefaultInfo(
            # nb. This field is required for cc_library to depend on our output.
            files = depset([crate_info.output]),
            runfiles = runfiles,
        ),
    ]

def _crate_to_link_flag(crate_info):
    return "{}={}".format(crate_info.name, crate_info.output.path)

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
        for lib_dir in _get_dir_names(dep_info.transitive_dylibs)
    ])

def _get_features_flags(features):
    """
    Constructs a string containing the feature flags from the features specified
    in the features attribute.
    """
    features_flags = []
    for feature in features:
        features_flags += ["--cfg feature=\\\"%s\\\"" % feature]
    return features_flags

def _get_dir_names(files):
    dirs = {}
    for f in files:
        dirs[f.dirname] = None
    return dirs.keys()

def _get_path_str(dirs):
    return ":".join(dirs)

def _out_dir_setup_cmd(out_dir_tar):
    if out_dir_tar:
        return [
            "mkdir ./out_dir/\n",
            "tar -xzf %s -C ./out_dir\n" % out_dir_tar.path,
        ]
    else:
        return []

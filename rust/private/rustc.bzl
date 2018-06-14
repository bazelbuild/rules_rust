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

load(":private/utils.bzl", "find_toolchain", "relative_path")

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

def _get_rustc_env(ctx):
    version = ctx.attr.version if hasattr(ctx.attr, "version") else "0.0.0"
    major, minor, patch = version.split(".", 2)
    if "-" in patch:
        patch, pre = patch.split("-", 1)
    else:
        pre = ""
    return [
        "CARGO_PKG_VERSION=" + version,
        "CARGO_PKG_VERSION_MAJOR=" + major,
        "CARGO_PKG_VERSION_MINOR=" + minor,
        "CARGO_PKG_VERSION_PATCH=" + patch,
        "CARGO_PKG_VERSION_PRE=" + pre,
        "CARGO_PKG_AUTHORS=",
        "CARGO_PKG_NAME=" + ctx.label.name,
        "CARGO_PKG_DESCRIPTION=",
        "CARGO_PKG_HOMEPAGE=",
    ]

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
      Returns a struct containing the following fields:
        transitive_crates:
        transitive_dylibs:
        transitive_staticlibs:
        transitive_libs: All transitive dependencies, not filtered by type.
        setup_cmd:
        link_search_flags:
        link_flags:
    """
    direct_crates = depset()
    transitive_crates = depset()
    transitive_dylibs = depset(order = "topological")  # dylib link flag ordering matters.
    transitive_staticlibs = depset()
    for dep in deps:
        if hasattr(dep, "crate_info"):
            # This dependency is a rust_library
            direct_crates += [dep.crate_info]
            transitive_crates += [dep.crate_info]
            transitive_crates += dep.depinfo.transitive_crates
            transitive_dylibs += dep.depinfo.transitive_dylibs
            transitive_staticlibs += dep.depinfo.transitive_staticlibs
        elif hasattr(dep, "cc"):
            # This dependency is a cc_library
            transitive_dylibs += [l for l in dep.cc.libs if l.basename.endswith(toolchain.dylib_ext)]
            transitive_staticlibs += [l for l in dep.cc.libs if l.basename.endswith(toolchain.staticlib_ext)]
        else:
            fail("rust targets can only depend on rust_library or cc_library targets.")

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

    return struct(
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

    depinfo = setup_deps(
        crate_info.deps,
        crate_info.name,
        output_dir,
        toolchain,
    )

    compile_inputs = (
        crate_info.srcs +
        ctx.files.data +
        depinfo.transitive_libs +
        [toolchain.rustc] +
        toolchain.rustc_lib +
        toolchain.rust_lib +
        toolchain.crosstool_files
    )

    if ctx.file.out_dir_tar:
        compile_inputs.append(ctx.file.out_dir_tar)

    # Paths to cc (for linker) and ar
    cpp_fragment = ctx.host_fragments.cpp
    cc = cpp_fragment.compiler_executable
    ar = cpp_fragment.ar_executable

    # Currently, the CROSSTOOL config for darwin sets ar to "libtool". Because
    # rust uses ar-specific flags, use /usr/bin/ar in this case.
    # TODO(dzc): This is not ideal. Remove this workaround once ar_executable
    # always points to an ar binary.
    ar_str = "%s" % ar
    if ar_str.find("libtool", 0) != -1:
        ar = "/usr/bin/ar"

    rpaths = _compute_rpaths(toolchain, output_dir, depinfo)

    # Construct features flags
    features_flags = _get_features_flags(ctx.attr.crate_features)

    extra_filename = ""
    if output_hash:
        extra_filename = "-%s" % output_hash

    compilation_mode = _get_compilation_mode_opts(ctx, toolchain)

    command = " ".join(
        ["set -e;"] +
        # If TMPDIR is set but not created, rustc will die.
        ['if [ ! -z "${TMPDIR+x}" ]; then mkdir -p $TMPDIR; fi;'] +
        depinfo.setup_cmd +
        _out_dir_setup_cmd(ctx.file.out_dir_tar) +
        _get_rustc_env(ctx) +
        [
            "OUT_DIR=$(pwd)/out_dir",
            toolchain.rustc.path,
            crate_info.root.path,
            "--crate-name",
            crate_info.name,
            "--crate-type",
            crate_info.type,
            "--codegen opt-level=%s" % compilation_mode.opt_level,
            "--codegen debuginfo=%s" % compilation_mode.debug_info,
            # Mangle symbols to disambiguate crates with the same name
            "--codegen metadata=%s" % extra_filename,
            "--codegen extra-filename='%s'" % extra_filename,
            "--codegen ar=%s" % ar,
            "--codegen linker=%s" % cc,
            "--codegen link-args='%s'" % " ".join(cpp_fragment.link_options),
            "--out-dir",
            output_dir,
            "--emit=dep-info,link",
            "--color always",
            "--target=" + toolchain.target_triple,
        ] +
        ["--codegen link-arg='-Wl,-rpath={}'".format(rpath) for rpath in rpaths] +
        features_flags +
        rust_flags +
        depinfo.link_search_flags +
        depinfo.link_flags +
        ctx.attr.rustc_flags,
    )

    ctx.action(
        inputs = compile_inputs,
        outputs = [crate_info.output],
        mnemonic = "Rustc",
        command = command,
        use_default_shell_env = True,
        progress_message = "Compiling Rust {} {} ({} files)".format(crate_info.type, ctx.label.name, len(ctx.files.srcs)),
    )

    runfiles = ctx.runfiles(
        files = depinfo.transitive_dylibs.to_list() + ctx.files.data,
        collect_data = True,
    )

    return struct(
        crate_info = crate_info,
        # nb. This field is required for cc_library to depend on our output.
        files = depset([crate_info.output]),
        depinfo = depinfo,
        runfiles = runfiles,
    )

def _compute_rpaths(toolchain, output_dir, depinfo):
    """
    Determine the artifact's rpaths relative to the bazel root
    for runtime linking of shared libraries.
    """
    if not depinfo.transitive_dylibs:
        return []
    if toolchain.os != "linux":
        fail("Runtime linking is not supported on {}, but found {}".format(
            toolchain.os,
            depinfo.transitive_dylibs,
        ))

    # Multiple dylibs can be present in the same directory, so deduplicate them.
    return [
        "$ORIGIN/" + relative_path(output_dir, lib_dir)
        for lib_dir in _get_dir_names(depinfo.transitive_dylibs)
    ]

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

"""
Toolchain rules used by Rust.
"""

load(":utils.bzl", "relative_path")

ZIP_PATH = "/usr/bin/zip"

def _get_rustc_env(ctx):
    version = ctx.attr.version if hasattr(ctx.attr, "version") else "0.0.0"
    v1, v2, v3 = version.split(".")
    if "-" in v3:
        v3, pre = v3.split("-")
    else:
        pre = ""
    return [
        "CARGO_PKG_VERSION=" + version,
        "CARGO_PKG_VERSION_MAJOR=" + v1,
        "CARGO_PKG_VERSION_MINOR=" + v2,
        "CARGO_PKG_VERSION_PATCH=" + v3,
        "CARGO_PKG_VERSION_PRE=" + pre,
        "CARGO_PKG_AUTHORS=",
        "CARGO_PKG_NAME=" + ctx.label.name,
        "CARGO_PKG_DESCRIPTION=",
        "CARGO_PKG_HOMEPAGE=",
    ]

def _get_comp_mode_codegen_opts(ctx, toolchain):
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

def _create_setup_cmd(lib, deps_dir, in_runfiles):
    """
    Helper function to construct a command for symlinking a library into the
    deps directory.
    """
    lib_path = lib.short_path if in_runfiles else lib.path
    return (
        "ln -sf " + relative_path(deps_dir, lib_path) + " " +
        deps_dir + "/" + lib.basename + "\n"
    )

# @TODO make private again
def setup_deps(
        deps,
        name,
        working_dir,
        toolchain,
        allow_cc_deps = False,
        in_runfiles = False):
    """
    Walks through dependencies and constructs the necessary commands for linking
    to all the necessary dependencies.

    Args:
      deps: List of Labels containing deps from ctx.attr.deps.
      name: Name of the current target.
      working_dir: The output directory for the current target's outputs.
      allow_cc_deps: True if the current target is allowed to depend on cc_library
          targets, false otherwise.
      in_runfiles: True if the setup commands will be run in a .runfiles
          directory. In this case, the working dir should be '.', and the deps
          will be symlinked into the .deps dir from the runfiles tree.

    Returns:
      Returns a struct containing the following fields:
        transitive_rlibs:
        transitive_dylibs:
        transitive_staticlibs:
        transitive_libs: All transitive dependencies, not filtered by type.
        setup_cmd:
        search_flags:
        link_flags:
    """
    deps_dir = working_dir + "/" + name + ".deps"
    setup_cmd = ["rm -rf " + deps_dir + "; mkdir " + deps_dir + "\n"]

    staticlib_filetype = FileType([toolchain.staticlib_ext])
    dylib_filetype = FileType([toolchain.dylib_ext])

    link_flags = []
    transitive_rlibs = depset()
    transitive_dylibs = depset(order = "topological")  # dylib link flag ordering matters.
    transitive_staticlibs = depset()
    for dep in deps:
        if hasattr(dep, "crate_info"):
            # This dependency is a rust_library
            rlib = dep.crate_info.output

            transitive_rlibs += [rlib]
            transitive_rlibs += dep.transitive_rlibs
            transitive_dylibs += dep.transitive_dylibs
            transitive_staticlibs += dep.transitive_staticlibs

            link_flags += ["--extern " + dep.label.name + "=" + deps_dir + "/" + rlib.basename]
        elif hasattr(dep, "cc"):
            # This dependency is a cc_library
            if not allow_cc_deps:
                fail("Only rust_library, rust_binary, and rust_test targets can " +
                     "depend on cc_library")

            transitive_dylibs += dylib_filetype.filter(dep.cc.libs)
            transitive_staticlibs += staticlib_filetype.filter(dep.cc.libs)

        else:
            fail("rust_library, rust_binary and rust_test targets can only depend " +
                 "on rust_library or cc_library targets.")

    link_flags += ["-l static=" + _get_lib_name(lib) for lib in transitive_staticlibs.to_list()]
    link_flags += ["-l dylib=" + _get_lib_name(lib) for lib in transitive_dylibs.to_list()]

    search_flags = []
    if transitive_rlibs:
        search_flags += ["-L dependency={}".format(deps_dir)]
    if transitive_dylibs or transitive_staticlibs:
        search_flags += ["-L native={}".format(deps_dir)]

    # Create symlinks pointing to each transitive lib in deps_dir.
    transitive_libs = transitive_rlibs + transitive_staticlibs + transitive_dylibs
    for transitive_lib in transitive_libs:
        setup_cmd += [_create_setup_cmd(transitive_lib, deps_dir, in_runfiles)]

    return struct(
        link_flags = link_flags,
        search_flags = search_flags,
        setup_cmd = setup_cmd,
        transitive_dylibs = transitive_dylibs,
        transitive_libs = list(transitive_libs),
        transitive_rlibs = transitive_rlibs,
        transitive_staticlibs = transitive_staticlibs,
    )

_setup_deps = setup_deps

CrateInfo = provider(
    fields = [
        "name",
        "type",
        "root",
        "srcs",
        "deps",
        "output",
    ],
)

# Utility methods that use the toolchain provider.
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

    depinfo = _setup_deps(
        crate_info.deps,
        crate_info.name,
        output_dir,
        toolchain,
        allow_cc_deps = True,
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

    rpaths = _compute_rpaths(toolchain, ctx.bin_dir, output_dir, depinfo)

    # Construct features flags
    features_flags = _get_features_flags(ctx.attr.crate_features)

    extra_filename = ""
    if output_hash:
        extra_filename = "-%s" % output_hash

    codegen_opts = _get_comp_mode_codegen_opts(ctx, toolchain)

    command = " ".join(
        ["set -e;"] +
        # If TMPDIR is set but not created, rustc will die.
        ['if [ ! -z "${TMPDIR+x}" ]; then mkdir -p $TMPDIR; fi;'] + depinfo.setup_cmd +
        _out_dir_setup_cmd(ctx.file.out_dir_tar) +
        _get_rustc_env(ctx) + [
            "LD_LIBRARY_PATH=%s" % _get_path_str(_get_dir_names(toolchain.rustc_lib)),
            "DYLD_LIBRARY_PATH=%s" % _get_path_str(_get_dir_names(toolchain.rustc_lib)),
            "OUT_DIR=$(pwd)/out_dir",
            toolchain.rustc.path,
            crate_info.root.path,
            "--crate-name %s" % crate_info.name,
            "--crate-type %s" % crate_info.type,
            "--codegen opt-level=%s" % codegen_opts.opt_level,
            "--codegen debuginfo=%s" % codegen_opts.debug_info,
            # Disambiguate this crate from similarly named ones
            "--codegen metadata=%s" % extra_filename,
            "--codegen extra-filename='%s'" % extra_filename,
            "--codegen ar=%s" % ar,
            "--codegen linker=%s" % cc,
            "--codegen link-args='%s'" % " ".join(cpp_fragment.link_options),
            "--out-dir %s" % output_dir,
            "--emit=dep-info,link",
            "--color always",
        ] + ["--codegen link-arg='-Wl,-rpath={}'".format(rpath) for rpath in rpaths] +
        features_flags +
        rust_flags +
        ["-L all=%s" % dir for dir in _get_dir_names(toolchain.rust_lib)] +
        depinfo.search_flags +
        depinfo.link_flags +
        ctx.attr.rustc_flags,
    )

    ctx.action(
        inputs = compile_inputs,
        outputs = [crate_info.output],
        mnemonic = "Rustc",
        command = command,
        use_default_shell_env = True,
        progress_message = "Compiling Rust {} {} ({} files)".format(
            crate_info.type,
            ctx.label.name,
            len(ctx.files.srcs),
        ),
    )

    runfiles = ctx.runfiles(
        files = depinfo.transitive_dylibs.to_list() + ctx.files.data,
        collect_data = True,
    )

    return struct(
        crate_info = crate_info,
        # nb. This field is required for cc_library to depend on our output.
        files = depset([crate_info.output]),
        # @TODO DepInfo
        depinfo = depinfo,
        transitive_dylibs = depinfo.transitive_dylibs,
        transitive_rlibs = depinfo.transitive_rlibs,
        transitive_staticlibs = depinfo.transitive_staticlibs,
        runfiles = runfiles,
    )

def build_rustdoc_command(ctx, toolchain, rust_doc_zip, depinfo, lib_rs, target, doc_flags):
    """
    Constructs the rustdoc command used to build the current target.
    """

    docs_dir = rust_doc_zip.dirname + "/_rust_docs"
    return " ".join(
        ["set -e;"] +
        depinfo.setup_cmd + [
            "rm -rf %s;" % docs_dir,
            "mkdir %s;" % docs_dir,
            "LD_LIBRARY_PATH=%s" % _get_path_str(_get_dir_names(toolchain.rustc_lib)),
            "DYLD_LIBRARY_PATH=%s" % _get_path_str(_get_dir_names(toolchain.rustc_lib)),
            toolchain.rust_doc.path,
            lib_rs.path,
            "--crate-name %s" % target.name,
        ] + ["-L all=%s" % dir for dir in _get_dir_names(toolchain.rust_lib)] + [
            "-o %s" % docs_dir,
        ] + doc_flags +
        depinfo.search_flags +
        # rustdoc can't do anything with native link flags, and blows up on them
        [f for f in depinfo.link_flags if f.startswith("--extern")] +
        [
            "&&",
            "(cd %s" % docs_dir,
            "&&",
            ZIP_PATH,
            "-qR",
            rust_doc_zip.basename,
            "$(find . -type f) )",
            "&&",
            "mv %s/%s %s" % (docs_dir, rust_doc_zip.basename, rust_doc_zip.path),
        ],
    )

def build_rustdoc_test_command(ctx, toolchain, depinfo, lib_rs):
    """
    Constructs the rustdocc command used to test the current target.
    """
    return " ".join(
        ["#!/usr/bin/env bash\n"] + ["set -e\n"] + depinfo.setup_cmd + [
            "LD_LIBRARY_PATH=%s" % _get_path_str(_get_dir_names(toolchain.rustc_lib)),
            "DYLD_LIBRARY_PATH=%s" % _get_path_str(_get_dir_names(toolchain.rustc_lib)),
            toolchain.rust_doc.path,
        ] + ["-L all=%s" % dir for dir in _get_dir_names(toolchain.rust_lib)] + [
            lib_rs.path,
        ] + depinfo.search_flags +
        depinfo.link_flags,
    )

def _compute_rpaths(toolchain, bin_dir, output_dir, depinfo):
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

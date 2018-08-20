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

# Utility methods that use the toolchain provider.
def build_rustc_command(
        ctx,
        toolchain,
        crate_name,
        crate_type,
        src,
        output_dir,
        depinfo,
        output_hash = None,
        rust_flags = []):
    """
    Constructs the rustc command used to build the current target.
    """

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

    return " ".join(
        ["set -e;"] +
        # If TMPDIR is set but not created, rustc will die.
        ['if [ ! -z "${TMPDIR+x}" ]; then mkdir -p $TMPDIR; fi;'] + depinfo.setup_cmd +
        _out_dir_setup_cmd(ctx.file.out_dir_tar) +
        _get_rustc_env(ctx) + [
            "LD_LIBRARY_PATH=%s" % _get_path_str(_get_dir_names(toolchain.rustc_lib)),
            "DYLD_LIBRARY_PATH=%s" % _get_path_str(_get_dir_names(toolchain.rustc_lib)),
            "OUT_DIR=$(pwd)/out_dir",
            toolchain.rustc.path,
            src.path,
            "--crate-name %s" % crate_name,
            "--crate-type %s" % crate_type,
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
    return depset([
        "$ORIGIN/" + relative_path(output_dir, dylib.dirname)
        for dylib in depinfo.transitive_dylibs
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


"""
Toolchain rules used by Rust.
"""

ZIP_PATH = "/usr/bin/zip"

# Utility methods that use the toolchain provider.
def build_rustc_command(ctx, toolchain, crate_name, crate_type, src, output_dir,
                         depinfo, rust_flags=[]):
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

  # Construct features flags
  features_flags = _get_features_flags(ctx.attr.crate_features)

  return " ".join(
      ["set -e;"] +
      depinfo.setup_cmd +
      [
          "LD_LIBRARY_PATH=%s" % _get_path_str(_get_dir_names(toolchain.rustc_lib)),
          "DYLD_LIBRARY_PATH=%s" % _get_path_str(_get_dir_names(toolchain.rustc_lib)),
          toolchain.rustc.path,
          src.path,
          "--crate-name %s" % crate_name,
          "--crate-type %s" % crate_type,
          "-C opt-level=3",
          "--codegen ar=%s" % ar,
          "--codegen linker=%s" % cc,
          "--codegen link-args='%s'" % ' '.join(cpp_fragment.link_options),
      ] + ["-L all=%s" % dir for dir in _get_dir_names(toolchain.rust_lib)] + [
          "--out-dir %s" % output_dir,
          "--emit=dep-info,link",
      ] +
      features_flags +
      rust_flags +
      depinfo.search_flags +
      depinfo.link_flags +
      ctx.attr.rustc_flags)

def build_rustdoc_command(ctx, toolchain, rust_doc_zip, depinfo, lib_rs, target, doc_flags):
  """
  Constructs the rustdocc command used to build the current target.
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
      ] +
      doc_flags +
      depinfo.search_flags +
      depinfo.link_flags + [
          "&&",
          "(cd %s" % docs_dir,
          "&&",
          ZIP_PATH,
          "-qR",
          rust_doc_zip.basename,
          "$(find . -type f) )",
          "&&",
          "mv %s/%s %s" % (docs_dir, rust_doc_zip.basename, rust_doc_zip.path),
      ])

def build_rustdoc_test_command(ctx, toolchain, depinfo, lib_rs):
  """
  Constructs the rustdocc command used to test the current target.
  """
  return " ".join(
      ["#!/usr/bin/env bash\n"] +
      ["set -e\n"] +
      depinfo.setup_cmd +
      [
          "LD_LIBRARY_PATH=%s" % _get_path_str(_get_dir_names(toolchain.rustc_lib)),
          "DYLD_LIBRARY_PATH=%s" % _get_path_str(_get_dir_names(toolchain.rustc_lib)),
          toolchain.rust_doc.path,
      ] + ["-L all=%s" % dir for dir in _get_dir_names(toolchain.rust_lib)] + [
          lib_rs.path,
      ] +
      depinfo.search_flags +
      depinfo.link_flags)

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

def _get_first_file(input):
  if hasattr(input, "files"):
    for f in input.files:
      return f
  return input

def _get_files(input):
  files = []
  for i in input:
    if hasattr(i, "files"):
      files += [f for f in i.files]
  return files

# The rust_toolchain rule definition and implementation.

def _rust_toolchain_impl(ctx):
  toolchain = platform_common.ToolchainInfo(
      rustc = _get_first_file(ctx.attr.rustc),
      rust_doc = _get_first_file(ctx.attr.rust_doc),
      rustc_lib = _get_files(ctx.attr.rustc_lib),
      rust_lib = _get_files(ctx.attr.rust_lib),
      crosstool_files = ctx.files._crosstool)
  return [toolchain]

rust_toolchain = rule(
    _rust_toolchain_impl,
    attrs = {
        "rustc": attr.label(allow_files = True),
        "rust_doc": attr.label(allow_files = True),
        "rustc_lib": attr.label_list(allow_files = True),
        "rust_lib": attr.label_list(allow_files = True),
        "_crosstool": attr.label(
            default = Label("//tools/defaults:crosstool"),
        ),
    },
)

"""Declares a Rust toolchain for use.

This is used when porting the rust_rules to a new platform.

Args:
  name: The name of the toolchain instance.
  rustc: The location of the `rustc` binary. Can be a direct source or a filegroup containing one
      item.
  rustdoc: The location of the `rustdoc` binary. Can be a direct source or a filegroup containing
      one item.
  rustc_lib: The libraries used by rustc.
  rust_lib: The libraries used by rustc.

Example:
  Suppose the core rust team has ported the compiler to a new target CPU, called `cpuX`. This
  support can be used in Bazel by defining a new toolchain definition and declaration:
  ```
  load('@io_bazel_rules_rust//rust:toolchain.bzl', 'rust_toolchain')

  toolchain(
    name="rust_cpuX",
    exec_compatible_with = [
      "@bazel_tools//platforms:cpuX",
    ],
    target_compatible_with = [
      "@bazel_tools//platforms:cpuX",
    ],
    toolchain = ":rust_cpuX_impl")
  rust_toolchain(
    name="rust_cpuX_impl",
    rustc="@rust_cpuX//:rustc",
    rustc_lib=["@rust_cpuX//:rustc_lib"],
    rust_lib=["@rust_cpuX//:rust_lib"],
    rust_doc="@rust_cpuX//:rustdoc")
  ```

  Then, either add the label of the toolchain rule to register_toolchains in the WORKSPACE, or pass
  it to the "--extra_toolchains" flag for Bazel, and it will be used.

  See @io_bazel_rules_rust//rust:repositories.bzl for examples of defining the @rust_cpuX repository
  with the actual binaries and libraries.
"""

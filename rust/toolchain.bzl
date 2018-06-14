"""
The rust_toolchain rule definition and implementation.
"""

def _get_files(labels):
    return [f for l in labels for f in getattr(l, "files", [])]

def _rust_toolchain_impl(ctx):
    compilation_mode_opts = {}
    for k, v in ctx.attr.opt_level.items():
        if not k in ctx.attr.debug_info:
            fail("Compilation mode {} is not defined in debug_info but is defined opt_level".format(k))
        compilation_mode_opts[k] = struct(debug_info = ctx.attr.debug_info[k], opt_level = v)
    for k, v in ctx.attr.debug_info.items():
        if not k in ctx.attr.opt_level:
            fail("Compilation mode {} is not defined in opt_level but is defined debug_info".format(k))

    toolchain = platform_common.ToolchainInfo(
        rustc = ctx.file.rustc,
        rust_doc = ctx.file.rust_doc,
        rustc_lib = _get_files(ctx.attr.rustc_lib),
        rust_lib = _get_files(ctx.attr.rust_lib),
        staticlib_ext = ctx.attr.staticlib_ext,
        dylib_ext = ctx.attr.dylib_ext,
        target_triple = ctx.attr.target_triple,
        exec_triple = ctx.attr.exec_triple,
        os = ctx.attr.os,
        compilation_mode_opts = compilation_mode_opts,
        crosstool_files = ctx.files._crosstool,
    )
    return [toolchain]

rust_toolchain = rule(
    _rust_toolchain_impl,
    attrs = {
        "rustc": attr.label(allow_single_file = True),
        "rust_doc": attr.label(allow_single_file = True),
        "rustc_lib": attr.label_list(allow_files = True),
        "rust_lib": attr.label_list(allow_files = True),
        "staticlib_ext": attr.string(mandatory = True),
        "dylib_ext": attr.string(mandatory = True),
        "os": attr.string(mandatory = True),
        "exec_triple": attr.string(),
        "target_triple": attr.string(),
        "_crosstool": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
        "opt_level": attr.string_dict(default = {
            "opt": "3",
            "dbg": "0",
            "fastbuild": "0",
        }),
        "debug_info": attr.string_dict(default = {
            "opt": "0",
            "dbg": "2",
            "fastbuild": "0",
        }),
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
    name = "rust_cpuX",
    exec_compatible_with = [
      "@bazel_tools//platforms:cpuX",
    ],
    target_compatible_with = [
      "@bazel_tools//platforms:cpuX",
    ],
    toolchain = ":rust_cpuX_impl",
  )

  rust_toolchain(
    name = "rust_cpuX_impl",
    rustc = "@rust_cpuX//:rustc",
    rustc_lib = ["@rust_cpuX//:rustc_lib"],
    rust_lib = ["@rust_cpuX//:rust_lib"],
    rust_doc = "@rust_cpuX//:rustdoc",
    staticlib_ext = ".a",
    dylib_ext = ".so",
    os = "linux",
  )
  ```

  Then, either add the label of the toolchain rule to register_toolchains in the WORKSPACE, or pass
  it to the "--extra_toolchains" flag for Bazel, and it will be used.

  See @io_bazel_rules_rust//rust:repositories.bzl for examples of defining the @rust_cpuX repository
  with the actual binaries and libraries.
"""

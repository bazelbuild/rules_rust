"""The rust_toolchain rule definition and implementation."""

def _rust_toolchain_impl(ctx):
    """The rust_toolchain implementation

    Args:
        ctx (ctx): The rule's context object

    Returns:
        list: A list containing the target's toolchain Provider info
    """
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
        rustfmt = ctx.file.rustfmt,
        cargo = ctx.file.cargo,
        clippy_driver = ctx.file.clippy_driver,
        rustc_lib = ctx.attr.rustc_lib,
        rust_lib = ctx.attr.rust_lib,
        binary_ext = ctx.attr.binary_ext,
        staticlib_ext = ctx.attr.staticlib_ext,
        dylib_ext = ctx.attr.dylib_ext,
        stdlib_linkflags = ctx.attr.stdlib_linkflags,
        target_triple = ctx.attr.target_triple,
        exec_triple = ctx.attr.exec_triple,
        os = ctx.attr.os,
        target_arch = ctx.attr.target_triple.split("-")[0],
        default_edition = ctx.attr.default_edition,
        compilation_mode_opts = compilation_mode_opts,
        crosstool_files = ctx.files._crosstool,
    )
    return [toolchain]

rust_toolchain = rule(
    implementation = _rust_toolchain_impl,
    attrs = {
        "rustc": attr.label(
            doc = "The location of the `rustc` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
        ),
        "rust_doc": attr.label(
            doc = "The location of the `rustdoc` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
        ),
        "rustfmt": attr.label(
            doc = "The location of the `rustfmt` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
        ),
        "cargo": attr.label(
            doc = "The location of the `cargo` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
        ),
        "clippy_driver": attr.label(
            doc = "The location of the `clippy-driver` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
        ),
        "rustc_lib": attr.label(
            doc = "The libraries used by rustc during compilation.",
        ),
        "rust_lib": attr.label(
            doc = "The rust standard library.",
        ),
        "binary_ext": attr.string(
            doc = "The extension for binaries created from rustc.",
            mandatory = True,
        ),
        "staticlib_ext": attr.string(
            doc = "The extension for static libraries created from rustc.",
            mandatory = True,
        ),
        "dylib_ext": attr.string(
            doc = "The extension for dynamic libraries created from rustc.",
            mandatory = True,
        ),
        "stdlib_linkflags": attr.string_list(
            doc = (
                "Additional linker libs used when std lib is linked, " +
                "see https://github.com/rust-lang/rust/blob/master/src/libstd/build.rs"
            ),
            mandatory = True,
        ),
        "os": attr.string(
            doc = "The operating system for the current toolchain",
            mandatory = True,
        ),
        "default_edition": attr.string(
            doc = "The edition to use for rust_* rules that don't specify an edition.",
            default = "2015",
        ),
        "exec_triple": attr.string(
            doc = (
                "The platform triple for the toolchains execution environment. " +
                "For more details see: https://docs.bazel.build/versions/master/skylark/rules.html#configurations"
            ),
        ),
        "target_triple": attr.string(
            doc = (
                "The platform triple for the toolchains target environment. " +
                "For more details see: https://docs.bazel.build/versions/master/skylark/rules.html#configurations"
            ),
        ),
        "opt_level": attr.string_dict(
            doc = "Rustc optimization levels.",
            default = {
                "opt": "3",
                "dbg": "0",
                "fastbuild": "0",
            },
        ),
        "debug_info": attr.string_dict(
            doc = "Rustc debug info levels per opt level",
            default = {
                "opt": "0",
                "dbg": "2",
                "fastbuild": "0",
            },
        ),
        "_crosstool": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
    },
    doc = """Declares a Rust toolchain for use.

This is for declaring a custom toolchain, eg. for configuring a particular version of rust or supporting a new platform.

Example:

Suppose the core rust team has ported the compiler to a new target CPU, called `cpuX`. This \
support can be used in Bazel by defining a new toolchain definition and declaration:

```python
load('@io_bazel_rules_rust//rust:toolchain.bzl', 'rust_toolchain')

rust_toolchain(
    name = "rust_cpuX_impl",
    rustc = "@rust_cpuX//:rustc",
    rustc_lib = "@rust_cpuX//:rustc_lib",
    rust_lib = "@rust_cpuX//:rust_lib",
    rust_doc = "@rust_cpuX//:rustdoc",
    binary_ext = "",
    staticlib_ext = ".a",
    dylib_ext = ".so",
    stdlib_linkflags = ["-lpthread", "-ldl"],
    os = "linux",
)

toolchain(
    name = "rust_cpuX",
    exec_compatible_with = [
        "@platforms//cpu:cpuX",
    ],
    target_compatible_with = [
        "@platforms//cpu:cpuX",
    ],
    toolchain = ":rust_cpuX_impl",
)
```

Then, either add the label of the toolchain rule to `register_toolchains` in the WORKSPACE, or pass \
it to the `"--extra_toolchains"` flag for Bazel, and it will be used.

See @io_bazel_rules_rust//rust:repositories.bzl for examples of defining the @rust_cpuX repository \
with the actual binaries and libraries.
""",
)

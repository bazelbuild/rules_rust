"""Rust Cbindgen rules"""

load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_rust//rust:rust_common.bzl", "CrateInfo", "DepInfo", "TestCrateInfo")
load("//private:cargo_manifest.bzl", "CargoManifestInfo", "cargo_manifest_aspect")

def _c_identifier(name):
    """Convert a string into a valid C/C++ identifier.

    Bazel target names allow characters (e.g. `-` or `.`) which are not legal
    in C/C++ identifiers such as include guards and namespaces.

    Args:
        name (str): The string to convert.

    Returns:
        str: `name` with all illegal characters replaced by `_`.
    """
    identifier = "".join([
        char if char.isalnum() else "_"
        for char in name.elems()
    ])
    if identifier[0].isdigit():
        identifier = "_" + identifier
    return identifier

def _rust_cbindgen_library_impl(ctx):
    rust_lib = ctx.attr.lib

    # rust_library exposes a CrateInfo directly. rust_shared_library and
    # rust_static_library deliberately do not advertise a CrateInfo; they wrap
    # it in a TestCrateInfo instead. Accept either so cbindgen can read the
    # crate sources (and deps) in both cases.
    if CrateInfo in rust_lib:
        crate_info = rust_lib[CrateInfo]
    elif TestCrateInfo in rust_lib:
        crate_info = rust_lib[TestCrateInfo].crate
    else:
        fail("Expected a Rust library target (`rust_shared_library` or `rust_static_library`) for `lib` but got '{}'".format(
            rust_lib.label,
        ))

    supported_crate_types = ["cdylib", "staticlib"]
    if not crate_info.type in supported_crate_types:
        fail("Rust library '{}' of type '{}' must be one of {}".format(
            rust_lib.label,
            crate_info.type,
            supported_crate_types,
        ))

    if CargoManifestInfo not in rust_lib:
        fail("No Cargo manifest was generated for '{}'. The target passed to `lib` must be a Rust library rule.".format(
            rust_lib.label,
        ))

    # Determine the location of the cbindgen executable
    toolchain = ctx.toolchains[Label("//:toolchain_type")]
    cbindgen_bin = toolchain.cbindgen

    # Optionally use the user defined config if one is provided
    if ctx.file.config:
        template_config = ctx.file.config
        substitutions = ctx.attr.substitutions
    else:
        if ctx.attr.substitutions:
            fail("'substitutions' should not be defined without the `config` attribute also being defined.")

        # Identify the desired language
        use_c = ctx.attr.lang == "c"

        template_config = ctx.file._config_default_template

        identifier = _c_identifier(ctx.label.name)
        substitutions = {
            "{include_guard}": "INCLUDE_{}_H".format(identifier.upper()),
            "{label}": str(ctx.label),
            "{language}": "C" if use_c else "C++",
            "{namespace}": "" if use_c else "namespace = \"{}\"".format(identifier),
        }

    # Generate the `cbindgen.toml` config file
    ctx.actions.expand_template(
        template = template_config,
        output = ctx.outputs.config,
        substitutions = substitutions,
    )

    output_header = ctx.actions.declare_file(
        ctx.attr.header_name if ctx.attr.header_name else "{}.h".format(ctx.label.name),
    )

    args = ctx.actions.args()
    args.add(ctx.outputs.config, format = "--config=%s")
    args.add(output_header, format = "--output=%s")
    args.add_all(ctx.attr.cbindgen_flags)
    args.add(rust_lib[CargoManifestInfo].toml.dirname)

    # The crate's own sources come from its crate info. The sources of
    # dependency crates are supplied separately by the cargo manifest aspect
    # via `OutputGroupInfo.all_files`.
    inputs = depset(
        crate_info.srcs.to_list() + [ctx.outputs.config],
        transitive = [
            rust_lib[OutputGroupInfo].all_files,
        ],
    )

    # cbindgen invokes `cargo metadata` to locate the crate's dependencies so
    # the Rust toolchain must be made available to the action.
    rust_toolchain = ctx.toolchains[Label("@rules_rust//rust:toolchain_type")]

    env = {
        "CARGO": rust_toolchain.cargo.path,
        "HOST": rust_toolchain.exec_triple.str,
        "RUSTC": rust_toolchain.rustc.path,
        "TARGET": rust_toolchain.target_triple.str,
    }

    ctx.actions.run(
        mnemonic = "RustCbindgen",
        progress_message = "Generating cbindgen bindings for '{}'..".format(
            output_header.short_path,
        ),
        outputs = [output_header],
        executable = cbindgen_bin,
        inputs = inputs,
        arguments = [args],
        tools = rust_toolchain.all_files,
        env = env,
        toolchain = Label("//:toolchain_type"),
    )

    rust_compilation_context = rust_lib[CcInfo].compilation_context

    # Add the new headers to the existing CompilationContext info
    compilation_context = cc_common.create_compilation_context(
        headers = depset([output_header], transitive = [rust_compilation_context.headers]),
        defines = rust_compilation_context.defines,
        framework_includes = rust_compilation_context.framework_includes,
        includes = rust_compilation_context.includes,
        local_defines = rust_compilation_context.local_defines,
        quote_includes = rust_compilation_context.quote_includes,
        system_includes = rust_compilation_context.system_includes,
    )

    # Return all providers given by the underlying library to ensure
    # compatibility with other rules
    providers = [
        CcInfo(
            compilation_context = compilation_context,
            linking_context = rust_lib[CcInfo].linking_context,
        ),
        DefaultInfo(
            files = depset([output_header], transitive = [rust_lib.files]),
            runfiles = ctx.runfiles([output_header], transitive_files = rust_lib.files),
        ),
        OutputGroupInfo(
            cbindgen_header = depset([output_header]),
        ),
    ]

    # Only re-provide CrateInfo and DepInfo if the wrapped library advertises
    # them directly (rust_library does; rust_shared_library and
    # rust_static_library intentionally do not).
    if CrateInfo in rust_lib:
        providers.append(rust_lib[CrateInfo])
    if DepInfo in rust_lib:
        providers.append(rust_lib[DepInfo])

    return providers

rust_cbindgen_library = rule(
    doc = """\
Generates a C (or C++) header for a Rust library using [cbindgen](https://github.com/mozilla/cbindgen) \
and forwards the library's providers so the target can be consumed by `cc_library`, `cc_binary`, \
and `cc_test` targets as a direct replacement of the library passed to `lib`.
""",
    implementation = _rust_cbindgen_library_impl,
    attrs = {
        "cbindgen_flags": attr.string_list(
            doc = (
                "Optional flags to pass directly to the cbindgen executable. " +
                "See https://github.com/mozilla/cbindgen/blob/master/docs.md for details."
            ),
        ),
        "config": attr.label(
            doc = "Optional cbindgen configuration template",
            allow_single_file = True,
        ),
        "header_name": attr.string(
            doc = (
                "Optional override for the name of the generated header. The default is the " +
                "name of the target created by this rule."
            ),
        ),
        "lang": attr.string(
            doc = "Optional target language identifier of the generated header file",
            values = [
                "c",
                "cc",
                "c++",
                "cxx",
            ],
            default = "cc",
        ),
        "lib": attr.label(
            doc = (
                "The Rust library target for which to run cbindgen. The `crate_type` of the " +
                "target passed here must be either `cdylib` or `staticlib`."
            ),
            providers = [CcInfo],
            aspects = [cargo_manifest_aspect],
            mandatory = True,
        ),
        "substitutions": attr.string_dict(
            doc = "Optional substitutions for the cbindgen config template passed to `config`",
        ),
        "_config_default_template": attr.label(
            doc = "Default cbindgen configuration template. This is treated as fallback from `config`",
            default = Label("//private:cbindgen.toml.template"),
            allow_single_file = True,
        ),
    },
    outputs = {
        "config": "%{name}.cbindgen.toml",
    },
    toolchains = [
        config_common.toolchain_type("//:toolchain_type"),
        config_common.toolchain_type("@rules_rust//rust:toolchain_type"),
    ],
)

def _rust_cbindgen_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        cbindgen = ctx.executable.cbindgen,
    )]

rust_cbindgen_toolchain = rule(
    doc = """\
The tools required for the `rust_cbindgen_library` rule.

This rule depends on the [`cbindgen`](https://crates.io/crates/cbindgen) binary crate.

```python
load("@rules_rust_cbindgen//:defs.bzl", "rust_cbindgen_toolchain")

rust_cbindgen_toolchain(
    name = "cbindgen_toolchain_impl",
    cbindgen = "//my/cbindgen:cbindgen",
)

toolchain(
    name = "cbindgen_toolchain",
    toolchain = "cbindgen_toolchain_impl",
    toolchain_type = "@rules_rust_cbindgen//:toolchain_type",
)
```

This toolchain will then need to be registered in the current `MODULE.bazel` file.
For additional information, see the [Bazel toolchains documentation](https://docs.bazel.build/versions/master/toolchains.html).
""",
    implementation = _rust_cbindgen_toolchain_impl,
    attrs = {
        "cbindgen": attr.label(
            doc = "The label of a `cbindgen` executable.",
            executable = True,
            cfg = "exec",
        ),
    },
)

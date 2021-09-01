"""Rust toolchain rule definitions and implementations."""

load("//rust/private:common.bzl", "rust_common")
load("//rust/private:toolchain_utils.bzl", "find_cc_toolchain", "generate_sysroot")
load("//rust/private:utils.bzl", "dedent", "make_static_lib_symlink")
load("//rust/settings:incompatible.bzl", "IncompatibleFlagInfo")

def _rust_stdlib_filegroup_impl(ctx):
    rust_lib = ctx.files.srcs
    dot_a_files = []
    between_alloc_and_core_files = []
    core_files = []
    between_core_and_std_files = []
    std_files = []
    alloc_files = []
    self_contained_files = [
        file
        for file in rust_lib
        if file.basename.endswith(".o") and "self-contained" in file.path
    ]

    std_rlibs = [f for f in rust_lib if f.basename.endswith(".rlib")]
    if std_rlibs:
        # std depends on everything
        #
        # core only depends on alloc, but we poke adler in there
        # because that needs to be before miniz_oxide
        #
        # alloc depends on the allocator_library if it's configured, but we
        # do that later.
        dot_a_files = [make_static_lib_symlink(ctx.actions, f) for f in std_rlibs]

        alloc_files = [f for f in dot_a_files if "alloc" in f.basename and "std" not in f.basename]
        between_alloc_and_core_files = [f for f in dot_a_files if "compiler_builtins" in f.basename]
        core_files = [f for f in dot_a_files if ("core" in f.basename or "adler" in f.basename) and "std" not in f.basename]
        between_core_and_std_files = [
            f
            for f in dot_a_files
            if "alloc" not in f.basename and "compiler_builtins" not in f.basename and "core" not in f.basename and "adler" not in f.basename and "std" not in f.basename
        ]
        std_files = [f for f in dot_a_files if "std" in f.basename]

        partitioned_files_len = len(alloc_files) + len(between_alloc_and_core_files) + len(core_files) + len(between_core_and_std_files) + len(std_files)
        if partitioned_files_len != len(dot_a_files):
            partitioned = alloc_files + between_alloc_and_core_files + core_files + between_core_and_std_files + std_files
            for f in sorted(partitioned):
                # buildifier: disable=print
                print("File partitioned: {}".format(f.basename))
            fail("rust_toolchain couldn't properly partition rlibs in rust_lib. Partitioned {} out of {} files. This is probably a bug in the rule implementation.".format(partitioned_files_len, len(dot_a_files)))

    return [
        DefaultInfo(
            files = depset(ctx.files.srcs),
        ),
        rust_common.stdlib_info(
            std_rlibs = std_rlibs,
            dot_a_files = dot_a_files,
            between_alloc_and_core_files = between_alloc_and_core_files,
            core_files = core_files,
            between_core_and_std_files = between_core_and_std_files,
            std_files = std_files,
            alloc_files = alloc_files,
            self_contained_files = self_contained_files,
        ),
    ]

rust_stdlib_filegroup = rule(
    doc = "A dedicated filegroup-like rule for Rust stdlib artifacts.",
    implementation = _rust_stdlib_filegroup_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
            doc = "The list of targets/files that are components of the rust-stdlib file group",
            mandatory = True,
        ),
    },
)

def _ltl(library, ctx, cc_toolchain, feature_configuration):
    """A helper to generate `LibraryToLink` objects

    Args:
        library (File): A rust library file to link.
        ctx (ctx): The rule's context object.
        cc_toolchain (CcToolchainInfo): A cc toolchain provider to be used.
        feature_configuration (feature_configuration): feature_configuration to be queried.

    Returns:
        LibraryToLink: A provider containing information about libraries to link.
    """
    return cc_common.create_library_to_link(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        static_library = library,
        pic_static_library = library,
    )

def _make_libstd_and_allocator_ccinfo(ctx, rust_lib, allocator_library):
    """Make the CcInfo (if possible) for libstd and allocator libraries.

    Args:
        ctx (ctx): The rule's context object.
        rust_lib: The rust standard library.
        allocator_library: The target to use for providing allocator functions.


    Returns:
        A CcInfo object for the required libraries, or None if no such libraries are available.
    """
    cc_toolchain, feature_configuration = find_cc_toolchain(ctx)
    cc_infos = []

    if not rust_common.stdlib_info in ctx.attr.rust_stdlib:
        fail(dedent("""\
            {} --
            The `rust_lib` ({}) must be a target providing `rust_common.stdlib_info`
            (typically `rust_stdlib_filegroup` rule from @rules_rust//rust:defs.bzl).
            See https://github.com/bazelbuild/rules_rust/pull/802 for more information.
        """).format(ctx.label, ctx.attr.rust_stdlib))
    rust_stdlib_info = ctx.attr.rust_stdlib[rust_common.stdlib_info]

    if rust_stdlib_info.self_contained_files:
        compilation_outputs = cc_common.create_compilation_outputs(
            objects = depset(rust_stdlib_info.self_contained_files),
        )

        linking_context, _linking_outputs = cc_common.create_linking_context_from_compilation_outputs(
            name = ctx.label.name,
            actions = ctx.actions,
            feature_configuration = feature_configuration,
            cc_toolchain = cc_toolchain,
            compilation_outputs = compilation_outputs,
        )

        cc_infos.append(CcInfo(
            linking_context = linking_context,
        ))

    if rust_stdlib_info.std_rlibs:
        alloc_inputs = depset(
            [_ltl(f, ctx, cc_toolchain, feature_configuration) for f in rust_stdlib_info.alloc_files],
        )
        between_alloc_and_core_inputs = depset(
            [_ltl(f, ctx, cc_toolchain, feature_configuration) for f in rust_stdlib_info.between_alloc_and_core_files],
            transitive = [alloc_inputs],
            order = "topological",
        )
        core_inputs = depset(
            [_ltl(f, ctx, cc_toolchain, feature_configuration) for f in rust_stdlib_info.core_files],
            transitive = [between_alloc_and_core_inputs],
            order = "topological",
        )

        # The libraries panic_abort and panic_unwind are alternatives.
        # The std by default requires panic_unwind.
        # Exclude panic_abort if panic_unwind is present.
        # TODO: Provide a setting to choose between panic_abort and panic_unwind.
        filtered_between_core_and_std_files = rust_stdlib_info.between_core_and_std_files
        has_panic_unwind = [
            f
            for f in filtered_between_core_and_std_files
            if "panic_unwind" in f.basename
        ]
        if has_panic_unwind:
            filtered_between_core_and_std_files = [
                f
                for f in filtered_between_core_and_std_files
                if "panic_abort" not in f.basename
            ]
        between_core_and_std_inputs = depset(
            [
                _ltl(f, ctx, cc_toolchain, feature_configuration)
                for f in filtered_between_core_and_std_files
            ],
            transitive = [core_inputs],
            order = "topological",
        )
        std_inputs = depset(
            [
                _ltl(f, ctx, cc_toolchain, feature_configuration)
                for f in rust_stdlib_info.std_files
            ],
            transitive = [between_core_and_std_inputs],
            order = "topological",
        )

        link_inputs = cc_common.create_linker_input(
            owner = rust_lib.label,
            libraries = std_inputs,
        )

        allocator_inputs = None
        if allocator_library:
            allocator_inputs = [allocator_library[CcInfo].linking_context.linker_inputs]

        cc_infos.append(CcInfo(
            linking_context = cc_common.create_linking_context(
                linker_inputs = depset(
                    [link_inputs],
                    transitive = allocator_inputs,
                    order = "topological",
                ),
            ),
        ))

    if cc_infos:
        return cc_common.merge_cc_infos(
            direct_cc_infos = cc_infos,
        )
    return None

def _rust_toolchain_impl(ctx):
    """The rust_toolchain implementation

    Args:
        ctx (ctx): The rule's context object

    Returns:
        list: A list containing the target's toolchain Provider info
    """
    exec_toolchain = ctx.toolchains[Label("@rules_rust//rust:exec_toolchain")]
    target_toolchain = ctx.toolchains[Label("@rules_rust//rust:target_toolchain")]

    exec_version = struct(
        version = exec_toolchain.version,
        iso_date = exec_toolchain.iso_date,
    )

    target_version = struct(
        version = target_toolchain.version,
        iso_date = target_toolchain.iso_date,
    )

    if exec_version != target_version:
        fail("The exec and target toolchains do not have matching versions\nexec = {}\ntarget = {}".format(
            exec_version,
            target_version,
        ))

    sysroot = generate_sysroot(
        ctx = ctx,
        exec_toolchain = exec_toolchain,
        target_toolchain = target_toolchain,
    )

    return platform_common.ToolchainInfo(
        binary_ext = target_toolchain.binary_ext,
        compilation_mode_opts = target_toolchain.compilation_mode_opts,
        crosstool_files = exec_toolchain.crosstool_files,
        default_edition = exec_toolchain.default_edition,
        dylib_ext = target_toolchain.dylib_ext,
        exec_triple = exec_toolchain.triple,
        libstd_and_allocator_ccinfo = target_toolchain.libstd_and_allocator_ccinfo,
        os = target_toolchain.os,
        rust_lib = sysroot.rust_stdlib,  # TODO: This value is deprecated, use `rust_stdlib` instead
        rust_stdlib = sysroot.rust_stdlib,
        rustc = sysroot.rustc,
        rustc_lib = sysroot.rustc_lib,
        rustc_srcs = exec_toolchain.rustc_srcs,
        rustdoc = sysroot.rustdoc,
        staticlib_ext = target_toolchain.staticlib_ext,
        stdlib_linkflags = target_toolchain.stdlib_linkflags,
        sysroot_anchor = sysroot.sysroot_anchor,
        sysroot_files = sysroot.sysroot_files,
        target_arch = target_toolchain.triple.split("-")[0],
        target_flag_value = target_toolchain.target_flag_value,
        target_json = target_toolchain.target_json,
        target_triple = target_toolchain.triple,
        _incompatible_make_rust_providers_target_independent = exec_toolchain._incompatible_make_rust_providers_target_independent,
    )

rust_toolchain = rule(
    doc = dedent("""\
    Declares a Rust exec/host + target toolchain for use.

    This takes a [rust_exec_toolchain](#rust_exec_toolchain) and a [rust_target_toolchain](#rust_target_toolchain) and creates
    a [sysroot](https://doc.rust-lang.org/stable/rustc/command-line-arguments.html#--sysroot-override-the-system-root) 
    containing all Rust components needed to build in the execution environment for the target platform. This
    toolchain allows Bazel's toolchain resolution to, on-demand, gather the necessary components to perform an action
    without forcing users to generate complete sysroots for all combinations of `exec -> target(s)` expected to be
    built.

    A generated sysroot is expected to look like the following:

    ```text
    rust/toolchain/current/
        bin/
            rustc -> ${CACHE_LOCATION}/rustc
            rustdoc -> ${CACHE_LOCATION}/rustdoc
        lib/
            lib*.so -> ${CACHE_LOCATION}/lib*.so
            ...
            rustlib/
                x86_64-unknown-linux-gnu/
                    bin/
                        rust-lld -> ${CACHE_LOCATION}/rust-lld
                    lib/
                        lib*.rlib -> ${CACHE_LOCATION}/lib*.rlib
                        ...
        rules_rust.sysroot -> ${CACHE_LOCATION}/rules_rust.sysroot
    ```

    The tree above assumes that the contents of `rust_exec_toolchain` and `rust_target_toolchain` can
    be directly used in the sysroot, meaning the files use the same paths from the root of their
    repositories and are not expected to contain any conflicts. Though, both toolchains may provide
    contents for the same directory, where above `./lib/rustlib/x86_64-unknown-linux-gnu` contains a
    `bin` directory from the exec toolchain and a `lib` directory from the target toolchain.
    """),
    implementation = _rust_toolchain_impl,
    toolchains = [
        str(Label("//rust:exec_toolchain")),
        str(Label("//rust:target_toolchain")),
    ],
    incompatible_use_toolchain_transition = True,
)

def _rust_exec_toolchain_impl(ctx):
    """The rust_exec_toolchain implementation

    Args:
        ctx (ctx): The rule's context object

    Returns:
        list: A list containing the target's toolchain Provider info
    """

    make_rust_providers_target_independent = ctx.attr._incompatible_make_rust_providers_target_independent[IncompatibleFlagInfo]

    return platform_common.ToolchainInfo(
        arch = ctx.attr.triple.split("-")[0],
        crosstool_files = ctx.files._crosstool,
        default_edition = ctx.attr.default_edition,
        iso_date = ctx.attr.iso_date,
        os = ctx.attr.os,
        rustc = ctx.file.rustc,
        rustc_lib = ctx.attr.rustc_lib,
        rustc_srcs = ctx.attr.rustc_srcs,
        rustdoc = ctx.file.rustdoc,
        triple = ctx.attr.triple,
        version = ctx.attr.version,
        _incompatible_make_rust_providers_target_independent = make_rust_providers_target_independent.enabled,
    )

rust_exec_toolchain = rule(
    doc = dedent("""\
    Declares a Rust exec/host toolchain for use.

    This is for declaring a custom host toolchain (as described by [The rustc book](https://doc.rust-lang.org/stable/rustc/platform-support.html)),
    eg. for configuring a particular version of rust or supporting a new platform.

    Example:

    Suppose the core rust team has ported the compiler to a new target CPU, called `cpuX`. This
    support can be used in Bazel by defining a new toolchain definition and declaration:

    ```python
    load('@rules_rust//rust:toolchain.bzl', 'rust_exec_toolchain')

    rust_exec_toolchain(
        name = "rust_cpuX_impl",
        # see attributes...
    )

    toolchain(
        name = "rust_cpuX",
        exec_compatible_with = [
            "@platforms//cpu:cpuX",
        ],
        toolchain = ":rust_cpuX_impl",
        toolchain_type = "@rules_rust//rust:exec_toolchain",
    )
    ```

    Then, either add the label of the toolchain rule to `register_toolchains` in the WORKSPACE, or pass
    it to the `"--extra_toolchains"` flag for Bazel, and it will be used.

    See @rules_rust//rust:repositories.bzl for examples of defining the @rust_cpuX repository
    with the actual binaries and libraries.
    """),
    implementation = _rust_exec_toolchain_impl,
    fragments = ["cpp"],
    attrs = {
        "default_edition": attr.string(
            doc = "The edition to use for rust_* rules that don't specify an edition.",
            default = rust_common.default_version,
        ),
        "iso_date": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
        ),
        "os": attr.string(
            doc = "The operating system for the current toolchain",
            mandatory = True,
        ),
        "rustc": attr.label(
            doc = "The location of the `rustc` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            mandatory = True,
            cfg = "exec",
        ),
        "rustc_lib": attr.label(
            doc = "The location of the `rustc` binary. Can be a direct source or a filegroup containing one item.",
            allow_files = True,
            mandatory = True,
            cfg = "exec",
        ),
        "rustc_srcs": attr.label(
            doc = "The source code of rustc.",
        ),
        "rustdoc": attr.label(
            doc = "The location of the `rustdoc` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            cfg = "exec",
        ),
        "triple": attr.string(
            doc = (
                "The platform triple for the toolchains execution environment. " +
                "For more details see: https://docs.bazel.build/versions/master/skylark/rules.html#configurations"
            ),
        ),
        "version": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
            mandatory = True,
        ),
        "_cc_toolchain": attr.label(
            default = "@bazel_tools//tools/cpp:current_cc_toolchain",
            cfg = "exec",
        ),
        "_crosstool": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
            cfg = "exec",
        ),
        "_incompatible_make_rust_providers_target_independent": attr.label(
            default = "@rules_rust//rust/settings:incompatible_make_rust_providers_target_independent",
        ),
    },
    toolchains = [
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    incompatible_use_toolchain_transition = True,
)

def _rust_target_toolchain_impl(ctx):
    compilation_mode_opts = {}
    for k, v in ctx.attr.opt_level.items():
        if not k in ctx.attr.debug_info:
            fail("Compilation mode {} is not defined in debug_info but is defined opt_level".format(k))
        compilation_mode_opts[k] = struct(debug_info = ctx.attr.debug_info[k], opt_level = v)
    for k, v in ctx.attr.debug_info.items():
        if not k in ctx.attr.opt_level:
            fail("Compilation mode {} is not defined in opt_level but is defined debug_info".format(k))

    if ctx.attr.triple and ctx.file.target_json:
        fail("Do not specify both target_triple and target_json, either use a builtin triple or provide a custom specification file.")

    return platform_common.ToolchainInfo(
        arch = ctx.attr.triple.split("-")[0],
        binary_ext = ctx.attr.binary_ext,
        compilation_mode_opts = compilation_mode_opts,
        dylib_ext = ctx.attr.dylib_ext,
        iso_date = ctx.attr.iso_date,
        libstd_and_allocator_ccinfo = _make_libstd_and_allocator_ccinfo(ctx, ctx.attr.rust_stdlib, ctx.attr.allocator_library),
        os = ctx.attr.os,
        rust_stdlib = ctx.attr.rust_stdlib,
        staticlib_ext = ctx.attr.staticlib_ext,
        stdlib_linkflags = ctx.attr.stdlib_linkflags,
        triple = ctx.attr.triple,
        target_json = ctx.file.target_json,
        target_flag_value = ctx.file.target_json.path if ctx.file.target_json else ctx.attr.triple,
        version = ctx.attr.version,
    )

rust_target_toolchain = rule(
    doc = dedent("""\
    Declares a Rust target toolchain for use.

    This is for declaring a custom toolchain which contains details about the target platform as well as
    provide a `rust-std` artifact to the sysroot for targets that depend on the stardard library.

    Example:

    Suppose the core rust team has added a new platform to tier 2 support with a `rust-std` artifact called 
    `aarch256-raven-microcyber`. This support can be used in Bazel by defining a new toolchain definition 
    and declaration:

    ```python
    load('@rules_rust//rust:toolchain.bzl', 'rust_target_toolchain')

    rust_target_toolchain(
        name = "rust_aarch256_raven_microcyber_impl",
        # see attributes...
    )

    toolchain(
        name = "rust_aarch256_raven_microcyber",
        target_compatible_with = [
            "@platforms//cpu:aarch2077",
            "@platforms//os:microcyber",
        ],
        toolchain = ":rust_aarch256_raven_microcyber_impl",
        toolchain_type = "@rules_rust//rust:target_toolchain",
    )
    ```
    """),
    implementation = _rust_target_toolchain_impl,
    fragments = ["cpp"],
    attrs = {
        "allocator_library": attr.label(
            doc = "Target that provides allocator functions when rust_library targets are embedded in a cc_binary.",
        ),
        "binary_ext": attr.string(
            doc = "The extension for binaries created from rustc.",
            mandatory = True,
        ),
        "debug_info": attr.string_dict(
            doc = "Rustc debug info levels per opt level",
            default = {
                "dbg": "2",
                "fastbuild": "0",
                "opt": "0",
            },
        ),
        "dylib_ext": attr.string(
            doc = "The extension for dynamic libraries created from rustc.",
            mandatory = True,
        ),
        "iso_date": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
        ),
        "opt_level": attr.string_dict(
            doc = "Rustc optimization levels.",
            default = {
                "dbg": "0",
                "fastbuild": "0",
                "opt": "3",
            },
        ),
        "os": attr.string(
            doc = "The operating system for the current toolchain",
            mandatory = True,
        ),
        "rust_stdlib": attr.label(
            doc = "The rust standard library.",
            mandatory = True,
        ),
        "staticlib_ext": attr.string(
            doc = "The extension for static libraries created from rustc.",
            mandatory = True,
        ),
        "stdlib_linkflags": attr.string_list(
            doc = (
                "Additional linker libs used when std lib is linked, " +
                "see https://github.com/rust-lang/rust/blob/master/src/libstd/build.rs"
            ),
            mandatory = True,
        ),
        "target_json": attr.label(
            doc = ("Override the target_triple with a custom target specification. " +
                   "For more details see: https://doc.rust-lang.org/rustc/targets/custom.html"),
            allow_single_file = True,
        ),
        "triple": attr.string(
            doc = (
                "The platform triple for the toolchains execution environment. " +
                "For more details see: https://docs.bazel.build/versions/master/skylark/rules.html#configurations"
            ),
        ),
        "version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
            mandatory = True,
        ),
        "_cc_toolchain": attr.label(
            default = "@bazel_tools//tools/cpp:current_cc_toolchain",
            cfg = "target",
        ),
    },
    toolchains = [
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    incompatible_use_toolchain_transition = True,
)

def _rust_cargo_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        cargo = ctx.file.cargo,
    )]

rust_cargo_toolchain = rule(
    doc = "Declares a [Cargo](https://doc.rust-lang.org/cargo/) toolchain for use.",
    implementation = _rust_cargo_toolchain_impl,
    attrs = {
        "cargo": attr.label(
            doc = "The location of the `cargo` binary.",
            allow_single_file = True,
            mandatory = True,
        ),
    },
    incompatible_use_toolchain_transition = True,
)

def _rust_clippy_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        clippy_driver = ctx.file.clippy_driver,
    )]

rust_clippy_toolchain = rule(
    doc = "Declares a [Clippy](https://github.com/rust-lang/rust-clippy#readme) toolchain for use.",
    implementation = _rust_clippy_toolchain_impl,
    attrs = {
        "clippy_driver": attr.label(
            doc = "The location of the `clippy-driver` binary.",
            allow_single_file = True,
            mandatory = True,
        ),
    },
    incompatible_use_toolchain_transition = True,
)

def _rust_rustfmt_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        rustfmt = ctx.file.rustfmt,
    )]

rust_rustfmt_toolchain = rule(
    doc = "Declares a [Rustfmt](https://github.com/rust-lang/rustfmt#readme) toolchain for use.",
    implementation = _rust_rustfmt_toolchain_impl,
    attrs = {
        "rustfmt": attr.label(
            doc = "The location of the `rustfmt` binary.",
            allow_single_file = True,
            mandatory = True,
        ),
    },
    incompatible_use_toolchain_transition = True,
)

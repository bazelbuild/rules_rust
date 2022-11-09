"""The rust_toolchain rule definition and implementation."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("//rust/private:common.bzl", "rust_common")
load("//rust/private:rust_analyzer.bzl", _rust_analyzer_toolchain = "rust_analyzer_toolchain")
load(
    "//rust/private:utils.bzl",
    "dedent",
    "dedup_expand_location",
    "find_cc_toolchain",
    "make_static_lib_symlink",
)

rust_analyzer_toolchain = _rust_analyzer_toolchain

def _rust_stdlib_filegroup_impl(ctx):
    rust_std = ctx.files.srcs
    dot_a_files = []
    between_alloc_and_core_files = []
    core_files = []
    between_core_and_std_files = []
    std_files = []
    test_files = []
    memchr_files = []
    alloc_files = []
    self_contained_files = [
        file
        for file in rust_std
        if file.basename.endswith(".o") and "self-contained" in file.path
    ]

    std_rlibs = [f for f in rust_std if f.basename.endswith(".rlib")]
    if std_rlibs:
        # test depends on std
        # std depends on everything except test
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
            if "alloc" not in f.basename and "compiler_builtins" not in f.basename and "core" not in f.basename and "adler" not in f.basename and "std" not in f.basename and "memchr" not in f.basename and "test" not in f.basename
        ]
        memchr_files = [f for f in dot_a_files if "memchr" in f.basename]
        std_files = [f for f in dot_a_files if "std" in f.basename]
        test_files = [f for f in dot_a_files if "test" in f.basename]

        partitioned_files_len = len(alloc_files) + len(between_alloc_and_core_files) + len(core_files) + len(between_core_and_std_files) + len(memchr_files) + len(std_files) + len(test_files)
        if partitioned_files_len != len(dot_a_files):
            partitioned = alloc_files + between_alloc_and_core_files + core_files + between_core_and_std_files + memchr_files + std_files + test_files
            for f in sorted(partitioned):
                # buildifier: disable=print
                print("File partitioned: {}".format(f.basename))
            fail("rust_toolchain couldn't properly partition rlibs in rust_std. Partitioned {} out of {} files. This is probably a bug in the rule implementation.".format(partitioned_files_len, len(dot_a_files)))

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
            test_files = test_files,
            memchr_files = memchr_files,
            alloc_files = alloc_files,
            self_contained_files = self_contained_files,
            srcs = ctx.attr.srcs,
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

def _make_libstd_and_allocator_ccinfo(ctx, rust_std, allocator_library):
    """Make the CcInfo (if possible) for libstd and allocator libraries.

    Args:
        ctx (ctx): The rule's context object.
        rust_std: The Rust standard library.
        allocator_library: The target to use for providing allocator functions.


    Returns:
        A CcInfo object for the required libraries, or None if no such libraries are available.
    """
    cc_toolchain, feature_configuration = find_cc_toolchain(ctx)
    cc_infos = []

    if not rust_common.stdlib_info in rust_std:
        fail(dedent("""\
            {} --
            The `rust_lib` ({}) must be a target providing `rust_common.stdlib_info`
            (typically `rust_stdlib_filegroup` rule from @rules_rust//rust:defs.bzl).
            See https://github.com/bazelbuild/rules_rust/pull/802 for more information.
        """).format(ctx.label, rust_std))
    rust_stdlib_info = rust_std[rust_common.stdlib_info]

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
        memchr_inputs = depset(
            [
                _ltl(f, ctx, cc_toolchain, feature_configuration)
                for f in rust_stdlib_info.memchr_files
            ],
            transitive = [core_inputs],
            order = "topological",
        )
        between_core_and_std_inputs = depset(
            [
                _ltl(f, ctx, cc_toolchain, feature_configuration)
                for f in filtered_between_core_and_std_files
            ],
            transitive = [memchr_inputs],
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
        test_inputs = depset(
            [
                _ltl(f, ctx, cc_toolchain, feature_configuration)
                for f in rust_stdlib_info.test_files
            ],
            transitive = [std_inputs],
            order = "topological",
        )

        link_inputs = cc_common.create_linker_input(
            owner = rust_std.label,
            libraries = test_inputs,
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

def _symlink_sysroot_tree(ctx, name, target):
    """Generate a set of symlinks to files from another target

    Args:
        ctx (ctx): The toolchain's context object
        name (str): The name of the sysroot directory (typically `ctx.label.name`)
        target (Target): A target owning files to symlink

    Returns:
        depset[File]: A depset of the generated symlink files
    """
    tree_files = []
    for file in target.files.to_list():
        # Parse the path to the file relative to the workspace root so a
        # symlink matching this path can be created within the sysroot.

        # The code blow attempts to parse any workspace names out of the
        # path. For local targets, this code is a noop.
        if target.label.workspace_root:
            file_path = file.path.split(target.label.workspace_root, 1)[-1]
        else:
            file_path = file.path

        symlink = ctx.actions.declare_file("{}/{}".format(name, file_path.lstrip("/")))

        ctx.actions.symlink(
            output = symlink,
            target_file = file,
        )

        tree_files.append(symlink)

    return depset(tree_files)

def _symlink_sysroot_bin(ctx, name, directory, target):
    """Crete a symlink to a target file.

    Args:
        ctx (ctx): The rule's context object
        name (str): A common name for the output directory
        directory (str): The directory under `name` to put the file in
        target (File): A File object to symlink to

    Returns:
        File: A newly generated symlink file
    """
    symlink = ctx.actions.declare_file("{}/{}/{}".format(
        name,
        directory,
        target.basename,
    ))

    ctx.actions.symlink(
        output = symlink,
        target_file = target,
        is_executable = True,
    )

    return symlink

def _generate_sysroot(
        ctx,
        rustc,
        rustdoc,
        rustc_lib,
        cargo = None,
        clippy = None,
        llvm_tools = None,
        rust_std = None,
        rustfmt = None):
    """Generate a rust sysroot from collection of toolchain components

    Args:
        ctx (ctx): A context object from a `rust_toolchain` rule.
        rustc (File): The path to a `rustc` executable.
        rustdoc (File): The path to a `rustdoc` executable.
        rustc_lib (Target): A collection of Files containing dependencies of `rustc`.
        cargo (File, optional): The path to a `cargo` executable.
        clippy (File, optional): The path to a `clippy-driver` executable.
        llvm_tools (Target, optional): A collection of llvm tools used by `rustc`.
        rust_std (Target, optional): A collection of Files containing Rust standard library components.
        rustfmt (File, optional): The path to a `rustfmt` executable.

    Returns:
        struct: A struct of generated files representing the new sysroot
    """
    name = ctx.label.name

    # Define runfiles
    direct_files = []
    transitive_file_sets = []

    # Rustc
    sysroot_rustc = _symlink_sysroot_bin(ctx, name, "bin", rustc)
    direct_files.extend([sysroot_rustc])

    # Rustc dependencies
    sysroot_rustc_lib = None
    if rustc_lib:
        sysroot_rustc_lib = _symlink_sysroot_tree(ctx, name, rustc_lib)
        transitive_file_sets.extend([sysroot_rustc_lib])

    # Rustdoc
    sysroot_rustdoc = _symlink_sysroot_bin(ctx, name, "bin", rustdoc)
    direct_files.extend([sysroot_rustdoc])

    # Clippy
    sysroot_clippy = None
    if clippy:
        sysroot_clippy = _symlink_sysroot_bin(ctx, name, "bin", clippy)
        direct_files.extend([sysroot_clippy])

    # Cargo
    sysroot_cargo = None
    if cargo:
        sysroot_cargo = _symlink_sysroot_bin(ctx, name, "bin", cargo)
        direct_files.extend([sysroot_cargo])

    # Rustfmt
    sysroot_rustfmt = None
    if rustfmt:
        sysroot_rustfmt = _symlink_sysroot_bin(ctx, name, "bin", rustfmt)
        direct_files.extend([sysroot_rustfmt])

    # Llvm tools
    sysroot_llvm_tools = None
    if llvm_tools:
        sysroot_llvm_tools = _symlink_sysroot_tree(ctx, name, llvm_tools)
        transitive_file_sets.extend([sysroot_llvm_tools])

    # Rust standard library
    sysroot_rust_std = None
    if rust_std:
        sysroot_rust_std = _symlink_sysroot_tree(ctx, name, rust_std)
        transitive_file_sets.extend([sysroot_rust_std])

    # Declare a file in the root of the sysroot to make locating the sysroot easy
    sysroot_anchor = ctx.actions.declare_file("{}/rust.sysroot".format(name))
    ctx.actions.write(
        output = sysroot_anchor,
        content = "\n".join([
            "cargo: {}".format(cargo),
            "clippy: {}".format(clippy),
            "llvm_tools: {}".format(llvm_tools),
            "rust_std: {}".format(rust_std),
            "rustc_lib: {}".format(rustc_lib),
            "rustc: {}".format(rustc),
            "rustdoc: {}".format(rustdoc),
            "rustfmt: {}".format(rustfmt),
        ]),
    )

    # Create a depset of all sysroot files (symlinks and their real paths)
    all_files = depset(direct_files, transitive = transitive_file_sets)

    return struct(
        all_files = all_files,
        cargo = sysroot_cargo,
        clippy = sysroot_clippy,
        rust_std = sysroot_rust_std,
        rustc = sysroot_rustc,
        rustc_lib = sysroot_rustc_lib,
        rustdoc = sysroot_rustdoc,
        rustfmt = sysroot_rustfmt,
        sysroot_anchor = sysroot_anchor,
    )

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

    if ctx.attr.target_triple and ctx.file.target_json:
        fail("Do not specify both target_triple and target_json, either use a builtin triple or provide a custom specification file.")

    rename_first_party_crates = ctx.attr._rename_first_party_crates[BuildSettingInfo].value
    third_party_dir = ctx.attr._third_party_dir[BuildSettingInfo].value
    pipelined_compilation = ctx.attr._pipelined_compilation[BuildSettingInfo].value

    experimental_use_cc_common_link = ctx.attr.experimental_use_cc_common_link[BuildSettingInfo].value
    if experimental_use_cc_common_link and not ctx.attr.allocator_library:
        fail("rust_toolchain.experimental_use_cc_common_link requires rust_toolchain.allocator_library to be set")

    if ctx.attr.rust_lib:
        # buildifier: disable=print
        print("`rust_toolchain.rust_lib` is deprecated. Please update {} to use `rust_toolchain.rust_std`".format(
            ctx.label,
        ))
        rust_std = ctx.attr.rust_lib
    else:
        rust_std = ctx.attr.rust_std

    sysroot = _generate_sysroot(
        ctx = ctx,
        rustc = ctx.file.rustc,
        rustdoc = ctx.file.rust_doc,
        rustc_lib = ctx.attr.rustc_lib,
        rust_std = rust_std,
        rustfmt = ctx.file.rustfmt,
        clippy = ctx.file.clippy_driver,
        cargo = ctx.file.cargo,
        llvm_tools = ctx.attr.llvm_tools,
    )

    expanded_stdlib_linkflags = []
    for flag in ctx.attr.stdlib_linkflags:
        expanded_stdlib_linkflags.append(
            dedup_expand_location(
                ctx,
                flag,
                targets = rust_std[rust_common.stdlib_info].srcs,
            ),
        )

    linking_context = cc_common.create_linking_context(
        linker_inputs = depset([
            cc_common.create_linker_input(
                owner = ctx.label,
                user_link_flags = depset(expanded_stdlib_linkflags),
            ),
        ]),
    )

    # Contains linker flags needed to link Rust standard library.
    # These need to be added to linker command lines when the linker is not rustc
    # (rustc does this automatically). Linker flags wrapped in an otherwise empty
    # `CcInfo` to provide the flags in a way that doesn't duplicate them per target
    # providing a `CcInfo`.
    stdlib_linkflags_cc_info = CcInfo(
        compilation_context = cc_common.create_compilation_context(),
        linking_context = linking_context,
    )

    # Determine the path and short_path of the sysroot
    sysroot_path = sysroot.sysroot_anchor.dirname
    sysroot_short_path, _, _ = sysroot.sysroot_anchor.short_path.rpartition("/")

    # Variables for make variable expansion
    make_variables = {
        "RUSTC": sysroot.rustc.path,
        "RUSTDOC": sysroot.rustdoc.path,
        "RUST_DEFAULT_EDITION": ctx.attr.default_edition or "",
        "RUST_SYSROOT": sysroot_path,
    }

    if sysroot.cargo:
        make_variables.update({
            "CARGO": sysroot.cargo.path,
        })

    if sysroot.rustfmt:
        make_variables.update({
            "RUSTFMT": sysroot.rustfmt.path,
        })

    make_variable_info = platform_common.TemplateVariableInfo(make_variables)

    toolchain = platform_common.ToolchainInfo(
        all_files = sysroot.all_files,
        binary_ext = ctx.attr.binary_ext,
        cargo = sysroot.cargo,
        clippy_driver = sysroot.clippy,
        compilation_mode_opts = compilation_mode_opts,
        crosstool_files = ctx.files._cc_toolchain,
        default_edition = ctx.attr.default_edition,
        dylib_ext = ctx.attr.dylib_ext,
        env = ctx.attr.env,
        exec_triple = ctx.attr.exec_triple,
        libstd_and_allocator_ccinfo = _make_libstd_and_allocator_ccinfo(ctx, rust_std, ctx.attr.allocator_library),
        llvm_cov = ctx.file.llvm_cov,
        llvm_profdata = ctx.file.llvm_profdata,
        make_variables = make_variable_info,
        os = ctx.attr.os,
        rust_doc = sysroot.rustdoc,
        rust_lib = sysroot.rust_std,  # `rust_lib` is deprecated and only exists for legacy support.
        rust_std = sysroot.rust_std,
        rust_std_paths = depset([file.dirname for file in sysroot.rust_std.to_list()]),
        rustc = sysroot.rustc,
        rustc_lib = sysroot.rustc_lib,
        rustc_srcs = ctx.attr.rustc_srcs,
        rustfmt = sysroot.rustfmt,
        staticlib_ext = ctx.attr.staticlib_ext,
        stdlib_linkflags = stdlib_linkflags_cc_info,
        sysroot = sysroot_path,
        sysroot_short_path = sysroot_short_path,
        target_arch = ctx.attr.target_triple.split("-")[0],
        target_flag_value = ctx.file.target_json.path if ctx.file.target_json else ctx.attr.target_triple,
        target_json = ctx.file.target_json,
        target_triple = ctx.attr.target_triple,

        # Experimental and incompatible flags
        _rename_first_party_crates = rename_first_party_crates,
        _third_party_dir = third_party_dir,
        _pipelined_compilation = pipelined_compilation,
        _experimental_use_cc_common_link = experimental_use_cc_common_link,
    )
    return [
        toolchain,
        make_variable_info,
    ]

rust_toolchain = rule(
    implementation = _rust_toolchain_impl,
    fragments = ["cpp"],
    attrs = {
        "allocator_library": attr.label(
            doc = "Target that provides allocator functions when rust_library targets are embedded in a cc_binary.",
        ),
        "binary_ext": attr.string(
            doc = "The extension for binaries created from rustc.",
            mandatory = True,
        ),
        "cargo": attr.label(
            doc = "The location of the `cargo` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            cfg = "exec",
        ),
        "clippy_driver": attr.label(
            doc = "The location of the `clippy-driver` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            cfg = "exec",
        ),
        "debug_info": attr.string_dict(
            doc = "Rustc debug info levels per opt level",
            default = {
                "dbg": "2",
                "fastbuild": "0",
                "opt": "0",
            },
        ),
        "default_edition": attr.string(
            doc = (
                "The edition to use for rust_* rules that don't specify an edition. " +
                "If absent, every rule is required to specify its `edition` attribute."
            ),
        ),
        "dylib_ext": attr.string(
            doc = "The extension for dynamic libraries created from rustc.",
            mandatory = True,
        ),
        "env": attr.string_dict(
            doc = "Environment variables to set in actions.",
        ),
        "exec_triple": attr.string(
            doc = (
                "The platform triple for the toolchains execution environment. " +
                "For more details see: https://docs.bazel.build/versions/master/skylark/rules.html#configurations"
            ),
            mandatory = True,
        ),
        "experimental_use_cc_common_link": attr.label(
            default = Label("//rust/settings:experimental_use_cc_common_link"),
            doc = "Label to a boolean build setting that controls whether cc_common.link is used to link rust binaries.",
        ),
        "llvm_cov": attr.label(
            doc = "The location of the `llvm-cov` binary. Can be a direct source or a filegroup containing one item. If None, rust code is not instrumented for coverage.",
            allow_single_file = True,
            cfg = "exec",
        ),
        "llvm_profdata": attr.label(
            doc = "The location of the `llvm-profdata` binary. Can be a direct source or a filegroup containing one item. If `llvm_cov` is None, this can be None as well and rust code is not instrumented for coverage.",
            allow_single_file = True,
            cfg = "exec",
        ),
        "llvm_tools": attr.label(
            doc = "LLVM tools that are shipped with the Rust toolchain.",
            allow_files = True,
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
        "rust_doc": attr.label(
            doc = "The location of the `rustdoc` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            cfg = "exec",
            mandatory = True,
        ),
        "rust_lib": attr.label(
            doc = "**Deprecated**: Use `rust_std`",
        ),
        "rust_std": attr.label(
            doc = "The Rust standard library.",
        ),
        "rustc": attr.label(
            doc = "The location of the `rustc` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            cfg = "exec",
            mandatory = True,
        ),
        "rustc_lib": attr.label(
            doc = "The libraries used by rustc during compilation.",
            cfg = "exec",
        ),
        "rustc_srcs": attr.label(
            doc = "The source code of rustc.",
        ),
        "rustfmt": attr.label(
            doc = "The location of the `rustfmt` binary. Can be a direct source or a filegroup containing one item.",
            allow_single_file = True,
            cfg = "exec",
        ),
        "staticlib_ext": attr.string(
            doc = "The extension for static libraries created from rustc.",
            mandatory = True,
        ),
        "stdlib_linkflags": attr.string_list(
            doc = (
                "Additional linker flags to use when Rust standard library is linked by a C++ linker " +
                "(rustc will deal with these automatically). Subject to location expansion with respect " +
                "to the srcs of the `rust_std` attribute."
            ),
            mandatory = True,
        ),
        "target_json": attr.label(
            doc = ("Override the target_triple with a custom target specification. " +
                   "For more details see: https://doc.rust-lang.org/rustc/targets/custom.html"),
            allow_single_file = True,
        ),
        "target_triple": attr.string(
            doc = (
                "The platform triple for the toolchains target environment. " +
                "For more details see: https://docs.bazel.build/versions/master/skylark/rules.html#configurations"
            ),
        ),
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
        "_pipelined_compilation": attr.label(
            default = "@rules_rust//rust/settings:pipelined_compilation",
        ),
        "_rename_first_party_crates": attr.label(
            default = Label("//rust/settings:rename_first_party_crates"),
        ),
        "_third_party_dir": attr.label(
            default = Label("//rust/settings:third_party_dir"),
        ),
    },
    toolchains = [
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    incompatible_use_toolchain_transition = True,
    doc = """Declares a Rust toolchain for use.

This is for declaring a custom toolchain, eg. for configuring a particular version of rust or supporting a new platform.

Example:

Suppose the core rust team has ported the compiler to a new target CPU, called `cpuX`. This \
support can be used in Bazel by defining a new toolchain definition and declaration:

```python
load('@rules_rust//rust:toolchain.bzl', 'rust_toolchain')

rust_toolchain(
    name = "rust_cpuX_impl",
    rustc = "@rust_cpuX//:rustc",
    rustc_lib = "@rust_cpuX//:rustc_lib",
    rust_std = "@rust_cpuX//:rust_std",
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

See @rules_rust//rust:repositories.bzl for examples of defining the @rust_cpuX repository \
with the actual binaries and libraries.
""",
)

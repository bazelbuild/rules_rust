"""Helpers for laying out Rust tools in a generated sysroot.

A sysroot is the directory tree a Rust distribution installs into: `bin/` for
the tools, `lib/` for the compiler's own shared libraries and
`lib/rustlib/<triple>/{lib,bin}` for each target's standard library and
self-contained tools. rustup toolchains, the `rust-installer` tarballs and
rustc's own build all use this layout, and rustc finds most of what it needs
by walking it from one of two roots. The references below point at the
rust-lang/rust `1.99.1` tag, with the function name given alongside so it can
be found again once the lines have moved.

rustc derives the following from its own location:

* `librustc_driver` is found by the dynamic loader through the rpath that
  bootstrap writes into every distributed binary, `$ORIGIN/../lib`
  (`@loader_path/../lib` on macOS). `configure_linker` has the long story on
  why `-C rpath` is not used for this:
  https://github.com/rust-lang/rust/blob/1.99.1/src/bootstrap/src/core/builder/cargo.rs#L292-L346
  On Windows there is no rpath and `rustc_driver.dll` is installed beside the
  executables in `bin/`, see `rustc_libdir`:
  https://github.com/rust-lang/rust/blob/1.99.1/src/bootstrap/src/core/builder/mod.rs#L1330-L1335
  The loader expands `$ORIGIN` from the executable's real path (glibc reads
  `/proc/self/exe`, dyld the path it opened), so a symlink to a binary only
  loads libraries beside the binary itself, never beside the symlink. The
  generated trees below are symlinks wherever Bazel keeps them as such, so
  every binary they point at must have the libraries beside its real file.
  `rust_toolchain_tools_repository` sees to that for the repositories it
  lays out: a repository holding Clippy without the compiler links the
  compiler's `lib/` beside it.
  Either way `bin/<tool>` needs the compiler libraries at a fixed relative
  path.

* The default sysroot comes from `default_sysroot`:
  https://github.com/rust-lang/rust/blob/1.99.1/compiler/rustc_session/src/filesearch.rs#L277-L346
  It tries `argv[0]` first: when that is a symlink and `../../lib/rustlib`
  exists beside it, that directory is the sysroot (rust-lang/rust#79253).
  Otherwise it canonicalizes the path `librustc_driver` was loaded from
  (`current_dll_path`,
  https://github.com/rust-lang/rust/blob/1.99.1/compiler/rustc_session/src/filesearch.rs#L265-L275)
  and strips `lib/` or `lib/rustlib/<host>/lib/` from it. `rustc --print
  sysroot` shows the result
  (https://doc.rust-lang.org/rustc/command-line-arguments.html#option-print).

* `--sysroot` does not replace that default, it adds a second root. `Sysroot`
  keeps both and `all_paths()` yields the explicit one first, then the
  default:
  https://github.com/rust-lang/rust/blob/1.99.1/compiler/rustc_session/src/config.rs#L1383-L1402
  (https://doc.rust-lang.org/rustc/command-line-arguments.html#option-sysroot).

Under those roots rustc looks for:

* The standard library and every other target library in
  `<root>/lib/rustlib/<triple>/lib`, see `make_target_lib_path`:
  https://github.com/rust-lang/rust/blob/1.99.1/compiler/rustc_session/src/filesearch.rs#L136-L139
  The same directory's `self-contained/` holds the CRT objects and libraries
  used by `-C link-self-contained`, see `get_object_file_path`:
  https://github.com/rust-lang/rust/blob/1.99.1/compiler/rustc_codegen_ssa/src/back/link.rs#L2067-L2080

* Codegen backends in `<root>/lib/rustlib/<host>/codegen-backends`, tried for
  each root in turn by `get_codegen_sysroot`:
  https://github.com/rust-lang/rust/blob/1.99.1/compiler/rustc_interface/src/util.rs#L506-L545

* Self-contained linkers and LLVM tools in `<root>/lib/rustlib/<host>/bin`,
  see `make_target_bin_path`:
  https://github.com/rust-lang/rust/blob/1.99.1/compiler/rustc_session/src/filesearch.rs#L141-L147
  This is where `rust-lld`, the `gcc-ld/` wrappers and `rust-objcopy` live.
  `get_tools_search_paths` lists that directory for every root (note the
  host triple, not the target's):
  https://github.com/rust-lang/rust/blob/1.99.1/compiler/rustc_session/src/session.rs#L671-L686
  and `link.rs` passes each one's `gcc-ld` to `cc` with `-B` when the
  self-contained linker is in use:
  https://github.com/rust-lang/rust/blob/1.99.1/compiler/rustc_codegen_ssa/src/back/link.rs#L4109-L4127
  (https://doc.rust-lang.org/rustc/codegen-options/index.html#link-self-contained).

* The compiler rustdoc runs doctests with. `rustc_path` joins
  `RUSTC_INSTALL_BINDIR` (`bin`, baked in by bootstrap) onto
  `sysroot.default` only:
  https://github.com/rust-lang/rust/blob/1.99.1/compiler/rustc_interface/src/util.rs#L492-L504
  and rustdoc unwraps the result with `.expect("found rustc")` unless
  `--test-builder` was passed:
  https://github.com/rust-lang/rust/blob/1.99.1/src/librustdoc/doctest.rs#L656-L659
  The explicit `--sysroot` is never consulted here, so `rustdoc` needs
  `rustc` in its own `bin/`.

For more background see the rustc dev guide
(https://rustc-dev-guide.rust-lang.org/building/bootstrapping/what-bootstrapping-does.html#what-is-a-sysroot),
rustup's notes on toolchains
(https://rust-lang.github.io/rustup/concepts/toolchains.html) and the
installer that produces the tarballs
(https://github.com/rust-lang/rust-installer).

The trees built here are made of `ctx.actions.symlink(target_file = ...)`
outputs (https://bazel.build/rules/lib/builtins/actions#symlink). Locally
those are ordinary symlinks. `bin/rustc` is one, so the generated tree is the
default sysroot as soon as it holds `lib/rustlib`, and when it does not,
`current_dll_path` resolves into the downloaded distribution and that becomes
the default root instead. Either way an incomplete tree works locally, by
accident. Remote executors receive these artifacts as regular files at the
symlink's path with no trace of where they came from (unlike
`declare_symlink` outputs, which Bazel transfers verbatim:
https://bazel.build/rules/lib/builtins/actions#declare_symlink), so there the
generated tree is the only layout that exists and it has to be complete.
`//test/unit/companion_toolchains` checks exactly that: it copies a generated
sysroot with every symlink dereferenced and runs the tools from the copy,
including for a sysroot built from a hand-crafted distribution of relative
symlinks under a nested package root.

`rust_toolchain` has generated its sysroot this way since #1119, passed it
as `--sysroot` since #2223 and done so by default since #2277. Companion
toolchains derive theirs from it with `derive_sysroot`.
"""

load("//rust/private:common.bzl", "rust_common")

def companion_rust_toolchain_attrs(tool):
    """The attributes tying a companion toolchain to a `rust_toolchain`.

    Args:
        tool (str): The tool the companion provides, for the documentation.

    Returns:
        dict[str, attr]: `rust_toolchain`, `version`, `iso_date` and `channel`.
    """
    return {
        "channel": attr.string(
            doc = "The Rust release channel `{}` comes from (`stable`, `nightly`, or `beta`), as in `rust_toolchain.channel`.".format(tool),
            default = "",
        ),
        "iso_date": attr.string(
            doc = "The ISO date of the nightly or beta release `{}` comes from, as in `rust_toolchain.iso_date`. Empty for stable releases.".format(tool),
            default = "",
        ),
        "rust_toolchain": attr.label(
            doc = (
                "The `rust_toolchain` whose sysroot this toolchain derives its own from, normally the one " +
                "declared beside it over the same release. Exclusive with `version`, `iso_date` and `channel`: " +
                "when unset the `rust_toolchain` resolved for `@rules_rust//rust:toolchain_type` is used " +
                "instead and `version` is required, so that the resolved toolchain can be checked to come " +
                "from the same release."
            ),
            providers = [platform_common.ToolchainInfo],
        ),
        "version": attr.string(
            doc = (
                "The version of the Rust release `{tool}` comes from (e.g. `1.94.1`), as in " +
                "`rust_toolchain.version`. Required when `rust_toolchain` is unset, and not allowed with it. " +
                "The resolved `rust_toolchain` must agree on `version`, `iso_date` and `channel` wherever " +
                "both state them."
            ).format(tool = tool),
            default = "",
        ),
    }

def companion_rust_toolchain(ctx, tool):
    """The `rust_toolchain` a companion toolchain derives its sysroot from.

    It is the one named by `rust_toolchain`, else the one resolved for
    `@rules_rust//rust:toolchain_type`, which `version` is required for and
    must agree with `version`, `iso_date` and `channel` wherever both state
    them: `tool` would otherwise load the libraries of a `rustc` it was not
    built with. The two ways exclude each other, so the toolchain has one
    source of truth for its release, and advertises that `rust_toolchain`'s
    `version`, `iso_date` and `channel` in either case.

    Args:
        ctx (ctx): The rule context of a companion toolchain rule, with the
            attributes of `companion_rust_toolchain_attrs` and
            `@rules_rust//rust:toolchain_type` among its optional toolchains.
        tool (str): The tool the companion provides, for diagnostics.

    Returns:
        ToolchainInfo: The `rust_toolchain`.
    """
    release_fields = ("version", "iso_date", "channel")
    if ctx.attr.rust_toolchain:
        stated = [field for field in release_fields if getattr(ctx.attr, field)]
        if stated:
            fail((
                "{}: `rust_toolchain` and {} are exclusive. A `{}_toolchain` which names its " +
                "`rust_toolchain` takes its release from it; state `version`, `iso_date` and `channel` " +
                "only for one which leaves `rust_toolchain` unset."
            ).format(ctx.label, ", ".join(["`{}`".format(field) for field in stated]), tool))
        return ctx.attr.rust_toolchain[platform_common.ToolchainInfo]

    if not ctx.attr.version:
        fail((
            "{}: a `{}_toolchain` must name the `rust_toolchain` it accompanies through `rust_toolchain`, " +
            "or state its release through `version` (and `channel` and `iso_date` where they apply) so " +
            "that the `rust_toolchain` resolved for `@rules_rust//rust:toolchain_type` can be checked " +
            "against it."
        ).format(ctx.label, tool))
    rust_toolchain = ctx.toolchains[rust_common.toolchain_type]
    if not rust_toolchain:
        fail("{}: no `rust_toolchain` is registered for the current platform".format(ctx.label))
    for field in release_fields:
        stated = getattr(ctx.attr, field)
        actual = getattr(rust_toolchain, field, "")
        if stated and actual and stated != actual:
            fail((
                "{}: this `{tool}_toolchain` ({field} {stated}) and the `rust_toolchain` it derives its " +
                "sysroot from ({field} {actual}) come from different Rust releases. `{tool}` loads the " +
                "libraries of the `rustc` it was released with; pair it with a `rust_toolchain` of that release."
            ).format(ctx.label, tool = tool, field = field, stated = stated, actual = actual))
    return rust_toolchain

def distribution_relative_path(file, target):
    """The path of a distribution file relative to the distribution's root.

    The root is the package of the target that lists the file. The generated
    repositories and most hand-written toolchains declare their `filegroup`s
    at the distribution root, and a distribution kept in a sub-directory
    declares them in a `BUILD` file there. A file outside that package keeps
    its path relative to the package it is declared in, and a file from the
    main repository with neither falls back to its workspace-relative path.
    Source and generated files are treated alike since the path is taken from
    `short_path` rather than the output-root-prefixed `path`.

    Args:
        file (File): A file of the distribution.
        target (Target): The target which lists `file`.

    Returns:
        str: The path to recreate the file at inside a generated sysroot.
    """
    path = file.short_path
    if path.startswith("../"):
        # `../<repository>/<path within the repository>`
        path = path.split("/", 2)[-1]

    for package in (target.label.package, file.owner.package if file.owner else ""):
        if package and path.startswith(package + "/"):
            return path[len(package) + 1:]
    return path

def symlink_sysroot_tree(*, ctx, name, target, target_files = None, declared = None):
    """Generate a set of symlinks to files from another target.

    Each file is recreated at its `distribution_relative_path`, so the tree
    keeps the `bin/`, `lib/` and `lib/rustlib/<triple>` structure of the
    distribution whatever repository or package the files came from.

    Components of a distribution overlap. `rustc_lib` and `rust_std` both list
    `lib/rustlib/<triple>/lib/libstd-*.so`, for instance. When two components
    name the same `File` Bazel merges the identical symlink actions. When a
    hand-crafted toolchain reaches the same path through different files the
    first component to claim the path keeps it, which is what `declared`
    tracks.

    Args:
        ctx (ctx): The toolchain's context object.
        name (str): The name of the sysroot directory (typically `ctx.label.name`).
        target (Target): A target owning files to symlink.
        target_files (depset): An optional depset to use in place of `target.files`.
        declared (dict): Relative paths already placed in the tree, updated in place.
            Pass the same dict to every call for one sysroot.

    Returns:
        depset[File]: A depset of the generated symlink files.
    """
    tree_files = []
    if target_files == None:
        target_files = target.files
    if declared == None:
        declared = {}
    for file in target_files.to_list():
        file_path = distribution_relative_path(file, target)
        if file_path in declared:
            continue
        declared[file_path] = file
        symlink = ctx.actions.declare_file("{}/{}".format(name, file_path))

        ctx.actions.symlink(
            output = symlink,
            target_file = file,
        )

        tree_files.append(symlink)

    return depset(tree_files)

def symlink_sysroot_bin(*, ctx, name, directory, target):
    """Create an executable symlink to a target file.

    Args:
        ctx (ctx): The rule's context object.
        name (str): A common name for the output directory.
        directory (str): The directory under `name` to put the file in.
        target (File): A File object to symlink to.

    Returns:
        File: A newly generated symlink file.
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

def derive_sysroot(*, ctx, name, base_path, base_files, bins):
    """Lay out a sysroot under `name` that mirrors another one and adds tools to its `bin/`.

    Companion toolchains such as `rustdoc_toolchain` derive their sysroot from
    the one the resolved `rust_toolchain` generated. Every file of the base
    sysroot is symlinked at the same relative path, so `rustc`, its libraries
    and the standard library are all there, and the companion's own binaries
    join `bin/`. A tool run from the derived tree finds `librustc_driver` in
    `../lib` and `rustc` beside itself, and the tree can be passed as
    `--sysroot`. Where symlinks stay symlinks, a tool loads its libraries from
    its real location rather than from the tree (see the module docs), so a
    binary must come from a repository laid out like a distribution.

    Args:
        ctx (ctx): The toolchain's context object.
        name (str): The name of the sysroot directory (typically `ctx.label.name`).
        base_path (str): The path of the base sysroot (`rust_toolchain`'s `sysroot`).
        base_files (depset[File]): The files of the base sysroot, all under `base_path`.
        bins (list[File]): Binaries to place in `bin/`, replacing base entries of the same name.

    Returns:
        struct: `anchor`, a `File` at the root of the tree; `path` and
            `short_path` of the tree; `files`, a `depset` of everything in
            it; `bins`, a dict of the added binaries by basename; and
            `mirrored`, a dict of the entries taken over from the base
            sysroot by their path relative to the tree, such as `bin/rustc`.
    """
    prefix = base_path + "/"
    added = {}
    for binary in bins:
        added[binary.basename] = symlink_sysroot_bin(ctx = ctx, name = name, directory = "bin", target = binary)
    replaced = {"bin/" + basename: True for basename in added}

    files = list(added.values())
    mirrored = {}
    for file in base_files.to_list():
        if not file.path.startswith(prefix):
            fail("{} is not inside the sysroot {}".format(file.path, base_path))
        relative = file.path[len(prefix):]
        if relative in replaced or relative == "rust.sysroot":
            continue
        symlink = ctx.actions.declare_file("{}/{}".format(name, relative))
        ctx.actions.symlink(
            output = symlink,
            target_file = file,
            is_executable = relative.startswith("bin/") or "/bin/" in relative,
        )
        files.append(symlink)
        mirrored[relative] = symlink

    anchor = ctx.actions.declare_file("{}/rust.sysroot".format(name))
    ctx.actions.write(
        output = anchor,
        content = "\n".join(["derived from: {}".format(base_path)] + [
            "{}: {}".format(basename, binary.path)
            for basename, binary in added.items()
        ]),
    )
    files.append(anchor)

    short_path, _, _ = anchor.short_path.rpartition("/")
    return struct(
        anchor = anchor,
        path = anchor.dirname,
        short_path = short_path,
        files = depset(files),
        bins = added,
        mirrored = mirrored,
    )

def expand_toolchain_flags(*, ctx, attr_name, rust_toolchain, make_variables):
    """Expand Make variables in a companion toolchain's flag attribute.

    Both the `rust_toolchain`'s variables (`RUST_SYSROOT`, `RUSTC`, ...) and
    the companion's own are available.

    Args:
        ctx (ctx): The companion toolchain's context.
        attr_name (str): The name of the string list attribute to expand.
        rust_toolchain (ToolchainInfo): The resolved `rust_toolchain`.
        make_variables (dict): The companion's own Make variables.

    Returns:
        list[str]: The expanded flags.
    """
    variables = dict(rust_toolchain.make_variables.variables)
    variables.update(make_variables)
    return [
        ctx.expand_make_variables(attr_name, flag, variables) if "$" in flag else flag
        for flag in getattr(ctx.attr, attr_name)
    ]

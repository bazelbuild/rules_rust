"""Helpers for laying out Rust tools in a generated sysroot.

A sysroot is the directory tree a Rust distribution installs into: `bin/` for
the tools, `lib/` for the compiler's own shared libraries, and
`lib/rustlib/<triple>/{lib,bin}` for each target's standard library and
self-contained tools. rustup toolchains, the `rust-installer` tarballs and
rustc's own build all use it, and rustc finds most of what it needs by
walking it relative to one of two roots. References below point at
rust-lang/rust `master`; the functions named are stable landmarks.

What rustc derives from its own location
----------------------------------------

* `librustc_driver` is found by the dynamic loader through the rpath that
  bootstrap writes into every distributed binary, `$ORIGIN/../lib`
  (`@loader_path/../lib` on macOS; on Windows the DLLs sit in `bin/` and are
  found through the executable's own directory). See the long comment on
  rpath in `src/bootstrap/src/core/builder/cargo.rs`:
  https://github.com/rust-lang/rust/blob/master/src/bootstrap/src/core/builder/cargo.rs
  So `bin/<tool>` needs `lib/librustc_driver-*.so` as its sibling directory.

* The *default* sysroot is computed from where `librustc_driver` was loaded
  from, not from `argv[0]`: `default_sysroot()` in
  `compiler/rustc_session/src/filesearch.rs` takes `current_dll_path()` and
  strips `lib/` (or `lib/rustlib/<triple>/lib/`) from it.
  https://github.com/rust-lang/rust/blob/master/compiler/rustc_session/src/filesearch.rs
  `rustc --print sysroot` shows the result
  (https://doc.rust-lang.org/rustc/command-line-arguments.html#--print-print-compiler-information).

* `--sysroot` does not replace that default; it adds a second root. The
  `Sysroot { explicit, default }` type in `compiler/rustc_session/src/config.rs`
  searches `all_paths()`, the explicit one first and then the default:
  https://github.com/rust-lang/rust/blob/master/compiler/rustc_session/src/config.rs
  (https://doc.rust-lang.org/rustc/command-line-arguments.html#option-sysroot).
  This is why a generated tree that only held a tool binary still works
  locally: the symlink resolves into the downloaded distribution, whose
  `lib/` and `lib/rustlib` are then found as the default root.

What is looked up under those roots
-----------------------------------

* The standard library and every target library:
  `make_target_lib_path(sysroot, triple)` = `<root>/lib/rustlib/<triple>/lib`
  (`filesearch.rs`), searched for `--extern`-less crates such as `std` and
  for the `self-contained/` objects (`compiler/rustc_codegen_ssa/src/back/link.rs`,
  `target_tlib_path.dir.join("self-contained")`):
  https://github.com/rust-lang/rust/blob/master/compiler/rustc_codegen_ssa/src/back/link.rs

* Codegen backends: `get_codegen_sysroot()` in
  `compiler/rustc_interface/src/util.rs` looks for
  `<root>/lib/rustlib/<host>/codegen-backends` across `all_paths()`:
  https://github.com/rust-lang/rust/blob/master/compiler/rustc_interface/src/util.rs

* Self-contained linkers and LLVM tools: `make_target_bin_path(sysroot, triple)`
  = `<root>/lib/rustlib/<triple>/bin` (`filesearch.rs`), where `rust-lld`,
  the `gcc-ld/` wrappers and `rust-objcopy` live; `link.rs` adds `gcc-ld`
  from there with `-B` when the self-contained linker is in use
  (https://doc.rust-lang.org/rustc/codegen-options/index.html#link-self-contained).

* rustdoc's doctest compiler: `rustc_path()` in `rustc_interface/src/util.rs`
  joins `RUSTC_INSTALL_BINDIR` (`bin`, set by bootstrap) onto
  `sysroot.default` only, and `src/librustdoc/doctest.rs` unwraps it with
  `.expect("found rustc")`:
  https://github.com/rust-lang/rust/blob/master/src/librustdoc/doctest.rs
  The explicit `--sysroot` is not consulted, so `rustdoc` needs `rustc` in
  its own `bin/`.

Further reading: the rustc dev guide on what a sysroot is
(https://rustc-dev-guide.rust-lang.org/building/bootstrapping/what-bootstrapping-does.html#what-is-a-sysroot),
rustup's description of toolchains
(https://rust-lang.github.io/rustup/concepts/toolchains.html) and the
installer that produces the tarballs
(https://github.com/rust-lang/rust-installer).

Why Bazel needs the layout reproduced
-------------------------------------

The trees built here consist of `ctx.actions.symlink(target_file = ...)`
outputs (https://bazel.build/rules/lib/builtins/actions#symlink). Locally the
loader and `current_dll_path()` follow such a symlink into the downloaded
distribution, so an incomplete tree works by accident, as described above.
Remote executors receive these artifacts as regular files at the symlink's
path with no trace of the original location (unlike `declare_symlink`
outputs, which Bazel transfers verbatim:
https://bazel.build/rules/lib/builtins/actions#declare_symlink), so the
generated tree is the only layout that exists there and must be complete on
its own. `//test/unit/companion_toolchains` checks that by copying generated
sysroots with every symlink dereferenced and running the tools from the copy,
including sysroots built from a hand-crafted distribution of relative
symlinks and nested package roots.

`rust_toolchain` has generated its sysroot this way since rules_rust #1119,
passed it as `--sysroot` since #2223 and by default since #2277. Companion
toolchains derive theirs from it with `derive_sysroot`.
"""

def distribution_relative_path(file, target):
    """The path of a distribution file relative to the distribution's root.

    The root is the package of the target that lists the file: the generated
    repositories and most hand-written toolchains declare their `filegroup`s
    at the distribution root, and a distribution kept in a sub-directory
    declares them in a `BUILD` file there. Files outside that package keep
    their path relative to the package they are declared in, and files from
    the main repository with neither fall back to their workspace-relative
    path. Source and generated files are treated alike, since the path is
    taken from `short_path` rather than the output-root-prefixed `path`.

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

def symlink_sysroot_tree(ctx, name, target, target_files = None, declared = None):
    """Generate a set of symlinks to files from another target

    Each file is recreated at its `distribution_relative_path`, so that the
    tree keeps the `bin/`, `lib/` and `lib/rustlib/<triple>` structure of the
    distribution the files came from whatever repository or package holds it.

    Components of a distribution overlap: `rustc_lib` and `rust_std` both
    list `lib/rustlib/<triple>/lib/libstd-*.so`, for instance. When they name
    the same `File`, Bazel merges the identical symlink actions; when a
    hand-crafted toolchain reaches the same path through different files,
    the first component to claim a path keeps it, tracked in `declared`.

    Args:
        ctx (ctx): The toolchain's context object
        name (str): The name of the sysroot directory (typically `ctx.label.name`)
        target (Target): A target owning files to symlink
        target_files (depset): An optional depset to use in place of `target.files`.
        declared (dict): Relative paths already placed in the tree, updated in place.
            Pass the same dict to every call for one sysroot.

    Returns:
        depset[File]: A depset of the generated symlink files
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

def symlink_sysroot_bin(ctx, name, directory, target):
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

def derive_sysroot(ctx, name, base_path, base_files, bins):
    """Lay out a sysroot under `name` that mirrors another one and adds tools to its `bin/`.

    Companion toolchains such as `rustdoc_toolchain` derive their sysroot from
    the one the resolved `rust_toolchain` generated: every file of the base
    sysroot is symlinked at the same relative path, so `rustc`, its libraries
    and the standard library are all there, and the companion's own binaries
    join `bin/`. A tool run from the derived tree finds `librustc_driver` in
    `../lib` and `rustc` beside itself, and the tree serves as `--sysroot`.

    Args:
        ctx (ctx): The toolchain's context object.
        name (str): The name of the sysroot directory (typically `ctx.label.name`).
        base_path (str): The path of the base sysroot (`rust_toolchain`'s `sysroot`).
        base_files (depset[File]): The files of the base sysroot, all under `base_path`.
        bins (list[File]): Binaries to place in `bin/`, replacing base entries of the same name.

    Returns:
        struct: `anchor`, a `File` at the root of the tree; `path` and
            `short_path` of the tree; `files`, a `depset` of everything in
            it; and `bins`, a dict of the added binaries by basename.
    """
    prefix = base_path + "/"
    added = {}
    for binary in bins:
        added[binary.basename] = symlink_sysroot_bin(ctx, name, "bin", binary)
    replaced = {"bin/" + basename: True for basename in added}

    files = list(added.values())
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
    )

def expand_toolchain_flags(ctx, attr_name, rust_toolchain, make_variables):
    """Expand Make variables in a companion toolchain's flag attribute.

    Both the `rust_toolchain`'s variables (`RUST_SYSROOT`, `RUSTC`, ...) and the
    companion's own are available.

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

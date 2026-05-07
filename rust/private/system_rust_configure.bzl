"""Repository rule for configuring a system-installed Rust toolchain.

Follows the `cc_configure` pattern from rules_cc: probes the system at fetch
time and generates a BUILD file with `rust_toolchain()` targets that reference
the host-installed compiler and standard library without including sysroot files
as action inputs.

This is useful for remote-execution setups where every worker already has an
identical Rust toolchain installed (e.g. via a container image or system
package). By pointing at the system toolchain, ~670 MB of sysroot files are
excluded from action input sets, eliminating upload/transfer overhead.
"""

load("//rust/platform:triple_mappings.bzl", "triple_to_constraint_set")

def _fail_if_not_found(repository_ctx, result, tool):
    """Fail with a helpful message when a required tool is missing."""
    if result.return_code != 0:
        fail(
            "Failed to run '{}': exit code {}\nstdout: {}\nstderr: {}".format(
                tool,
                result.return_code,
                result.stdout,
                result.stderr,
            ),
        )

def _rust_system_toolchain_repository_impl(repository_ctx):
    """Probes the system Rust toolchain and generates BUILD targets.

    The generated BUILD file contains:
      - A `rust_stdlib_filegroup` with an empty srcs (sysroot files are not
        tracked as action inputs).
      - A `rust_toolchain` target with `sysroot_path` set, which causes
        rules_rust to pass `--sysroot=<path>` to rustc and skip packaging
        sysroot files into action inputs.
      - A `toolchain()` registration target for each requested target triple.
    """
    tool_path = repository_ctx.attr.tool_path

    # Locate rustc
    if tool_path:
        rustc = repository_ctx.path(tool_path + "/bin/rustc")
        cargo = repository_ctx.path(tool_path + "/bin/cargo")
        rustdoc = repository_ctx.path(tool_path + "/bin/rustdoc")
        clippy_driver = repository_ctx.path(tool_path + "/bin/clippy-driver")
        cargo_clippy = repository_ctx.path(tool_path + "/bin/cargo-clippy")
    else:
        rustc = repository_ctx.which("rustc")
        if not rustc:
            fail("Could not find `rustc` on PATH and no `tool_path` was provided.")
        cargo = repository_ctx.which("cargo")
        rustdoc = repository_ctx.which("rustdoc")
        clippy_driver = repository_ctx.which("clippy-driver")
        cargo_clippy = repository_ctx.which("cargo-clippy")

    # Probe the sysroot
    result = repository_ctx.execute([str(rustc), "--print", "sysroot"])
    _fail_if_not_found(repository_ctx, result, "rustc --print sysroot")
    sysroot = result.stdout.strip()

    # Probe the version
    result = repository_ctx.execute([str(rustc), "--version", "--verbose"])
    _fail_if_not_found(repository_ctx, result, "rustc --version --verbose")
    version_output = result.stdout.strip()

    # Parse version (first line is like "rustc 1.86.0-nightly (abc123 2026-01-29)")
    version_line = version_output.split("\n")[0]
    rustc_version = version_line.split(" ")[1].split("-")[0] if " " in version_line else ""

    # Parse host triple from verbose output
    host_triple = ""
    for line in version_output.split("\n"):
        if line.startswith("host:"):
            host_triple = line.split(":", 1)[1].strip()
            break

    # Validate version if user specified one
    if repository_ctx.attr.version:
        if not version_line.split(" ")[1].startswith(repository_ctx.attr.version) if " " in version_line else True:
            # buildifier: disable=print
            print("WARNING: Expected Rust version '{}' but found '{}'".format(
                repository_ctx.attr.version,
                version_line,
            ))

    # Determine exec_triple
    exec_triple = repository_ctx.attr.exec_triple if repository_ctx.attr.exec_triple else host_triple
    if not exec_triple:
        fail("Could not determine exec_triple. Set it explicitly or ensure `rustc --version --verbose` reports a host triple.")

    # Determine target triples
    target_triples = repository_ctx.attr.target_triples if repository_ctx.attr.target_triples else [exec_triple]

    # For each target triple, probe the target libdir to confirm it exists
    for target in target_triples:
        result = repository_ctx.execute([str(rustc), "--print", "target-libdir", "--target", target])
        if result.return_code != 0:
            # buildifier: disable=print
            print("WARNING: rustc cannot find target-libdir for '{}': {}".format(target, result.stderr.strip()))

    # Determine system extension values based on exec triple
    binary_ext, staticlib_ext, dylib_ext = _extensions_for_triple(exec_triple)

    # Create symlinks to system binaries so that Bazel can track them as labels.
    # Using symlinks avoids copying the binaries and keeps them in-tree for the
    # rule to reference.
    repository_ctx.symlink(rustc, "bin/rustc")
    if cargo:
        repository_ctx.symlink(cargo, "bin/cargo")
    if rustdoc:
        repository_ctx.symlink(rustdoc, "bin/rustdoc")
    if clippy_driver:
        repository_ctx.symlink(clippy_driver, "bin/clippy-driver")
    if cargo_clippy:
        repository_ctx.symlink(cargo_clippy, "bin/cargo-clippy")

    # Determine stdlib linkflags per target triple
    # For now we use a simplified approach -- the full mapping is in
    # triple_mappings.bzl but we don't have access to the `triple()` struct
    # at repository-rule time. We infer from the triple string.
    stdlib_linkflags_map = {}
    for target in target_triples:
        stdlib_linkflags_map[target] = _stdlib_linkflags_for_triple(target)

    # Build the BUILD.bazel content
    build_content = _generate_build_file(
        exec_triple = exec_triple,
        target_triples = target_triples,
        sysroot = sysroot,
        has_cargo = cargo != None,
        has_clippy = clippy_driver != None,
        has_cargo_clippy = cargo_clippy != None,
        binary_ext = binary_ext,
        staticlib_ext = staticlib_ext,
        dylib_ext = dylib_ext,
        default_edition = repository_ctx.attr.default_edition,
        stdlib_linkflags_map = stdlib_linkflags_map,
        extra_rustc_flags = repository_ctx.attr.extra_rustc_flags,
        extra_exec_rustc_flags = repository_ctx.attr.extra_exec_rustc_flags,
    )

    repository_ctx.file("WORKSPACE.bazel", 'workspace(name = "{}")\n'.format(repository_ctx.name))
    repository_ctx.file("BUILD.bazel", build_content)

    # Generate bin/BUILD.bazel that exports the tool symlinks as labels.
    bin_exports = ["rustc", "rustdoc"]
    if cargo:
        bin_exports.append("cargo")
    if clippy_driver:
        bin_exports.append("clippy-driver")
    if cargo_clippy:
        bin_exports.append("cargo-clippy")
    bin_build = 'exports_files([{}])\n'.format(
        ", ".join(['"{}"'.format(f) for f in bin_exports]),
    )
    repository_ctx.file("bin/BUILD.bazel", bin_build)

def _extensions_for_triple(triple_str):
    """Returns (binary_ext, staticlib_ext, dylib_ext) for a platform triple."""
    if "windows" in triple_str:
        return (".exe", ".lib", ".dll")
    elif "darwin" in triple_str or "apple" in triple_str:
        return ("", ".a", ".dylib")
    else:
        return ("", ".a", ".so")

def _stdlib_linkflags_for_triple(triple_str):
    """Returns stdlib linkflags as a list of strings for a given triple."""
    if "windows" in triple_str and "msvc" in triple_str:
        return ["-ladvapi32", "-lws2_32", "-luserenv", "-lbcrypt", "-lntdll", "-lsynchronization"]
    elif "windows" in triple_str and "gnu" in triple_str:
        return ["-ladvapi32", "-lws2_32", "-luserenv", "-lbcrypt", "-lntdll", "-lsynchronization"]
    elif "darwin" in triple_str or "apple" in triple_str:
        return ["-lc", "-lm", "-ldl", "-framework", "Security", "-framework", "CoreFoundation"]
    elif "freebsd" in triple_str:
        return ["-lc", "-lm", "-lpthread", "-lexecinfo"]
    elif "fuchsia" in triple_str:
        return ["-lc", "-lm", "-lzircon", "-lfdio"]
    elif "wasm" in triple_str:
        return []
    else:
        # Linux and similar
        return ["-lc", "-lm", "-ldl", "-lpthread"]

def _generate_build_file(
        exec_triple,
        target_triples,
        sysroot,
        has_cargo,
        has_clippy,
        has_cargo_clippy,
        binary_ext,
        staticlib_ext,
        dylib_ext,
        default_edition,
        stdlib_linkflags_map,
        extra_rustc_flags,
        extra_exec_rustc_flags):
    """Generates the BUILD.bazel content for the system toolchain repository."""
    lines = []
    lines.append('load("@rules_rust//rust:toolchain.bzl", "rust_toolchain", "rust_stdlib_filegroup")')
    lines.append("")

    # For each target triple, generate a rust_stdlib_filegroup + rust_toolchain
    for target in target_triples:
        stdlib_name = "rust_std-{}".format(target)
        toolchain_name = "rust_toolchain-{}".format(target)
        proxy_name = "toolchain-{}".format(target)

        stdlib_linkflags = stdlib_linkflags_map.get(target, [])
        linkflags_str = ", ".join(['"{}"'.format(f) for f in stdlib_linkflags])

        # Empty stdlib filegroup -- the sysroot files live on the system and
        # are not tracked as Bazel action inputs.
        lines.append('rust_stdlib_filegroup(')
        lines.append('    name = "{}",'.format(stdlib_name))
        lines.append("    srcs = [],")
        lines.append('    visibility = ["//visibility:public"],')
        lines.append(")")
        lines.append("")

        lines.append("rust_toolchain(")
        lines.append('    name = "{}",'.format(toolchain_name))
        lines.append('    rustc = "//bin:rustc",')
        lines.append('    rust_doc = "//bin:rustdoc",')
        lines.append('    rust_std = ":{}",'.format(stdlib_name))
        if has_cargo:
            lines.append('    cargo = "//bin:cargo",')
        if has_clippy:
            lines.append('    clippy_driver = "//bin:clippy-driver",')
        if has_cargo_clippy:
            lines.append('    cargo_clippy = "//bin:cargo-clippy",')
        lines.append('    binary_ext = "{}",'.format(binary_ext))
        lines.append('    staticlib_ext = "{}",'.format(staticlib_ext))
        lines.append('    dylib_ext = "{}",'.format(dylib_ext))
        lines.append('    stdlib_linkflags = [{}],'.format(linkflags_str))
        lines.append('    exec_triple = "{}",'.format(exec_triple))
        lines.append('    target_triple = "{}",'.format(target))
        lines.append('    sysroot_path = "{}",'.format(sysroot))
        if default_edition:
            lines.append('    default_edition = "{}",'.format(default_edition))
        if extra_rustc_flags:
            lines.append("    extra_rustc_flags = {},".format(repr(extra_rustc_flags)))
        if extra_exec_rustc_flags:
            lines.append("    extra_exec_rustc_flags = {},".format(repr(extra_exec_rustc_flags)))
        lines.append('    visibility = ["//visibility:public"],')
        lines.append(")")
        lines.append("")

        # Toolchain registration target
        exec_constraints = triple_to_constraint_set(exec_triple)
        target_constraints = triple_to_constraint_set(target)
        lines.append("toolchain(")
        lines.append('    name = "{}",'.format(proxy_name))
        lines.append('    toolchain = ":{}",'.format(toolchain_name))
        lines.append('    toolchain_type = "@rules_rust//rust:toolchain",')
        lines.append("    exec_compatible_with = {},".format(repr(exec_constraints)))
        lines.append("    target_compatible_with = {},".format(repr(target_constraints)))
        lines.append('    visibility = ["//visibility:public"],')
        lines.append(")")
        lines.append("")

    return "\n".join(lines)

rust_system_toolchain_repository = repository_rule(
    doc = """\
Probes a system-installed Rust toolchain and generates `rust_toolchain()` targets.

This follows the `cc_configure` pattern from rules_cc: the repository rule runs
at fetch time, probes the local system for `rustc`, and generates a BUILD file
with toolchain targets that reference the system binaries via symlinks.

When these toolchains are used, the sysroot files (stdlib, rustc libs) are NOT
included as Bazel action inputs. Instead, `--sysroot=<path>` is passed to rustc
so it finds them at their system location. This is ideal for remote execution
environments where workers have a matching Rust toolchain pre-installed.

Example usage in WORKSPACE:
```starlark
load("@rules_rust//rust/private:system_rust_configure.bzl", "rust_system_toolchain_repository")

rust_system_toolchain_repository(
    name = "system_rust",
    default_edition = "2021",
)

register_toolchains("@system_rust//:toolchain-x86_64-unknown-linux-gnu")
```

Example usage in MODULE.bazel via the module extension:
```starlark
system_rust = use_extension("@rules_rust//rust/private:system_rust_configure.bzl", "system_rust_ext")
system_rust.toolchain(
    name = "system_rust",
    default_edition = "2021",
)
use_repo(system_rust, "system_rust")
register_toolchains("@system_rust//:toolchain-x86_64-unknown-linux-gnu")
```
""",
    implementation = _rust_system_toolchain_repository_impl,
    attrs = {
        "default_edition": attr.string(
            doc = "The default Rust edition (e.g. '2021', '2024'). If not set, each target must specify its edition.",
        ),
        "exec_triple": attr.string(
            doc = (
                "The Rust-style execution platform triple (e.g. 'x86_64-unknown-linux-gnu'). " +
                "If not set, auto-detected from `rustc --version --verbose`."
            ),
        ),
        "extra_exec_rustc_flags": attr.string_list(
            doc = "Extra flags to pass to rustc in exec configuration.",
        ),
        "extra_rustc_flags": attr.string_list(
            doc = "Extra flags to pass to rustc in non-exec configuration.",
        ),
        "target_triples": attr.string_list(
            doc = (
                "List of Rust-style target triples to generate toolchains for " +
                "(e.g. ['x86_64-unknown-linux-gnu', 'aarch64-unknown-linux-gnu']). " +
                "If not set, defaults to the exec_triple (native compilation only)."
            ),
        ),
        "tool_path": attr.string(
            doc = (
                "Absolute path to the Rust toolchain directory (e.g. a rustup toolchain " +
                "directory like '/home/user/.rustup/toolchains/nightly-2026-01-29-x86_64-unknown-linux-gnu'). " +
                "If not set, tools are located via PATH."
            ),
        ),
        "version": attr.string(
            doc = "Expected Rust version (e.g. '1.86.0'). If set, a warning is emitted when the system version does not match.",
        ),
    },
    environ = ["PATH", "RUSTUP_HOME", "RUSTUP_TOOLCHAIN", "CARGO_HOME"],
    local = True,
)

def _system_rust_ext_impl(module_ctx):
    """Module extension implementation for system Rust toolchains."""
    for mod in module_ctx.modules:
        for toolchain in mod.tags.toolchain:
            rust_system_toolchain_repository(
                name = toolchain.name,
                version = toolchain.version,
                exec_triple = toolchain.exec_triple,
                target_triples = toolchain.target_triples,
                tool_path = toolchain.tool_path,
                default_edition = toolchain.default_edition,
                extra_rustc_flags = toolchain.extra_rustc_flags,
                extra_exec_rustc_flags = toolchain.extra_exec_rustc_flags,
            )

_toolchain_tag = tag_class(
    doc = "Declares a system Rust toolchain to be probed and registered.",
    attrs = {
        "default_edition": attr.string(doc = "Default Rust edition."),
        "exec_triple": attr.string(doc = "Execution platform triple."),
        "extra_exec_rustc_flags": attr.string_list(doc = "Extra flags for rustc in exec configuration."),
        "extra_rustc_flags": attr.string_list(doc = "Extra flags for rustc in non-exec configuration."),
        "name": attr.string(doc = "Repository name.", mandatory = True),
        "target_triples": attr.string_list(doc = "Target triples to generate toolchains for."),
        "tool_path": attr.string(doc = "Absolute path to the Rust toolchain directory."),
        "version": attr.string(doc = "Expected Rust version for validation."),
    },
)

system_rust_ext = module_extension(
    doc = "Module extension for configuring system-installed Rust toolchains.",
    implementation = _system_rust_ext_impl,
    tag_classes = {
        "toolchain": _toolchain_tag,
    },
)

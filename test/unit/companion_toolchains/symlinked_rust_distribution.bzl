"""A hand-crafted Rust distribution with an awkward layout, for sysroot tests.

The repository is assembled out of the host's downloaded distribution
(`@rust_host_tools`) but arranged the way a user-provided toolchain might be:

* the distribution root is a nested package, `//nested/dist`, not the
  repository root;
* every file in it is a relative symlink (`bin/rustc -> ../../../real/bin/rustc`),
  and `lib/rustlib` is a relative symlink to a directory, so the compiler
  libraries are reached through a chain of symlinks; on Windows the directory
  is a junction and the files are symlinks or, without the privilege for
  them, hard links;
* the standard library lives under another package root entirely,
  `//stdlib/<triple>`, again through relative symlinks.

A `rust_toolchain` and its companions built from these targets must produce
sysroots that work exactly like a plain copy of the distribution.
"""

load("@rules_rust//rust/platform:triple.bzl", "get_host_triple")
load("@rules_rust//rust/platform:triple_mappings.bzl", "system_to_binary_ext", "system_to_dylib_ext", "system_to_staticlib_ext")

_HOST_BZL = """\
\"\"\"The host triple the symlinked distribution was assembled for.\"\"\"

HOST_TRIPLE = "{triple}"
"""

_DIST_BUILD = """\
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "rustc",
    srcs = ["bin/rustc{binary_ext}"],
)

filegroup(
    name = "rustdoc",
    srcs = ["bin/rustdoc{binary_ext}"],
)

filegroup(
    name = "clippy_driver",
    srcs = ["bin/clippy-driver{binary_ext}"],
)

filegroup(
    name = "cargo_clippy",
    srcs = ["bin/cargo-clippy{binary_ext}"],
)

# The same globs the generated repositories use, resolved through the
# relative symlinks of this layout.
filegroup(
    name = "rustc_lib",
    srcs = glob(
        [
            "bin/*{dylib_ext}",
            "lib/*{dylib_ext}*",
            "lib/rustlib/{triple}/codegen-backends/*{dylib_ext}",
            "lib/rustlib/{triple}/lib/*{dylib_ext}*",
            "lib/rustlib/{triple}/lib/*.rmeta",
        ],
        allow_empty = True,
    ),
)
"""

_STDLIB_BUILD = """\
load("@rules_rust//rust:toolchain.bzl", "rust_stdlib_filegroup")

package(default_visibility = ["//visibility:public"])

rust_stdlib_filegroup(
    name = "rust_std",
    srcs = glob(
        [
            "lib/rustlib/{triple}/lib/*.rlib",
            "lib/rustlib/{triple}/lib/*.rmeta",
            "lib/rustlib/{triple}/lib/*{dylib_ext}*",
            "lib/rustlib/{triple}/lib/*{staticlib_ext}",
            "lib/rustlib/{triple}/lib/self-contained/**",
        ],
        allow_empty = True,
    ),
)
"""

def _posix_link_script(links):
    """A shell script creating every link as a relative symlink."""
    return "\n".join([
        "mkdir -p \"$(dirname '{link}')\" && ln -s '{target}' '{link}'".format(link = link, target = relative_target)
        for link, relative_target, _, _ in links
    ])

def _windows_link_script(links):
    """A batch script creating every link the way a Windows checkout can.

    Directories become junctions (`mklink /J`), which need no privilege.
    Files are symlinks where the user may create them (Developer Mode or the
    `SeCreateSymbolicLinkPrivilege`), else hard links (`mklink /H`). Both
    forms resolve their target at creation, so they take the absolute path
    of the distribution file rather than the relative one.
    """
    lines = ["@echo off"]
    for link, _, absolute_target, is_directory in links:
        link = link.replace("/", "\\")
        target = str(absolute_target).replace("/", "\\")
        lines.append("if not exist \"{dir}\" mkdir \"{dir}\" || exit /b 1".format(dir = link.rpartition("\\")[0]))
        if is_directory:
            lines.append("mklink /J \"{link}\" \"{target}\" > nul || exit /b 1".format(link = link, target = target))
        else:
            lines.append("mklink \"{link}\" \"{target}\" > nul 2> nul || mklink /H \"{link}\" \"{target}\" > nul || exit /b 1".format(link = link, target = target))
    return "\r\n".join(lines) + "\r\n"

def _symlinked_rust_distribution_impl(rctx):
    host = get_host_triple(rctx)
    triple = host.str
    binary_ext = system_to_binary_ext(host.system)
    dylib_ext = system_to_dylib_ext(host.system)
    staticlib_ext = system_to_staticlib_ext(host.system, host.abi)

    rctx.file("BUILD.bazel", """exports_files(["host.bzl"])""")
    rctx.file("host.bzl", _HOST_BZL.format(triple = triple))
    rctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(rctx.name))
    rctx.file("nested/dist/BUILD.bazel", _DIST_BUILD.format(
        binary_ext = binary_ext,
        dylib_ext = dylib_ext,
        triple = triple,
    ))
    rctx.file("stdlib/{}/BUILD.bazel".format(triple), _STDLIB_BUILD.format(
        dylib_ext = dylib_ext,
        staticlib_ext = staticlib_ext,
        triple = triple,
    ))

    # `real` is the downloaded distribution, reached through one absolute
    # link (a junction on Windows); everything else in this repository is a
    # relative link into it.
    real = rctx.path(rctx.attr.distribution).dirname
    rctx.symlink(real, "real")

    # (link, target relative to the link's directory, absolute target, is a directory)
    links = []

    def link(path, relative_target, absolute_target, is_directory = False):
        links.append((path, relative_target, absolute_target, is_directory))

    for binary in ("rustc", "rustdoc", "clippy-driver", "cargo-clippy"):
        name = binary + binary_ext
        link("nested/dist/bin/" + name, "../../../real/bin/" + name, real.get_child("bin", name))
    for entry in real.get_child("lib").readdir():
        if entry.basename == "rustlib":
            continue
        link("nested/dist/lib/" + entry.basename, "../../../real/lib/" + entry.basename, entry, entry.is_dir)

    # A directory reached through a relative link, so that globs and the
    # generated tree have to look through it.
    link("nested/dist/lib/rustlib", "../../../real/lib/rustlib", real.get_child("lib", "rustlib"), True)

    # The standard library under its own package root, file by file.
    std_dir = "stdlib/{triple}/lib/rustlib/{triple}/lib".format(triple = triple)
    real_std = real.get_child("lib", "rustlib", triple, "lib")
    for entry in real_std.readdir():
        link(
            std_dir + "/" + entry.basename,
            "../../../../../../real/lib/rustlib/{}/lib/{}".format(triple, entry.basename),
            entry,
            entry.is_dir,
        )

    if host.system == "windows":
        rctx.file("link.bat", _windows_link_script(links))
        result = rctx.execute(["cmd.exe", "/c", "link.bat"])
    else:
        result = rctx.execute(["sh", "-ec", _posix_link_script(links)])
    if result.return_code != 0:
        fail("Failed to assemble the symlinked Rust distribution:\n{}{}".format(result.stdout, result.stderr))

    return None

symlinked_rust_distribution = repository_rule(
    doc = "Assembles a hand-crafted Rust distribution with an awkward, symlink-heavy layout out of the host's downloaded one.",
    implementation = _symlinked_rust_distribution_impl,
    attrs = {
        "distribution": attr.label(
            doc = "A file at the root of the distribution to assemble from, such as its `BUILD.bazel`.",
            default = Label("@rust_host_tools//:BUILD.bazel"),
            allow_single_file = True,
        ),
    },
)

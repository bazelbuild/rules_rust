"""Analysistests for Windows-specific library naming and link flags."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

# buildifier: disable=bzl-visibility
load("//rust/private:rustc.bzl", "portable_link_flags_for_testing", "symlink_for_ambiguous_lib_for_testing")

# buildifier: disable=bzl-visibility
load("//rust/private:utils.bzl", "get_lib_name_default", "get_lib_name_for_windows")

# buildifier: disable=provider-params
LinkFlagsInfo = provider(fields = {"flags": "List[str]"})

# buildifier: disable=provider-params
SymlinkInfo = provider(fields = {"symlink": "File"})

def _portable_link_flags_probe_impl(ctx):
    lib_artifact = ctx.actions.declare_file(ctx.attr.lib_basename)
    ctx.actions.write(lib_artifact, "", is_executable = False)
    library_to_link = struct(
        static_library = lib_artifact,
        pic_static_library = None,
        dynamic_library = None,
        interface_library = None,
        alwayslink = False,
    )

    get_lib_name = get_lib_name_for_windows if ctx.attr.flavor_msvc else get_lib_name_default
    flags = portable_link_flags_for_testing(
        lib = library_to_link,
        use_pic = False,
        ambiguous_libs = {},
        get_lib_name = get_lib_name,
        for_windows = True,
        flavor_msvc = ctx.attr.flavor_msvc,
    )

    return [
        DefaultInfo(files = depset([])),
        LinkFlagsInfo(flags = flags),
    ]

portable_link_flags_probe = rule(
    implementation = _portable_link_flags_probe_impl,
    attrs = {
        "flavor_msvc": attr.bool(default = False),
        "lib_basename": attr.string(mandatory = True),
    },
)

def _symlink_probe_impl(ctx):
    lib_artifact = ctx.actions.declare_file(ctx.attr.lib_basename)
    ctx.actions.write(lib_artifact, "", is_executable = False)
    crate_output = ctx.actions.declare_file("crate.rlib")
    ctx.actions.write(crate_output, "", is_executable = False)
    symlink = symlink_for_ambiguous_lib_for_testing(
        ctx.actions,
        toolchain = struct(target_abi = ctx.attr.target_abi),
        crate_info = struct(output = crate_output),
        lib = lib_artifact,
    )

    return [
        SymlinkInfo(symlink = symlink),
        DefaultInfo(files = depset([symlink])),
    ]

symlink_probe = rule(
    implementation = _symlink_probe_impl,
    attrs = {
        "lib_basename": attr.string(mandatory = True),
        "target_abi": attr.string(mandatory = True),
    },
)

def _portable_link_flags_windows_gnu_test_impl(ctx):
    env = analysistest.begin(ctx)
    flags = analysistest.target_under_test(env)[LinkFlagsInfo].flags

    asserts.equals(
        env,
        ["-lstatic=foo.dll", "-Clink-arg=-lfoo.dll"],
        flags,
    )
    return analysistest.end(env)

portable_link_flags_windows_gnu_test = analysistest.make(
    _portable_link_flags_windows_gnu_test_impl,
)

def _portable_link_flags_windows_msvc_test_impl(ctx):
    env = analysistest.begin(ctx)
    flags = analysistest.target_under_test(env)[LinkFlagsInfo].flags

    asserts.equals(
        env,
        ["-lstatic=libfoo.dll", "-Clink-arg=libfoo.dll.lib"],
        flags,
    )
    return analysistest.end(env)

portable_link_flags_windows_msvc_test = analysistest.make(
    _portable_link_flags_windows_msvc_test_impl,
)

def _symlink_name_windows_gnu_test_impl(ctx):
    env = analysistest.begin(ctx)
    symlink = analysistest.target_under_test(env)[SymlinkInfo].symlink

    asserts.true(env, symlink.basename.startswith("libfoo.dll-"))
    asserts.true(env, symlink.basename.endswith(".a"))
    asserts.false(env, symlink.basename.startswith("liblib"))

    return analysistest.end(env)

symlink_name_windows_gnu_test = analysistest.make(_symlink_name_windows_gnu_test_impl)

def _symlink_name_windows_msvc_test_impl(ctx):
    env = analysistest.begin(ctx)
    symlink = analysistest.target_under_test(env)[SymlinkInfo].symlink

    asserts.true(env, symlink.basename.startswith("native_dep-"))
    asserts.true(env, symlink.basename.endswith(".lib"))

    return analysistest.end(env)

symlink_name_windows_msvc_test = analysistest.make(_symlink_name_windows_msvc_test_impl)

def _define_targets():
    portable_link_flags_probe(
        name = "portable_link_flags_windows_gnu_probe",
        flavor_msvc = False,
        lib_basename = "libfoo.dll.a",
    )
    portable_link_flags_probe(
        name = "portable_link_flags_windows_msvc_probe",
        flavor_msvc = True,
        lib_basename = "libfoo.dll.lib",
    )

    symlink_probe(
        name = "symlink_windows_gnu_probe",
        lib_basename = "libfoo.dll.a",
        target_abi = "gnu",
    )
    symlink_probe(
        name = "symlink_windows_msvc_probe",
        lib_basename = "native_dep.lib",
        target_abi = "msvc",
    )

def windows_lib_name_test_suite(name):
    """Entry-point macro for Windows library naming tests.

    Args:
      name: test suite name
    """
    _define_targets()

    portable_link_flags_windows_gnu_test(
        name = "portable_link_flags_windows_gnu_test",
        target_under_test = ":portable_link_flags_windows_gnu_probe",
    )
    portable_link_flags_windows_msvc_test(
        name = "portable_link_flags_windows_msvc_test",
        target_under_test = ":portable_link_flags_windows_msvc_probe",
    )
    symlink_name_windows_gnu_test(
        name = "symlink_name_windows_gnu_test",
        target_under_test = ":symlink_windows_gnu_probe",
    )
    symlink_name_windows_msvc_test(
        name = "symlink_name_windows_msvc_test",
        target_under_test = ":symlink_windows_msvc_probe",
    )

    native.test_suite(
        name = name,
        tests = [
            ":portable_link_flags_windows_gnu_test",
            ":portable_link_flags_windows_msvc_test",
            ":symlink_name_windows_gnu_test",
            ":symlink_name_windows_msvc_test",
        ],
    )

"""Regression test for #4250: the C++-toolchain-provided linker must reach
rustc through `Args` as a `File`, not a plain string, so Bazel's path
mapping (`--experimental_output_paths=strip`) can rewrite it.

The bug only manifests for a hermetic/generated C++ toolchain -- one whose
linker tool is itself a Bazel artifact under `bazel-out/...` rather than an
absolute system path like `/usr/bin/gcc`. This test builds a minimal fake
cc_toolchain whose "linker" is a genrule output for exactly that reason.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "CPP_LINK_EXECUTABLE_ACTION_NAME")
load("@rules_cc//cc:cc_toolchain_config_lib.bzl", "action_config", "flag_group", "flag_set", "tool", "tool_path")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/toolchains:cc_toolchain_config_info.bzl", "CcToolchainConfigInfo")
load(
    "//test/unit:common.bzl",
    "assert_argv_contains_prefix_suffix",
)

def _fake_cc_config_impl(ctx):
    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        toolchain_identifier = "path-mapped-fake-cc",
        host_system_name = "unknown",
        target_system_name = "unknown",
        target_cpu = "unknown",
        target_libc = "unknown",
        compiler = "unknown",
        abi_version = "unknown",
        abi_libc_version = "unknown",
        # `tool_path`'s `path` is resolved relative to the cc_toolchain's own
        # package (see rules_cc's `get_relative_path`/`_compute_tool_paths`),
        # not as an already-exec-root-relative string -- it cannot reference a
        # generated artifact whose real location is under `bazel-out/<config>/...`.
        # Every legacy name must still be declared for `cc_toolchain` to accept
        # this config at all, so these are unused, never-invoked placeholders.
        tool_paths = [
            tool_path(name = name, path = "/usr/bin/false")
            for name in ("ar", "cpp", "gcc", "gcov", "ld", "nm", "objcopy", "objdump", "strip", "dwp", "llvm-profdata")
        ],
        # `tool(tool = <File>)`, by contrast, is exactly the mechanism a real
        # hermetic toolchain uses to point an action at a generated artifact:
        # `cc_common.get_tool_for_action()` then returns that File's own exec
        # path directly, config-dependent prefix and all -- reproducing what
        # #4250 reports, and letting `rustc.bzl`'s `_resolve_tool_file` find it.
        #
        # The `--sysroot=` flag_group is the other half of #4250: it is how a
        # real toolchain config emits a sysroot path, and
        # `cc_common.get_memory_inefficient_command_line()` returns it as a
        # single already-formatted string in `link_args` -- exactly what
        # `_wrap_sysroot_link_args` has to recognise and re-associate with
        # `ctx.file.sysroot`.
        action_configs = [
            action_config(
                action_name = CPP_LINK_EXECUTABLE_ACTION_NAME,
                enabled = True,
                tools = [tool(tool = ctx.file.linker)],
                flag_sets = [
                    # An action_config's own flag_sets apply implicitly to its
                    # action_name; specifying `actions` here is rejected.
                    flag_set(
                        flag_groups = [flag_group(flags = ["--sysroot=" + ctx.file.sysroot.path])],
                    ),
                ],
            ),
        ],
    )

fake_cc_config = rule(
    implementation = _fake_cc_config_impl,
    attrs = {
        "linker": attr.label(allow_single_file = True, mandatory = True),
        "sysroot": attr.label(allow_single_file = True, mandatory = True),
    },
    provides = [CcToolchainConfigInfo],
)

def _linker_is_path_mappable_test_impl(ctx):
    env = analysistest.begin(ctx)
    tut = analysistest.target_under_test(env)
    actions = [a for a in tut.actions if a.mnemonic == "Rustc"]
    asserts.true(
        env,
        len(actions) == 1,
        "expected exactly one Rustc action, got mnemonics: {}".format([a.mnemonic for a in tut.actions]),
    )
    if actions:
        # `analysis_test_transition` (which `config_settings` below drives)
        # refuses to set --experimental_* / --incompatible_* options, so this
        # test cannot force --experimental_output_paths=strip on itself --
        # only a whole invocation can (see the repo's own "Path Mapping
        # Linux/RBE/MacOS" CI jobs, which run this same test suite with the
        # flag build-wide). Checking only the suffix keeps this test valid
        # either way: run normally it passes trivially; run under
        # --experimental_output_paths=strip, a --codegen=linker= built from a
        # `File` is rewritten to the literal `bazel-out/cfg/...` prefix,
        # while the pre-#4250 plain-string form keeps the real, unmapped
        # configuration segment instead -- verified manually both ways.
        assert_argv_contains_prefix_suffix(env, actions[0], "--codegen=linker=", "/fake_gcc")

        # Same bug, the other half: a --sysroot= link arg pointing at a
        # generated artifact.
        assert_argv_contains_prefix_suffix(env, actions[0], "--codegen=link-arg=--sysroot=", "/fake_sysroot")
    return analysistest.end(env)

linker_is_path_mappable_test = analysistest.make(
    _linker_is_path_mappable_test_impl,
    config_settings = {
        str(Label("//rust/settings:toolchain_linker_preference")): "cc",
        "//command_line_option:extra_toolchains": [str(Label("//test/unit/path_mapped_linker:fake_cc_toolchain"))],
        # Confines the fake toolchain to this test's own configuration --
        # see the target_compatible_with comment on :fake_cc_toolchain in
        # BUILD.bazel for why this is necessary, not just belt-and-braces.
        "//command_line_option:platforms": [str(Label("//test/unit/path_mapped_linker:fake_platform"))],
    },
)

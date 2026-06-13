"""Starlark tests for Rust LTO."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//rust:defs.bzl", "rust_binary", "rust_library", "rust_library_group", "rust_proc_macro")
load(
    "//test/unit:common.bzl",
    "assert_action_mnemonic",
    "assert_argv_contains",
    "assert_argv_contains_not",
    "assert_argv_contains_prefix",
    "assert_argv_contains_prefix_not",
)

_ALLOCATOR_LIBRARIES_SETTING = str(Label("//rust/settings:experimental_use_allocator_libraries_with_mangled_symbols"))
_CC_COMMON_LINK_SETTING = str(Label("//rust/settings:experimental_use_cc_common_link"))
_GLOBAL_ALLOCATOR_SETTING = str(Label("//rust/settings:experimental_use_global_allocator"))
_LLVM_LINUX_CONFIG_SETTINGS = {
    "//command_line_option:extra_toolchains": ["@llvm//toolchain:all"],
    "//command_line_option:platforms": [str(Label("@llvm//platforms:linux_x86_64"))],
}
_DISTRIBUTED_THIN_LTO_CONFIG_SETTINGS = _LLVM_LINUX_CONFIG_SETTINGS | {
    _ALLOCATOR_LIBRARIES_SETTING: True,
    "//command_line_option:features": ["thin_lto"],
}
_RULE_FEATURE_THIN_LTO_CONFIG_SETTINGS = _LLVM_LINUX_CONFIG_SETTINGS | {
    _ALLOCATOR_LIBRARIES_SETTING: True,
}
_GLOBAL_ALLOCATOR_THIN_LTO_CONFIG_SETTINGS = _DISTRIBUTED_THIN_LTO_CONFIG_SETTINGS | {
    _CC_COMMON_LINK_SETTING: True,
    _GLOBAL_ALLOCATOR_SETTING: True,
}

_DepActionsInfo = provider(
    doc = "Actions registered by a dependency.",
    fields = {"actions": "list[Action]"},
)

def _collect_dep_actions_aspect_impl(target, _ctx):
    return [_DepActionsInfo(actions = target.actions)]

_collect_dep_actions_aspect = aspect(
    implementation = _collect_dep_actions_aspect_impl,
)

def _with_exec_cfg_impl(ctx):
    return [ctx.attr.target[_DepActionsInfo]]

_with_exec_cfg = rule(
    implementation = _with_exec_cfg_impl,
    attrs = {
        "target": attr.label(
            aspects = [_collect_dep_actions_aspect],
            cfg = "exec",
        ),
    },
)

def _lto_test_impl(ctx, lto_setting, embed_bitcode, linker_plugin):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    action = target.actions[0]
    assert_action_mnemonic(env, action, "Rustc")

    # Check if LTO is enabled.
    if lto_setting:
        assert_argv_contains(env, action, "-Clto={}".format(lto_setting))
    else:
        assert_argv_contains_prefix_not(env, action, "-Clto")

    # Check if we should embed bitcode.
    if embed_bitcode:
        assert_argv_contains(env, action, "-Cembed-bitcode={}".format(embed_bitcode))
    else:
        assert_argv_contains_prefix_not(env, action, "-Cembed-bitcode")

    # Check if we should use linker plugin LTO.
    if linker_plugin:
        assert_argv_contains(env, action, "-Clinker-plugin-lto")
    else:
        assert_argv_contains_not(env, action, "-Clinker-plugin-lto")

    return analysistest.end(env)

def _lto_level_default(ctx):
    return _lto_test_impl(ctx, None, "no", False)

_lto_level_default_test = analysistest.make(
    _lto_level_default,
    config_settings = {},
)

def _lto_level_manual(ctx):
    return _lto_test_impl(ctx, None, None, False)

_lto_level_manual_test = analysistest.make(
    _lto_level_manual,
    config_settings = {str(Label("//rust/settings:lto")): "manual"},
)

def _lto_level_off(ctx):
    return _lto_test_impl(ctx, "off", "no", False)

_lto_level_off_test = analysistest.make(
    _lto_level_off,
    config_settings = {str(Label("//rust/settings:lto")): "off"},
)

def _lto_level_thin(ctx):
    return _lto_test_impl(ctx, "thin", None, True)

_lto_level_thin_test = analysistest.make(
    _lto_level_thin,
    config_settings = {str(Label("//rust/settings:lto")): "thin"},
)

def _lto_level_fat(ctx):
    return _lto_test_impl(ctx, "fat", None, True)

_lto_level_fat_test = analysistest.make(
    _lto_level_fat,
    config_settings = {str(Label("//rust/settings:lto")): "fat"},
)

def _lto_proc_macro(ctx):
    return _lto_test_impl(ctx, None, "no", False)

_lto_proc_macro_test = analysistest.make(
    _lto_proc_macro,
    config_settings = {str(Label("//rust/settings:lto")): "thin"},
)

def _distributed_thin_lto_library(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    action = [action for action in target.actions if action.mnemonic == "Rustc"][0]

    assert_argv_contains(env, action, "--emit=link")
    assert_argv_contains_prefix(env, action, "--emit=obj=")
    assert_argv_contains(env, action, "-Clinker-plugin-lto")
    assert_argv_contains_prefix_not(env, action, "-Clto")
    assert_argv_contains_prefix_not(env, action, "-Cembed-bitcode")

    output_basenames = [output.basename for output in action.outputs.to_list()]
    asserts.true(env, any([name.startswith("libdistributed_lib-") and name.endswith(".rlib") for name in output_basenames]))
    asserts.true(env, any([name.startswith("libdistributed_lib-") and name.endswith(".rlib.o") for name in output_basenames]))

    linker_inputs = target[CcInfo].linking_context.linker_inputs.to_list()
    lto_bitcode_files = [
        file.basename
        for linker_input in linker_inputs
        for library in linker_input.libraries
        for file in library.lto_bitcode_files
    ]
    asserts.true(env, any([name.startswith("libdistributed_lib-") and name.endswith(".rlib.o") for name in lto_bitcode_files]))

    return analysistest.end(env)

_distributed_thin_lto_library_test = analysistest.make(
    _distributed_thin_lto_library,
    config_settings = _DISTRIBUTED_THIN_LTO_CONFIG_SETTINGS,
)

def _assert_distributed_thin_lto_link(env, target):
    actions_by_mnemonic = {
        action.mnemonic: action
        for action in target.actions
    }
    asserts.true(env, "CppLTOIndexing" in actions_by_mnemonic)
    asserts.true(env, "CppLink" in actions_by_mnemonic)

    lto_backend_inputs = [
        file.basename
        for action in target.actions
        if action.mnemonic == "CcLtoBackendCompile"
        for file in action.inputs.to_list()
    ]
    asserts.true(env, any([name.startswith("libdistributed_lib-") and name.endswith(".rlib.o") for name in lto_backend_inputs]))

    return actions_by_mnemonic

def _distributed_thin_lto_binary(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    actions_by_mnemonic = _assert_distributed_thin_lto_link(env, target)
    link_inputs = [file.basename for file in actions_by_mnemonic["CppLink"].inputs.to_list()]
    asserts.true(env, any(["allocator_library" in name and name.endswith(".a") for name in link_inputs]))
    rustc_action = actions_by_mnemonic["Rustc"]
    assert_argv_contains_prefix(env, rustc_action, "--emit=obj=")
    assert_argv_contains(env, rustc_action, "-Clinker-plugin-lto")
    object_outputs = [file.basename for file in rustc_action.outputs.to_list() if file.extension == "o"]
    asserts.equals(env, 1, len(object_outputs))
    asserts.equals(env, target.label.name + ".o", object_outputs[0])

    return analysistest.end(env)

_distributed_thin_lto_binary_test = analysistest.make(
    _distributed_thin_lto_binary,
    config_settings = _DISTRIBUTED_THIN_LTO_CONFIG_SETTINGS,
)

def _distributed_thin_lto_global_allocator(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    _assert_distributed_thin_lto_link(env, target)

    lto_backend_inputs = [
        file.basename
        for action in target.actions
        if action.mnemonic == "CcLtoBackendCompile"
        for file in action.inputs.to_list()
    ]
    asserts.true(env, any([
        name.startswith("libglobal_allocator_library-") and name.endswith(".rlib.o")
        for name in lto_backend_inputs
    ]))

    return analysistest.end(env)

_distributed_thin_lto_global_allocator_test = analysistest.make(
    _distributed_thin_lto_global_allocator,
    config_settings = _GLOBAL_ALLOCATOR_THIN_LTO_CONFIG_SETTINGS,
)

def _distributed_thin_lto_cc_binary(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    _assert_distributed_thin_lto_link(env, target)

    return analysistest.end(env)

_distributed_thin_lto_cc_binary_test = analysistest.make(
    _distributed_thin_lto_cc_binary,
    config_settings = _RULE_FEATURE_THIN_LTO_CONFIG_SETTINGS,
)

def _distributed_thin_lto_requires_allocator_setting(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "distributed ThinLTO requires --@rules_rust//rust/settings:experimental_use_allocator_libraries_with_mangled_symbols")
    return analysistest.end(env)

_distributed_thin_lto_requires_allocator_setting_test = analysistest.make(
    _distributed_thin_lto_requires_allocator_setting,
    expect_failure = True,
    config_settings = _LLVM_LINUX_CONFIG_SETTINGS | {
        "//command_line_option:features": ["thin_lto"],
    },
)

_thin_lto_feature_overrides_manual_lto_setting_test = analysistest.make(
    _distributed_thin_lto_binary,
    config_settings = _DISTRIBUTED_THIN_LTO_CONFIG_SETTINGS | {
        str(Label("//rust/settings:lto")): "manual",
    },
)

def _unsupported_distributed_thin_lto_binary(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    rustc_action = [action for action in target.actions if action.mnemonic == "Rustc"][0]

    assert_argv_contains_prefix(env, rustc_action, "--emit=link")
    assert_argv_contains_prefix_not(env, rustc_action, "-Clto")
    assert_argv_contains_prefix_not(env, rustc_action, "-Clinker-plugin-lto")

    return analysistest.end(env)

_wasm_thin_lto_binary_test = analysistest.make(
    _unsupported_distributed_thin_lto_binary,
    config_settings = {
        "//command_line_option:extra_toolchains": ["@llvm//toolchain:all"],
        "//command_line_option:features": ["thin_lto"],
        "//command_line_option:platforms": [str(Label("@llvm//platforms:none_wasm32"))],
    },
)

_no_std_thin_lto_binary_test = analysistest.make(
    _unsupported_distributed_thin_lto_binary,
    config_settings = _LLVM_LINUX_CONFIG_SETTINGS | {
        str(Label("//rust/settings:no_std")): "alloc",
        "//command_line_option:features": ["thin_lto"],
    },
)

_disabled_thin_lto_binary_test = analysistest.make(
    _unsupported_distributed_thin_lto_binary,
    config_settings = _LLVM_LINUX_CONFIG_SETTINGS | {
        "//command_line_option:features": ["thin_lto"],
    },
)

def _target_feature_not_used_in_exec_configuration(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    rustc_action = [action for action in target[_DepActionsInfo].actions if action.mnemonic == "Rustc"][0]

    assert_argv_contains_prefix_not(env, rustc_action, "-Clto")
    assert_argv_contains_prefix_not(env, rustc_action, "-Clinker-plugin-lto")

    return analysistest.end(env)

_target_feature_not_used_in_exec_configuration_test = analysistest.make(
    _target_feature_not_used_in_exec_configuration,
    config_settings = {
        "//command_line_option:features": ["thin_lto"],
        "//command_line_option:host_features": [],
    },
)

def lto_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): The name of the test suite.
    """
    write_file(
        name = "crate_lib",
        out = "lib.rs",
        content = [
            "pub fn add(left: usize, right: usize) -> usize {",
            "    *std::hint::black_box(Box::new(left + right))",
            "}",
            "",
            "#[no_mangle]",
            "pub extern \"C\" fn distributed_add(left: usize, right: usize) -> usize {",
            "    left + right",
            "}",
            "",
        ],
    )

    write_file(
        name = "crate_bin",
        out = "main.rs",
        content = [
            "fn main() { assert_eq!(distributed_lib::add(2, 2), 4); }",
            "",
        ],
    )

    write_file(
        name = "global_allocator_bin",
        out = "global_allocator.rs",
        content = [
            "use std::alloc::{GlobalAlloc, Layout, System};",
            "struct Allocator;",
            "unsafe impl GlobalAlloc for Allocator {",
            "    unsafe fn alloc(&self, layout: Layout) -> *mut u8 { System.alloc(layout) }",
            "    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) { System.dealloc(ptr, layout) }",
            "}",
            "#[global_allocator]",
            "static GLOBAL: Allocator = Allocator;",
            "fn main() { assert_eq!(distributed_lib::add(2, 2), 4); }",
            "",
        ],
    )

    write_file(
        name = "crate_cc_bin",
        out = "main.cc",
        content = [
            "#include <cstdint>",
            "extern \"C\" uintptr_t distributed_add(uintptr_t, uintptr_t);",
            "int main() { return distributed_add(2, 2) == 4 ? 0 : 1; }",
            "",
        ],
    )

    rust_library(
        name = "lib",
        srcs = [":lib.rs"],
        edition = "2021",
    )

    rust_proc_macro(
        name = "proc_macro",
        srcs = [":lib.rs"],
        edition = "2021",
    )

    rust_library(
        name = "distributed_lib",
        srcs = [":lib.rs"],
        edition = "2021",
    )

    rust_library(
        name = "distributed_lib_rule_feature",
        srcs = [":lib.rs"],
        crate_name = "distributed_lib",
        edition = "2021",
        features = ["thin_lto"],
    )

    rust_library(
        name = "distributed_lib_disabled_feature",
        srcs = [":lib.rs"],
        crate_name = "distributed_lib",
        edition = "2021",
        features = ["-thin_lto"],
    )

    rust_library_group(
        name = "distributed_lib_group",
        deps = [":distributed_lib"],
    )

    rust_binary(
        name = "distributed_bin",
        srcs = [":main.rs"],
        deps = [":distributed_lib_group"],
        edition = "2021",
    )

    rust_binary(
        name = "distributed_global_allocator_bin",
        srcs = [":global_allocator_bin"],
        deps = [":distributed_lib_group"],
        edition = "2021",
    )

    rust_binary(
        name = "distributed_bin_disabled_feature",
        srcs = [":main.rs"],
        deps = [":distributed_lib_disabled_feature"],
        edition = "2021",
        features = ["-thin_lto"],
    )

    cc_binary(
        name = "distributed_cc_bin",
        srcs = [":main.cc"],
        deps = [":distributed_lib_rule_feature"],
        features = ["thin_lto"],
    )

    _with_exec_cfg(
        name = "distributed_bin_exec",
        target = ":distributed_bin",
    )

    _lto_level_default_test(
        name = "lto_level_default_test",
        target_under_test = ":lib",
    )

    _lto_level_manual_test(
        name = "lto_level_manual_test",
        target_under_test = ":lib",
    )

    _lto_level_off_test(
        name = "lto_level_off_test",
        target_under_test = ":lib",
    )

    _lto_level_thin_test(
        name = "lto_level_thin_test",
        target_under_test = ":lib",
    )

    _lto_level_fat_test(
        name = "lto_level_fat_test",
        target_under_test = ":lib",
    )

    _lto_proc_macro_test(
        name = "lto_proc_macro_test",
        target_under_test = ":proc_macro",
    )

    _distributed_thin_lto_library_test(
        name = "distributed_thin_lto_library_test",
        target_under_test = ":distributed_lib",
    )

    _distributed_thin_lto_binary_test(
        name = "distributed_thin_lto_binary_test",
        target_under_test = ":distributed_bin",
    )

    _distributed_thin_lto_global_allocator_test(
        name = "distributed_thin_lto_global_allocator_test",
        target_under_test = ":distributed_global_allocator_bin",
    )

    _distributed_thin_lto_cc_binary_test(
        name = "distributed_thin_lto_cc_binary_test",
        target_under_test = ":distributed_cc_bin",
    )

    _distributed_thin_lto_requires_allocator_setting_test(
        name = "distributed_thin_lto_requires_allocator_setting_test",
        target_under_test = ":distributed_bin",
    )

    _thin_lto_feature_overrides_manual_lto_setting_test(
        name = "thin_lto_feature_overrides_manual_lto_setting_test",
        target_under_test = ":distributed_bin",
    )

    _wasm_thin_lto_binary_test(
        name = "wasm_thin_lto_binary_test",
        target_under_test = ":distributed_bin",
    )

    _no_std_thin_lto_binary_test(
        name = "no_std_thin_lto_binary_test",
        target_under_test = ":distributed_bin",
    )

    _disabled_thin_lto_binary_test(
        name = "disabled_thin_lto_binary_test",
        target_under_test = ":distributed_bin_disabled_feature",
    )

    _target_feature_not_used_in_exec_configuration_test(
        name = "target_feature_not_used_in_exec_configuration_test",
        target_under_test = ":distributed_bin_exec",
    )

    native.test_suite(
        name = name,
        tests = [
            ":lto_level_default_test",
            ":lto_level_manual_test",
            ":lto_level_off_test",
            ":lto_level_thin_test",
            ":lto_level_fat_test",
            ":lto_proc_macro_test",
            ":distributed_thin_lto_library_test",
            ":distributed_thin_lto_binary_test",
            ":distributed_thin_lto_global_allocator_test",
            ":distributed_thin_lto_cc_binary_test",
            ":distributed_thin_lto_requires_allocator_setting_test",
            ":thin_lto_feature_overrides_manual_lto_setting_test",
            ":wasm_thin_lto_binary_test",
            ":no_std_thin_lto_binary_test",
            ":disabled_thin_lto_binary_test",
            ":target_feature_not_used_in_exec_configuration_test",
        ],
    )

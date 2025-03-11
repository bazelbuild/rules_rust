""" Generate CcToolchainConfigInfo for LLVM """

load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "artifact_name_pattern",
    "feature",
)
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("//bazel/toolchain_rules/cc_tools:clang.bzl", clang_compile_action_configs = "compile_action_configs")
load("//bazel/toolchain_rules/cc_tools:ld.lld.bzl", ld_lld_link_action_configs = "link_action_configs")
load("//bazel/toolchain_rules/cc_tools:ld64.lld.bzl", ld64_lld_link_action_configs = "link_action_configs")
load("//bazel/toolchain_rules/cc_tools:lld_link.bzl", lld_link_link_action_configs = "link_action_configs")
load("//bazel/toolchain_rules/cc_tools:llvm_ar.bzl", llvm_ar_archive_action_configs = "archive_action_configs")
load("//bazel/toolchain_rules/cc_tools:llvm_strip.bzl", llvm_strip_strip_action_configs = "strip_action_configs")
load("//bazel/toolchain_rules/cc_tools:wasm_ld.bzl", wasm_ld_link_action_configs = "link_action_configs")

APPLE_ARTIFACT_NAME_PATTERNS = [
    # Artifact name patterns differ from the defaults only for dynamic libraries.
    artifact_name_pattern(
        category_name = "dynamic_library",
        prefix = "lib",
        extension = ".dylib",
    ),
]

LINUX_ARTIFACT_NAME_PATTERNS = [
    # Artifact name patterns are the default.
]

WASM_ARTIFACT_NAME_PATTERNS = [
    # Artifact name patterns differ from the defaults only for executables.
    artifact_name_pattern(
        category_name = "executable",
        prefix = "",
        extension = ".wasm",
    ),
]

WINDOWS_ARTIFACT_NAME_PATTERNS = [
    artifact_name_pattern(
        category_name = "object_file",
        prefix = "",
        extension = ".obj",
    ),
    artifact_name_pattern(
        category_name = "static_library",
        prefix = "",
        extension = ".lib",
    ),
    artifact_name_pattern(
        category_name = "alwayslink_static_library",
        prefix = "",
        extension = ".lo.lib",
    ),
    artifact_name_pattern(
        category_name = "executable",
        prefix = "",
        extension = ".exe",
    ),
    artifact_name_pattern(
        category_name = "dynamic_library",
        prefix = "",
        extension = ".dll",
    ),
    artifact_name_pattern(
        category_name = "interface_library",
        prefix = "",
        extension = ".if.lib",
    ),
]

TARGET_CONFIG = {
    "aarch64-apple-darwin": struct(
        artifact_name_patterns = APPLE_ARTIFACT_NAME_PATTERNS,
        compile_action_configs = clang_compile_action_configs,
        archive_action_configs = llvm_ar_archive_action_configs,
        link_action_configs = ld64_lld_link_action_configs,
        strip_action_configs = llvm_strip_strip_action_configs,
    ),
    "aarch64-apple-ios": struct(
        artifact_name_patterns = APPLE_ARTIFACT_NAME_PATTERNS,
        compile_action_configs = clang_compile_action_configs,
        archive_action_configs = llvm_ar_archive_action_configs,
        link_action_configs = ld64_lld_link_action_configs,
        strip_action_configs = llvm_strip_strip_action_configs,
    ),
    "aarch64-linux-android": struct(
        artifact_name_patterns = LINUX_ARTIFACT_NAME_PATTERNS,
        compile_action_configs = clang_compile_action_configs,
        archive_action_configs = llvm_ar_archive_action_configs,
        link_action_configs = ld_lld_link_action_configs,
        strip_action_configs = llvm_strip_strip_action_configs,
    ),
    "aarch64-unknown-linux-gnu": struct(
        artifact_name_patterns = LINUX_ARTIFACT_NAME_PATTERNS,
        compile_action_configs = clang_compile_action_configs,
        archive_action_configs = llvm_ar_archive_action_configs,
        link_action_configs = ld_lld_link_action_configs,
        strip_action_configs = llvm_strip_strip_action_configs,
    ),
    "wasm32-unknown-unknown": struct(
        artifact_name_patterns = WASM_ARTIFACT_NAME_PATTERNS,
        compile_action_configs = clang_compile_action_configs,
        archive_action_configs = llvm_ar_archive_action_configs,
        link_action_configs = wasm_ld_link_action_configs,
        strip_action_configs = llvm_strip_strip_action_configs,
    ),
    "wasm32-wasip1": struct(
        artifact_name_patterns = WASM_ARTIFACT_NAME_PATTERNS,
        compile_action_configs = clang_compile_action_configs,
        archive_action_configs = llvm_ar_archive_action_configs,
        link_action_configs = wasm_ld_link_action_configs,
        strip_action_configs = llvm_strip_strip_action_configs,
    ),
    "x86_64-apple-darwin": struct(
        artifact_name_patterns = APPLE_ARTIFACT_NAME_PATTERNS,
        compile_action_configs = clang_compile_action_configs,
        archive_action_configs = llvm_ar_archive_action_configs,
        link_action_configs = ld64_lld_link_action_configs,
        strip_action_configs = llvm_strip_strip_action_configs,
    ),
    "x86_64-pc-windows-msvc": struct(
        artifact_name_patterns = WINDOWS_ARTIFACT_NAME_PATTERNS,
        compile_action_configs = clang_compile_action_configs,
        archive_action_configs = llvm_ar_archive_action_configs,
        link_action_configs = lld_link_link_action_configs,
        strip_action_configs = llvm_strip_strip_action_configs,
    ),
    "x86_64-unknown-linux-gnu": struct(
        artifact_name_patterns = LINUX_ARTIFACT_NAME_PATTERNS,
        compile_action_configs = clang_compile_action_configs,
        archive_action_configs = llvm_ar_archive_action_configs,
        link_action_configs = ld_lld_link_action_configs,
        strip_action_configs = llvm_strip_strip_action_configs,
    ),
}

def _llvm_cc_toolchain_config_impl(ctx):
    target_config = TARGET_CONFIG[ctx.attr.target]

    compile_action_configs = target_config.compile_action_configs(
        clang = ctx.attr.clang,
        target = ctx.attr.target,
        builtin_include_directories = ctx.attr.builtin_include_directories,
        builtin_framework_directories = ctx.attr.builtin_framework_directories,
        compile_flags = ctx.attr.compile_flags,
        dbg_compile_flags = ctx.attr.dbg_compile_flags,
        fastbuild_compile_flags = ctx.attr.fastbuild_compile_flags,
        opt_compile_flags = ctx.attr.opt_compile_flags,
        remap_path_prefix = ctx.attr.remap_path_prefix,
    )

    archive_action_configs = target_config.archive_action_configs(
        llvm = ctx.attr.llvm,
        archive_flags = ctx.attr.archive_flags,
    )

    link_action_configs = target_config.link_action_configs(
        llvm = ctx.attr.llvm,
        builtin_library_directories = ctx.attr.builtin_library_directories,
        builtin_libraries = ctx.attr.builtin_libraries,
        builtin_framework_directories = ctx.attr.builtin_framework_directories,
        builtin_frameworks = ctx.attr.builtin_frameworks,
        builtin_executable_objects = ctx.attr.builtin_executable_objects,
        link_flags = ctx.attr.link_flags,
        dbg_link_flags = ctx.attr.dbg_link_flags,
        fastbuild_link_flags = ctx.attr.fastbuild_link_flags,
        opt_link_flags = ctx.attr.opt_link_flags,
    )

    strip_action_configs = target_config.strip_action_configs(
        llvm = ctx.attr.llvm,
    )

    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        features = [
            feature(name = "no_legacy_features", enabled = True),
            feature(name = "supports_start_end_lib", enabled = ctx.attr.supports_start_end_lib),
            feature(name = "supports_interface_shared_libraries", enabled = False),
            feature(name = "supports_dynamic_linker", enabled = True),
            feature(name = "has_configured_linker_path", enabled = True),
            feature(name = "static_link_cpp_runtimes", enabled = False),
            feature(name = "supports_pic", enabled = True),
        ],
        action_configs = compile_action_configs +
                         archive_action_configs +
                         link_action_configs +
                         strip_action_configs,
        artifact_name_patterns = target_config.artifact_name_patterns,
        cxx_builtin_include_directories = ctx.attr.builtin_include_directories,
        toolchain_identifier = ctx.attr.name,
        host_system_name = None,
        target_system_name = ctx.attr.target,
        target_cpu = "unused",
        target_libc = "unused",
        compiler = "unused",
        abi_version = None,
        abi_libc_version = None,
        tool_paths = [],
        make_variables = [],
        builtin_sysroot = None,
        cc_target_os = None,
    )

llvm_cc_toolchain_config = rule(
    implementation = _llvm_cc_toolchain_config_impl,
    attrs = {
        "archive_flags": attr.string_list(),
        "builtin_executable_objects": attr.string_list(),
        "builtin_framework_directories": attr.string_list(),
        "builtin_frameworks": attr.string_list(),
        "builtin_include_directories": attr.string_list(),
        "builtin_libraries": attr.string_list(),
        "builtin_library_directories": attr.string_list(),
        "clang": attr.string(mandatory = True),
        "compile_flags": attr.string_list(),
        "dbg_compile_flags": attr.string_list(),
        "dbg_link_flags": attr.string_list(),
        "fastbuild_compile_flags": attr.string_list(),
        "fastbuild_link_flags": attr.string_list(),
        "link_flags": attr.string_list(),
        "llvm": attr.string(mandatory = True),
        "opt_compile_flags": attr.string_list(),
        "opt_link_flags": attr.string_list(),
        "remap_path_prefix": attr.string(),
        "supports_start_end_lib": attr.bool(default = True),
        "target": attr.string(mandatory = True),
    },
    provides = [CcToolchainConfigInfo],
)

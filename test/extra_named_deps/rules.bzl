load("@rules_rust//rust/private:common.bzl", "COMMON_PROVIDERS")
load("@rules_rust//rust/private:providers.bzl", "CrateInfo", "DepInfo")
load("@rules_rust//rust/private:rust.bzl", "RUSTC_ATTRS")
load("@rules_rust//rust/private:rustc.bzl", "AliasableDepInfo", "rustc_compile_action")
load(
    "@rules_rust//rust/private:utils.bzl",
    "compute_crate_name",
    "determine_lib_name",
    "determine_output_hash",
    "find_toolchain",
    "generate_output_diagnostics",
    "get_edition",
    "transform_deps",
)

def _rust_library_with_extra_deps_impl(ctx):
    toolchain = find_toolchain(ctx)
    crate_name = compute_crate_name(ctx.workspace_name, ctx.label, toolchain, ctx.attr.crate_name)

    # Assume the first file in srcs is the crate root.
    crate_root = ctx.files.srcs[0]

    output_hash = determine_output_hash(crate_root, ctx.label)
    rust_lib_name = determine_lib_name(crate_name, "rlib", toolchain, output_hash)
    rust_lib = ctx.actions.declare_file(rust_lib_name)

    deps = transform_deps(ctx.attr.deps)

    # Find indirect deps to rename
    rename_labels = {Label(k): v for k, v in ctx.attr.rename_indirect_deps.items()}
    extra_named_deps_list = []

    for dep in deps:
        if dep.dep_info:
            for transitive_crate in dep.dep_info.transitive_crates.to_list():
                if transitive_crate.owner in rename_labels:
                    new_name = rename_labels[transitive_crate.owner]
                    extra_named_deps_list.append(AliasableDepInfo(
                        dep = transitive_crate,
                        name = new_name,
                    ))

    extra_named_deps = depset(extra_named_deps_list) if extra_named_deps_list else None

    # Call rustc_compile_action
    providers = rustc_compile_action(
        ctx = ctx,
        attr = ctx.attr,
        toolchain = toolchain,
        output_hash = output_hash,
        crate_info_dict = dict(
            name = crate_name,
            type = "rlib",
            root = crate_root,
            srcs = ctx.files.srcs,
            deps = deps,
            proc_macro_deps = [],
            aliases = ctx.attr.aliases,
            output = rust_lib,
            rustc_output = generate_output_diagnostics(ctx, rust_lib),
            metadata = None,
            metadata_supports_pipelining = False,
            rustc_rmeta_output = None,
            edition = get_edition(ctx.attr, toolchain, ctx.label),
            rustc_env = {},
            is_test = False,
            data = depset([]),
            compile_data = depset([]),
            compile_data_targets = depset([]),
            owner = ctx.label,
        ),
        extra_named_deps = extra_named_deps,
    )

    return providers

rust_library_with_extra_deps = rule(
    implementation = _rust_library_with_extra_deps_impl,
    provides = COMMON_PROVIDERS,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "deps": attr.label_list(providers = [[CrateInfo, DepInfo]]),
        "crate_name": attr.string(),
        "edition": attr.string(default = "2021"),
        "aliases": attr.label_keyed_string_dict(),
        "rename_indirect_deps": attr.string_dict(),
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
    } | RUSTC_ATTRS,
    fragments = ["cpp"],
    toolchains = [
        str(Label("//rust:toolchain_type")),
        config_common.toolchain_type("@bazel_tools//tools/cpp:toolchain_type", mandatory = False),
    ],
)

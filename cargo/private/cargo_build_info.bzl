"""Generic rule for packaging files as a `BuildInfo` provider with optional `CcInfo` propagation.

Serves as a build-script replacement for `-sys` crates that need files placed in `OUT_DIR`
and/or linking against a C/C++ library.
"""

load("@rules_cc//cc:defs.bzl", "CcInfo")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("//rust:rust_common.bzl", "BuildInfo")

# buildifier: disable=bzl-visibility
load("//rust/private:utils.bzl", "get_lib_name_default")

def _get_user_link_flags(cc_info):
    linker_flags = []
    for linker_input in cc_info.linking_context.linker_inputs.to_list():
        linker_flags.extend(linker_input.user_link_flags)
    return linker_flags

def _cargo_build_info_impl(ctx):
    out_dir = ctx.actions.declare_directory(ctx.label.name + ".out_dir")
    env_out = ctx.actions.declare_file(ctx.label.name + ".env")
    dep_env_out = ctx.actions.declare_file(ctx.label.name + ".depenv")
    flags_out = ctx.actions.declare_file(ctx.label.name + ".flags")
    link_flags = ctx.actions.declare_file(ctx.label.name + ".linkflags")
    link_search_paths = ctx.actions.declare_file(ctx.label.name + ".linksearchpaths")

    compile_data = []
    cc_link_flags = []
    cc_link_search_paths = []

    if ctx.attr.cc_lib:
        cc_info = ctx.attr.cc_lib[CcInfo]
        for linker_input in cc_info.linking_context.linker_inputs.to_list():
            for lib in linker_input.libraries:
                if lib.static_library:
                    cc_link_flags.append("-lstatic={}".format(get_lib_name_default(lib.static_library)))
                    cc_link_search_paths.append(lib.static_library.dirname)
                    compile_data.append(lib.static_library)
                elif lib.pic_static_library:
                    cc_link_flags.append("-lstatic={}".format(get_lib_name_default(lib.pic_static_library)))
                    cc_link_search_paths.append(lib.pic_static_library.dirname)
                    compile_data.append(lib.pic_static_library)

    dep_env_lines = []
    if ctx.attr.dep_env:
        if ctx.attr.links:
            prefix = "DEP_{}_".format(ctx.attr.links.replace("-", "_").upper())
        else:
            prefix = ""
        dep_env_lines = ["{}{}={}".format(prefix, k, v) for k, v in ctx.attr.dep_env.items()]

    # Collect files and their destinations, validating single-file labels.
    input_files = []
    file_args = []
    for label, dests_json in ctx.attr.out_dir_files.items():
        src_files = label.files.to_list()
        if len(src_files) != 1:
            fail("Expected exactly one file for {}, got {}".format(label, len(src_files)))
        src_file = src_files[0]
        input_files.append(src_file)
        for dest in json.decode(dests_json):
            file_args.append("{}={}".format(dest, src_file.path))

    args = ctx.actions.args()
    args.add(out_dir.path, format = "--out_dir=%s")
    args.add(env_out, format = "--env_out=%s")
    args.add(flags_out, format = "--flags_out=%s")
    args.add(link_flags, format = "--link_flags=%s")
    args.add(link_search_paths, format = "--link_search_paths=%s")
    args.add(dep_env_out, format = "--dep_env_out=%s")

    args.add_all(file_args, format_each = "--file=%s")
    args.add_all(ctx.attr.rustc_flags, format_each = "--rustc_flag=%s")
    args.add_all(
        [
            "{}={}".format(k, v)
            for k, v in ctx.attr.rustc_env.items()
        ],
        format_each = "--rustc_env=%s",
    )
    args.add_all(dep_env_lines, format_each = "--dep_env=%s")
    args.add_all(cc_link_flags, format_each = "--link_flag=%s")
    args.add_all(
        depset(cc_link_search_paths).to_list(),
        format_each = "--link_search_path=%s",
    )

    ctx.actions.run(
        mnemonic = "CargoBuildInfo",
        executable = ctx.executable._runner,
        arguments = [args],
        inputs = input_files + compile_data,
        outputs = [out_dir, env_out, dep_env_out, flags_out, link_flags, link_search_paths],
    )

    providers = [
        DefaultInfo(files = depset([out_dir])),
        BuildInfo(
            out_dir = out_dir,
            rustc_env = env_out,
            dep_env = dep_env_out,
            flags = flags_out,
            linker_flags = link_flags,
            link_search_paths = link_search_paths,
            compile_data = depset(compile_data),
        ),
    ]

    if ctx.attr.cc_lib:
        providers.append(CcInfo(
            linking_context = cc_common.create_linking_context(
                linker_inputs = depset([cc_common.create_linker_input(
                    owner = ctx.label,
                    user_link_flags = _get_user_link_flags(ctx.attr.cc_lib[CcInfo]),
                )]),
            ),
        ))

    return providers

cargo_build_info = rule(
    doc = "Packages files into an `OUT_DIR` and returns a `BuildInfo` provider, serving as a drop-in replacement for `cargo_build_script`.",
    implementation = _cargo_build_info_impl,
    attrs = {
        "cc_lib": attr.label(
            doc = "Optional `cc_library` whose `CcInfo` linking context is propagated. Static libraries are added to link flags and search paths.",
            providers = [CcInfo],
        ),
        "dep_env": attr.string_dict(
            doc = "Environment variables exported to dependent build scripts. Keys are auto-prefixed with `DEP_{LINKS}_` when `links` is set.",
        ),
        "links": attr.string(
            doc = "The Cargo `links` field value. Used to prefix `dep_env` keys with `DEP_{LINKS}_`.",
        ),
        "out_dir_files": attr.label_keyed_string_dict(
            doc = "Map of source file labels to JSON-encoded lists of destination paths within `OUT_DIR`. Use the `cargo_build_info` macro for an ergonomic `{dest: label}` interface.",
            allow_files = True,
        ),
        "rustc_env": attr.string_dict(
            doc = "Extra environment variables to set for rustc.",
        ),
        "rustc_flags": attr.string_list(
            doc = "Extra flags to pass to rustc.",
        ),
        "_runner": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//cargo/private:cargo_build_info_runner"),
        ),
    },
)

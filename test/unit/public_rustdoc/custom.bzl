"""A custom build-time doctest rule using only public rules_rust loads."""

load("//rust:rust_common.bzl", "CrateInfo", "LintsInfo", "transform_deps")
load("//rust:rust_doc.bzl", "rustdoc_compile_action")

def _custom_impl(ctx):
    crate = ctx.attr.crate[CrateInfo]

    # This verifies the public provider identity against a standard rust_library.
    lints = ctx.attr.crate[LintsInfo]
    normal = transform_deps(ctx.attr.deps)
    macros = transform_deps(ctx.attr.proc_macro_deps)
    if normal[0].crate_info != ctx.attr.deps[0][CrateInfo]:
        fail("dependency conversion must preserve provider identity")
    if macros[0].crate_info.type != "proc-macro":
        fail("procedural-macro conversion must preserve its crate type")

    stamp = ctx.actions.declare_file(ctx.label.name + ".passed")
    flags = ctx.actions.args()
    flags.add("--test")
    flags.add(crate.output, format = "--extern=%s=%%s" % crate.name)
    action = rustdoc_compile_action(
        ctx = ctx,
        toolchain = ctx.toolchains[Label("//rust:toolchain_type")],
        crate_info = crate,
        lints_info = lints,
        rustdoc_flags = flags,
        force_depend_on_objects = True,
    )
    wrapper_flags = ctx.actions.args()
    wrapper_flags.add("--touch-file", stamp)
    ctx.actions.run(
        executable = action.executable,
        inputs = action.inputs,
        outputs = [stamp],
        arguments = [wrapper_flags] + action.arguments,
        env = action.env | {"TMPDIR": "${pwd}/" + stamp.dirname},
        tools = action.tools,
        toolchain = Label("//rust:toolchain_type"),
        execution_requirements = {"supports-path-mapping": ""} if action.supports_path_mapping else {},
        mnemonic = "CustomRustdoc",
    )
    return [DefaultInfo(files = depset([stamp]))]

custom_doctest = rule(
    implementation = _custom_impl,
    attrs = {
        "crate": attr.label(mandatory = True, providers = [CrateInfo, LintsInfo]),
        "deps": attr.label_list(providers = [CrateInfo]),
        "proc_macro_deps": attr.label_list(providers = [CrateInfo], cfg = "exec"),
        "_error_format": attr.label(default = Label("//rust/settings:error_format")),
        "_process_wrapper": attr.label(default = Label("//util/process_wrapper"), executable = True, cfg = "exec"),
    },
    fragments = ["cpp"],
    toolchains = [
        str(Label("//rust:toolchain_type")),
        config_common.toolchain_type("@bazel_tools//tools/cpp:toolchain_type", mandatory = False),
    ],
)

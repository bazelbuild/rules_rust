"""BoringSSL Utils"""

load("@rules_cc//cc:defs.bzl", "CcInfo")

def _get_static_libraries(cc_info, name):
    static_libraries = []
    for linker_input in cc_info.linking_context.linker_inputs.to_list():
        for library_to_link in linker_input.libraries:
            if not library_to_link.static_library:
                continue
            if not name in library_to_link.static_library.basename:
                continue
            static_libraries.append(library_to_link.static_library)

    if len(static_libraries) > 1:
        fail("Unexpected libraries: {}".format(static_libraries))

    if not static_libraries:
        for linker_input in cc_info.linking_context.linker_inputs.to_list():
            for library_to_link in linker_input.libraries:
                if not library_to_link.pic_static_library:
                    continue
                if not name in library_to_link.pic_static_library.basename:
                    continue
                static_libraries.append(library_to_link.pic_static_library)

    if len(static_libraries) != 1:
        fail("Unexpected libraries: {}".format(static_libraries))

    return static_libraries[0]

def _get_headers(cc_info):
    headers = cc_info.compilation_context.headers.to_list()
    return [h for h in headers if "/include/" in h.path]

def _boringssl_build_script_dir_impl(ctx):
    output = ctx.actions.declare_directory(ctx.attr.out)

    ssl = _get_static_libraries(ctx.attr.ssl[CcInfo], "ssl")
    crypto = _get_static_libraries(ctx.attr.crypto[CcInfo], "crypto")
    headers = depset(_get_headers(ctx.attr.ssl[CcInfo]) + _get_headers(ctx.attr.crypto[CcInfo]))

    inputs = depset([ssl, crypto], transitive = [headers])

    ctx.actions.run(
        executable = ctx.executable._maker,
        outputs = [output],
        inputs = inputs,
        env = {
            "ARG_CRYPTO": crypto.path,
            "ARG_HEADERS": " ".join([h.path for h in headers.to_list()]),
            "ARG_OUTPUT": output.path,
            "ARG_SSL": ssl.path,
        },
    )

    return [DefaultInfo(
        files = depset([output]),
        runfiles = ctx.runfiles([output]),
    )]

boringssl_build_script_dir = rule(
    doc = "A utility rule for building directories compatible with its `cargo_build_script` target.",
    implementation = _boringssl_build_script_dir_impl,
    attrs = {
        "crypto": attr.label(
            doc = "The `crypto`/`libcrypto` library.",
            providers = [CcInfo],
            allow_files = True,
            mandatory = True,
        ),
        "out": attr.string(
            doc = "The name of the output directory.",
            mandatory = True,
        ),
        "ssl": attr.label(
            doc = "The `ssl`/`libssl` library.",
            providers = [CcInfo],
            allow_files = True,
            mandatory = True,
        ),
        "_maker": attr.label(
            cfg = "exec",
            executable = True,
            default = Label("//complicated_dependencies:build_script_dir_maker"),
        ),
    },
)

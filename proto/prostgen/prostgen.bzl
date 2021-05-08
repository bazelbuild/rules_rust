"""
A set of rules and macros for generating prost-based rust protobuf code.
"""

load("@rules_proto//proto:defs.bzl", "ProtoInfo")
load("@rules_rust//rust:rust.bzl", "rust_library")

PROST_COMPILE_DEPS = [
    "@rules_rust//proto/prostgen/raze/cargo:prost",
    "@rules_rust//proto/prostgen/raze/cargo:prost_types",
]

PROST_COMPILE_PROC_MACRO_DEPS = [
    "@rules_rust//proto/prostgen/raze/cargo:prost_derive",
]

TONIC_COMPILE_DEPS = [
    "@rules_rust//proto/prostgen/raze/cargo:tonic",
]

# buildifier: disable=provider-params
ProstGenInfo = provider(
    fields = {
        "crate": "name of the crate that is used by the rust_library",
        "descriptor_set": "the file descriptor set for the target's sources",
        "transitive_proto_path": "depset containing all of the include paths " +
                                 "that need to be passed to protoc",
        "transitive_externs": "depset containing all of the extern targets " +
                              "that are passed to prostgen",
        "transitive_sources": "depset containing all of the proto files that " +
                              "must be accessed by protoc",
    },
)

def _external_flag(f):
    return ["--external=%s,%s" % (
        f[ProstGenInfo].crate,
        f[ProstGenInfo].descriptor_set.path,
    )]

def _prost_generator_impl(ctx):
    output_dir = ctx.actions.declare_directory(ctx.label.name)
    lib_rs = ctx.actions.declare_file("%s/lib.rs" % ctx.label.name)
    args = ctx.actions.args()

    direct_sources = depset(transitive = [
        depset(f[ProtoInfo].direct_sources)
        for f in ctx.attr.deps
    ])

    transitive_sources = depset(transitive = [
        f[ProstGenInfo].transitive_sources
        for f in ctx.attr.extern
    ] + [
        depset(f[ProtoInfo].transitive_sources)
        for f in ctx.attr.deps
    ])

    transitive_externs = depset(transitive = [depset(ctx.attr.extern)] + [
        f[ProstGenInfo].transitive_externs
        for f in ctx.attr.extern
    ])

    extern_descriptors = depset([
        f[ProstGenInfo].descriptor_set
        for f in transitive_externs.to_list()
    ])

    transitive_proto_path = depset(
        transitive = [
            f[ProstGenInfo].transitive_proto_path
            for f in ctx.attr.extern
        ] + [
            f[ProtoInfo].transitive_proto_path
            for f in ctx.attr.deps
        ],
    )

    args.add_all(direct_sources)
    args.add("--output=" + output_dir.path)
    if ctx.attr.grpc:
        args.add("--grpc")
    args.add_all(
        transitive_externs,
        map_each = _external_flag,
    )
    args.add_all(transitive_proto_path, format_each = "-I%s")

    rustfmt = ctx.toolchains["@rules_rust//rust:toolchain"].rustfmt
    ctx.actions.run(
        inputs = depset(
            transitive = [transitive_sources, extern_descriptors],
        ),
        env = {
            # Since tonic_build has logic to run rustfmt, and does so by default
            # for that matter, inject rustfmt into PATH, so that
            # std::process::Command can find it.  This seemed to be more clear
            # than setting up a separate bazel run action, and removes another
            # generated file.  A run action can't have the same input and
            # output file.  This is also compatible with prostgen currently
            # creating a lib.rs in the output directory, rather than taking in
            # an output directory and an output file.  The idea with only taking
            # in an output directory was to try and leave open the possibility
            # of using include! macros pointing towards the generated files.
            # This might make things a little easier to read, rather than being
            # extremely nested by package name.
            #
            # May not be perfect either, as the files are formatted before they
            # get indented to match their module nesting.
            "PATH": rustfmt.dirname,
            # We've patched rustfmt to expect that it can resolve the path to
            # protoc at runtime via this environment variable, rather than
            # expecting that this path was available at build time.
            "PROTOC": ctx.executable._protoc.path,
        },
        outputs = [output_dir, lib_rs],
        tools = [ctx.executable._generator, ctx.executable._protoc, rustfmt],
        progress_message = "Generating Rust protobuf stubs",
        mnemonic = "ProstSourceGeneration",
        executable = ctx.executable._generator,
        arguments = [args],
    )

    # Now go ahead and generate a file descriptor set.  prost_build already does
    # this, but, alas, it does not expose the requisite functionality to be able
    # to use this.
    #
    # See:
    #  * https://github.com/danburkert/prost/pull/155
    #  * https://github.com/danburkert/prost/pull/313
    #
    # This will let us pass along this full file descriptor set with the
    # associated source info with this generated target.  We use this for the
    # extern field.  In the future, if prost exposes this functionality we could
    # use this file directly.  And if bazel generated the source info with
    # proto_library (b/156677638), then we wouldn't need to invoke protoc at
    # all.
    file_descriptor_set = ctx.actions.declare_file(
        "%s-descriptor-set.proto.bin" % ctx.label.name,
    )
    protoc_args = ctx.actions.args()
    protoc_args.add("--include_source_info")
    protoc_args.add_all(direct_sources)
    protoc_args.add("-o")
    protoc_args.add(file_descriptor_set.path)
    protoc_args.add_all(transitive_proto_path, format_each = "-I%s")

    ctx.actions.run(
        inputs = depset(
            transitive = [transitive_sources],
        ),
        outputs = [file_descriptor_set],
        tools = [ctx.executable._protoc],
        progress_message = "Generating the prost file descriptor set",
        mnemonic = "ProstFileDescriptorSet",
        executable = ctx.executable._protoc,
        arguments = [protoc_args],
    )

    prostgen_info = ProstGenInfo(
        crate = ctx.attr.crate,
        descriptor_set = file_descriptor_set,
        transitive_proto_path = transitive_proto_path,
        transitive_sources = transitive_sources,
        transitive_externs = transitive_externs,
    )

    return [prostgen_info, DefaultInfo(files = depset([lib_rs]))]

_prost_generator = rule(
    _prost_generator_impl,
    attrs = {
        "crate": attr.string(
            mandatory = True,
        ),
        "deps": attr.label_list(
            doc = "List of proto_library dependencies that will be built.",
            mandatory = True,
            providers = [ProtoInfo],
        ),
        "extern": attr.label_list(
            doc = "",
        ),
        "grpc": attr.bool(
            doc = "Enables tonic service stub code generation",
        ),
        "_generator": attr.label(
            executable = True,
            cfg = "host",
            default = Label(
                "@rules_rust//proto/prostgen",
            ),
        ),
        "_protoc": attr.label(
            doc = "The location of the `protoc` binary. It should be an executable target.",
            executable = True,
            cfg = "host",
            default = "@com_google_protobuf//:protoc",
        ),
    },
    toolchains = [
        "@rules_rust//rust:toolchain",
    ],
    doc = """
Provides a wrapper around the generation of rust files.  The specification of
this as a rule allow the inspection of transitive descriptor sets of
proto_library.  This rule forms a wrapper around //proto/prostgen.  It generates
a single lib.rs file meant to be passed to a rust_library rule.
""",
)

def _prost_tonic_library(name, deps, grpc, extern = None, **kwargs):
    """A backing macro for tonic_library and prost_library.

    This allows for the selective enabling and disabling of grpc service
    generation since the prost_library and tonic_library macros share the same
    underlying prostgen binary
    """

    # Conslidating extern into deps would be ideal, however, it doesn't appear
    # that there would be a way to separate deps into things that should be
    # given to either prost_generator or rust_library.  It is possible to use an
    # aspect on _prost_generator's deps attr to change everything into a
    # ProstGenInfo provider, so if we were implementing this inside of rules
    # rust, or using rules_rust internals, then we could get rid of the need of
    # to separate them out, as we would just be using rustc_compile_action
    # instead.  See b/157488134 for more details.
    if not extern:
        extern = []
    generation_name = "%s_generated" % name
    generated_extern = ["%s_generated" % f for f in extern]
    dependencies = PROST_COMPILE_DEPS
    if grpc:
        dependencies = dependencies + TONIC_COMPILE_DEPS
    _prost_generator(
        name = generation_name,
        deps = deps,
        grpc = grpc,
        extern = generated_extern,
        # allow users to specify the crate name for the rust library.  This is
        # the default behavior of rules_rust.  The crate name is the library
        # name unless otherwise specified.
        crate = name if "crate" not in kwargs else kwargs["crate"],
        # The visibility of the two targets needs to match.
        visibility = kwargs.get("visibility"),
    )
    rust_library(
        name = name,
        srcs = [
            generation_name,
        ],
        deps = dependencies + extern,
        proc_macro_deps = PROST_COMPILE_PROC_MACRO_DEPS,
        edition = "2018",
        **kwargs
    )

def prost_library(**kwargs):
    """Create a rust protobuf library using prost as the backing library.

    This an alternative to the rust_proto_library.  It uses the //proto/prostgen
    executable to create a single lib.rs file from all proto_library targets
    passed in as dependencies.

    Since this is a macro, this will generate two targets: a rust_library, and a
    private _prost_generator rule target.  The rust_library will be given the
    name passed into this macro.  The generated file target will have
    "_generated" append to name.

    Keyword arguments:
    name -- The name given to the rust library on which you can depend
    deps -- A list of proto_library rules to uses as dependencies.
    extern -- A list of prost_library or tonic_library targets to depend on for
              their generated code.  Useful if a proto_library in deps depends
              on a proto_library that has a prost_library, so that definitions
              are shared.

    All other keyword arguments are passed to the generated rust_library.

    Example:

    proto_library(
        name = "foo_proto",
        src = ["foo.proto"],
    )
    prost_library(
        name = "foo_prost",
        deps = [":foo_proto"],
    )
    """
    _prost_tonic_library(grpc = False, **kwargs)

def tonic_library(**kwargs):
    """Create a rust gRPC library using prost and tonic.

    This an alternative to the rust_grpc_library.  It uses the //proto/prostgen
    executable to create a single lib.rs file from all proto_library targets
    passed in as dependencies.

    Since this is a macro, this will generate two targets: a rust_library, and a
    private _prost_generator rule target.  The rust_library will be given the
    name passed into this macro.  The generated file target will have
    "_generated" append to name.

    Keyword arguments:
    name -- The name given to the rust library on which you can depend
    deps -- A list of proto_library rules to uses as dependencies.
    extern -- A list of prost_library or tonic_library targets to depend on for
              their generated code.  Useful if a proto_library in deps depends
              on a proto_library that has a prost_library, so that definitions
              are shared.

    All other keyword arguments are passed to the generated rust_library.

    Example:

    proto_library(
        name = "foo_proto",
        src = ["foo.proto"],
    )
    tonic_library(
        name = "foo_prost",
        deps = [":foo_proto"],
    )
    """
    _prost_tonic_library(grpc = True, **kwargs)

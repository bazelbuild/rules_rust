# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Toolchain for compiling rust stubs from protobuf and gRPC."""

def generated_file_stem(f):
    basename = f.rsplit("/", 2)[-1]
    basename = basename.replace("-", "_")
    return basename.rsplit(".", 2)[0]

def rust_generate_proto(
        ctx,
        transitive_descriptor_sets,
        protos,
        imports,
        output_dir,
        proto_toolchain,
        grpc = False):
    """Generate a proto compilation action.

    Args:
      ctx: rule context.
      transitive_descriptor_sets: descriptor generated by previous protobuf
        libraries.
      protos: list of paths of protos to compile.
      output_dir: directory, relative to the package, to output the list of
        stubs.
      proto_toolchain: the toolchain for rust-proto compilation.
      grpc: generate gRPC stubs.

    Returns: the list of generate stubs ([File])
    """
    tools = [
        proto_toolchain.protoc,
        proto_toolchain.proto_plugin,
    ]
    executable = proto_toolchain.protoc
    args = ctx.actions.args()

    if not protos:
        fail("Protobuf compilation requested without inputs!")
    paths = ["%s/%s" % (output_dir, generated_file_stem(i)) for i in protos.to_list()]
    outs = [ctx.actions.declare_file(path + ".rs") for path in paths]
    output_directory = outs[0].dirname

    if grpc:
        # Add grpc stubs to the list of outputs
        grpc_files = [ctx.actions.declare_file(path + "_grpc.rs") for path in paths]
        outs.extend(grpc_files)

        # gRPC stubs is generated only if a service is defined in the proto,
        # so we create an empty grpc module in the other case.
        tools.append(proto_toolchain.grpc_plugin)
        tools.append(ctx.executable._optional_output_wrapper)
        args.add_all([f.path for f in grpc_files])
        args.add_all([
            "--",
            proto_toolchain.protoc.path,
            "--plugin=protoc-gen-grpc-rust=" + proto_toolchain.grpc_plugin.path,
            "--grpc-rust_out=" + output_directory,
        ])
        executable = ctx.executable._optional_output_wrapper

    args.add_all([
        "--plugin=protoc-gen-rust=" + proto_toolchain.proto_plugin.path,
        "--rust_out=" + output_directory,
    ])

    args.add_joined(
        transitive_descriptor_sets,
        join_with = ":",
        format_joined = "--descriptor_set_in=%s",
    )

    args.add_all(protos)
    ctx.actions.run(
        inputs = depset(
            transitive = [
                transitive_descriptor_sets,
                imports,
            ],
        ),
        outputs = outs,
        tools = tools,
        progress_message = "Generating Rust protobuf stubs",
        mnemonic = "RustProtocGen",
        executable = executable,
        arguments = [args],
    )
    return outs

def _rust_proto_toolchain_impl(ctx):
    return platform_common.ToolchainInfo(
        protoc = ctx.executable.protoc,
        proto_plugin = ctx.file.proto_plugin,
        grpc_plugin = ctx.file.grpc_plugin,
        edition = ctx.attr.edition,
    )

PROTO_COMPILE_DEPS = [
    "@io_bazel_rules_rust//proto/raze:protobuf",
]
"""Default dependencies needed to compile protobuf stubs."""

GRPC_COMPILE_DEPS = PROTO_COMPILE_DEPS + [
    "@io_bazel_rules_rust//proto/raze:grpc",
    "@io_bazel_rules_rust//proto/raze:tls_api",
    "@io_bazel_rules_rust//proto/raze:tls_api_stub",
]
"""Default dependencies needed to compile gRPC stubs."""

# TODO(damienmg): Once bazelbuild/bazel#6889 is fixed, reintroduce
# proto_compile_deps and grpc_compile_deps and remove them from the
# rust_proto_library and grpc_proto_library.
rust_proto_toolchain = rule(
    _rust_proto_toolchain_impl,
    attrs = {
        "protoc": attr.label(
            doc = "The location of the `protoc` binary. It should be an executable target.",
            executable = True,
            cfg = "host",
            default = Label("@com_google_protobuf//:protoc"),
        ),
        "proto_plugin": attr.label(
            doc = "The location of the Rust protobuf compiler plugin used to generate rust sources.",
            allow_single_file = True,
            cfg = "host",
            default = Label(
                "@io_bazel_rules_rust//proto:protoc_gen_rust",
            ),
        ),
        "grpc_plugin": attr.label(
            doc = "The location of the Rust protobuf compiler plugin to generate rust gRPC stubs.",
            allow_single_file = True,
            cfg = "host",
            default = Label(
                "@io_bazel_rules_rust//proto:protoc_gen_rust_grpc",
            ),
        ),
        "edition": attr.string(
            doc = "The edition used by the generated rust source.",
            default = "2015",
        ),
    },
    doc =
        """
Declares a Rust Proto toolchain for use.

This is used to configure proto compilation and can be used to set different
protobuf compiler plugin.

Example:

Suppose a new nicer gRPC plugin has came out. The new plugin can be
used in Bazel by defining a new toolchain definition and declaration:

```python
load('@io_bazel_rules_rust//proto:toolchain.bzl', 'rust_proto_toolchain')

rust_proto_toolchain(
   name="rust_proto_impl",
   grpc_plugin="@rust_grpc//:grpc_plugin",
   grpc_compile_deps=["@rust_grpc//:grpc_deps"],
)

toolchain(
    name="rust_proto",
    exec_compatible_with = [
        "@platforms//cpu:cpuX",
    ],
    target_compatible_with = [
        "@platforms//cpu:cpuX",
    ],
    toolchain = ":rust_proto_impl",
)
```

Then, either add the label of the toolchain rule to register_toolchains in the WORKSPACE, or pass
it to the "--extra_toolchains" flag for Bazel, and it will be used.

See @io_bazel_rules_rust//proto:BUILD for examples of defining the toolchain.
""",
)

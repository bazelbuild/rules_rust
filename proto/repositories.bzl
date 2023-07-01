"""Dependencies for Rust proto rules"""

load(
    "//proto/protobuf:repositories.bzl",
    "rust_proto_protobuf_dependencies",
    "rust_proto_protobuf_register_toolchains",
)

def rust_proto_dependencies():
    """Load rust_protobuf dependencies.

    Deprecated:
        Instead call `@rules_rust//proto/protobuf:repositories.bzl%rust_protobuf_dependencies`
    """
    rust_proto_protobuf_dependencies()

# buildifier: disable=unnamed-macro
def rust_proto_register_toolchains(register_default_toolchain = True):
    """Register rust_protobuf toolchains.

    Deprecated:
        Instead call `@rules_rust//proto/protobuf:repositories.bzl%rust_protobuf_register_toolchains`

    Args:
        register_default_toolchain (bool, optional): _description_. If True, the default toolchain is registered.
    """
    rust_proto_protobuf_register_toolchains(register_default_toolchain)

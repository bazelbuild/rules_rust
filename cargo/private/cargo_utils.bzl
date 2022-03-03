"""Utility functions for the cargo rules"""

load("//rust/platform:triple_mappings.bzl", "system_to_binary_ext")

def _resolve_repository_template(
        template,
        abi = None,
        arch = None,
        extension = None,
        system = None,
        tool = None,
        triple = None,
        vendor = None,
        version = None):
    """Render values into a repository template string

    Args:
        template (str): The template to use for rendering
        abi (str, optional): The host ABI
        arch (str, optional): The host CPU architecture
        extension (str, optional): The extension of executables for the host
        system (str, optional): The host system name
        tool (str, optional): The tool to expect in the particular repository.
            Eg. `cargo`, `rustc`, `stdlib`.
        triple (str, optional): The host triple
        vendor (str, optional): The host vendor name
        version (str, optional): The Rust version used in the toolchain.
    Returns:
        string: The resolved template string based on the given parameters
    """
    if abi != None:
        template = template.replace("{abi}", abi)

    if arch != None:
        template = template.replace("{arch}", arch)

    if extension != None:
        template = template.replace("{ext}", extension)

    if system != None:
        template = template.replace("{system}", system)

    if tool != None:
        template = template.replace("{tool}", tool)

    if triple != None:
        template = template.replace("{triple}", triple)

    if vendor != None:
        template = template.replace("{vendor}", vendor)

    if version != None:
        template = template.replace("{version}", version)

    return template

def sysroot_pair(anchor, path):
    """A constructor for producing a struct capable of locating a Rust sysroot

    Args:
        anchor (Label): The label of a file in a workspace that contains a Rust sysroot
        path (str): The relative path from the directory of `anchor` to the sysroot

    Returns:
        struct: A struct used to locate Rust sysroots
    """
    return struct(
        anchor = anchor,
        path = path,
    )

def resolve_sysroot_path(repository_ctx, sysroot_pair):
    """Parse a `sysroot_pair` to produce the path to a Rust sysroot

    Args:
        repository_ctx (repository_ctx): The rule's context object.
        sysroot_pair (struct): See the `sysroot_pair` macro.

    Returns:
        str: The value of `rustc --sysroot`
    """
    anchor = repository_ctx.path(sysroot_pair.anchor).dirname

    path = ""
    for part in sysroot_pair.path.split("/"):
        if part == "..":
            # Sanity check
            if path:
                fail("`../` can only exist at the beginning of the path. Please normalize")
            anchor = anchor.dirname
        else:
            path += "/{}".format(part)

    return "{}{}".format(anchor, path)

def get_rust_tools(cargo_template, rustc_template, sysroot_anchor_template, sysroot_path, host_triple, version):
    """Retrieve `cargo` and `rustc` labels based on the host triple.

    Args:
        cargo_template (str): A template used to identify the label of the host `cargo` binary.
        rustc_template (str): A template used to identify the label of the host `rustc` binary.
        sysroot_anchor_template (str): A template used to identify the label of a file relative to the sysroot.
        sysroot_path (str): The path relative to the directory of `sysroot_anchor_template` where the sysroot
            is located.
        host_triple (struct): The host's triple. See `@rules_rust//rust/platform:triple.bzl`.
        version (str): The version of Cargo+Rustc to use.

    Returns:
        struct: A struct containing the labels of expected tools
    """
    extension = system_to_binary_ext(host_triple.system)

    cargo_label = Label(_resolve_repository_template(
        template = cargo_template,
        version = version,
        triple = host_triple.str,
        arch = host_triple.arch,
        vendor = host_triple.vendor,
        system = host_triple.system,
        abi = host_triple.abi,
        tool = "cargo",
        extension = extension,
    ))

    rustc_label = Label(_resolve_repository_template(
        template = rustc_template,
        version = version,
        triple = host_triple.str,
        arch = host_triple.arch,
        vendor = host_triple.vendor,
        system = host_triple.system,
        abi = host_triple.abi,
        tool = "rustc",
        extension = extension,
    ))

    sysroot_label = Label(_resolve_repository_template(
        template = sysroot_anchor_template,
        version = version,
        triple = host_triple.str,
        arch = host_triple.arch,
        vendor = host_triple.vendor,
        system = host_triple.system,
        abi = host_triple.abi,
        tool = "rust-std",
    ))

    return struct(
        cargo = cargo_label,
        rustc = rustc_label,
        sysroot = sysroot_pair(
            anchor = sysroot_label,
            path = sysroot_path,
        ),
    )

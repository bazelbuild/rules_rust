"""Utility functions for the cargo rules"""

load("//rust/platform:triple.bzl", "triple")
load("//rust/platform:triple_mappings.bzl", "system_to_binary_ext")

_CPU_ARCH_ERROR_MSG = """\
Command failed with exit code '{code}': {args}
----------stdout:
{stdout}
----------stderr:
{stderr}
"""

def _query_cpu_architecture(repository_ctx, expected_archs, is_windows = False):
    """Detect the host CPU architecture

    Args:
        repository_ctx (repository_ctx): The repository rule's context object
        expected_archs (list): A list of expected architecture strings
        is_windows (bool, optional): If true, the cpu lookup will use the windows method (`wmic` vs `uname`)

    Returns:
        str: The host's CPU architecture
    """
    if is_windows:
        arguments = ["wmic", "os", "get", "osarchitecture"]
    else:
        arguments = ["uname", "-m"]

    result = repository_ctx.execute(arguments)

    if result.return_code:
        fail(_CPU_ARCH_ERROR_MSG.format(
            code = result.return_code,
            args = arguments,
            stdout = result.stdout,
            stderr = result.stderr,
        ))

    if is_windows:
        # Example output:
        # OSArchitecture
        # 64-bit
        lines = result.stdout.split("\n")
        arch = lines[1].strip()

        # Translate 64-bit to a compatible rust platform
        # https://doc.rust-lang.org/nightly/rustc/platform-support.html
        if arch == "64-bit":
            arch = "x86_64"
    else:
        arch = result.stdout.strip("\n")

        # Correct the arm architecture for macos
        if "mac" in repository_ctx.os.name and arch == "arm64":
            arch = "aarch64"

    if not arch in expected_archs:
        fail("{} is not a expected cpu architecture {}\n{}".format(
            arch,
            expected_archs,
            result.stdout,
        ))

    return arch

def get_host_triple(repository_ctx, abi = None):
    """Query host information for the appropriate triples for the crate_universe resolver

    Args:
        repository_ctx (repository_ctx): The rule's repository_ctx
        abi (str): Since there's no consistent way to check for ABI, this info
            may be explicitly provided

    Returns:
        struct: A triple struct, see `@rules_rust//rust/platform:triple.bzl`
    """

    # Detect the host's cpu architecture

    supported_architectures = {
        "linux": ["aarch64", "x86_64"],
        "macos": ["aarch64", "x86_64"],
        "windows": ["x86_64"],
    }

    if "linux" in repository_ctx.os.name:
        cpu = _query_cpu_architecture(repository_ctx, supported_architectures["linux"])
        return triple("{}-unknown-linux-{}".format(
            cpu,
            abi or "gnu",
        ))

    if "mac" in repository_ctx.os.name:
        cpu = _query_cpu_architecture(repository_ctx, supported_architectures["macos"])
        return triple("{}-apple-darwin".format(cpu))

    if "win" in repository_ctx.os.name:
        cpu = _query_cpu_architecture(repository_ctx, supported_architectures["windows"], True)
        return triple("{}-pc-windows-{}".format(
            cpu,
            abi or "msvc",
        ))

    fail("Unhandled host os: {}", repository_ctx.os.name)

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
        triple = host_triple.triple,
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
        triple = host_triple.triple,
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
        triple = host_triple.triple,
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

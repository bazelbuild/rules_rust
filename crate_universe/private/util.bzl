"""Utility functions for the crate_universe resolver"""

load(
    "//rust/platform:triple_mappings.bzl",
    "system_to_binary_ext",
    "triple_to_arch",
    "triple_to_system",
)

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

def get_host_triple(repository_ctx):
    """Query host information for the appropriate triples for the crate_universe resolver

    Args:
        repository_ctx (repository_ctx): The rule's repository_ctx

    Returns:
        tuple: The host triple and resolver triple
    """

    # Detect the host's cpu architecture

    supported_architectures = {
        "linux": ["aarch64", "x86_64"],
        "macos": ["aarch64", "x86_64"],
        "windows": ["x86_64"],
    }

    if "linux" in repository_ctx.os.name:
        cpu = _query_cpu_architecture(repository_ctx, supported_architectures["linux"])
        host_triple = "{}-unknown-linux-gnu".format(cpu)
        resolver_triple = "{}-unknown-linux-gnu".format(cpu)
    elif "mac" in repository_ctx.os.name:
        cpu = _query_cpu_architecture(repository_ctx, supported_architectures["macos"])
        host_triple = "{}-apple-darwin".format(cpu)
        resolver_triple = "{}-apple-darwin".format(cpu)
    elif "win" in repository_ctx.os.name:
        cpu = _query_cpu_architecture(repository_ctx, supported_architectures["windows"], True)

        # TODO: The resolver triple should be the same as the host but for the time being,
        # the resolver is compiled with `-gnu` not `-msvc`.
        host_triple = "{}-pc-windows-msvc".format(cpu)
        resolver_triple = "{}-pc-windows-gnu".format(cpu)
    else:
        fail("Could not locate resolver for OS " + repository_ctx.os.name)

    return (host_triple, resolver_triple)

def get_cargo_and_rustc(repository_ctx, host_triple):
    """Retrieve a cargo and rustc binary based on the host triple.

    Args:
        repository_ctx (repository_ctx): The rule's context object
        host_triple (str): The host's platform triple

    Returns:
        struct: A struct containing the expected tools
    """

    if repository_ctx.attr.version in ("beta", "nightly"):
        version_str = "{}-{}".format(repository_ctx.attr.version, repository_ctx.attr.iso_date)
    else:
        version_str = repository_ctx.attr.version

    # Get info about the current host's tool locations
    (host_triple, resolver_triple) = get_host_triple(repository_ctx)
    system = triple_to_system(host_triple)
    extension = system_to_binary_ext(system)
    arch = triple_to_arch(host_triple)

    rust_toolchain_repository = repository_ctx.attr.rust_toolchain_repository_template
    rust_toolchain_repository = rust_toolchain_repository.replace("{version}", version_str)
    rust_toolchain_repository = rust_toolchain_repository.replace("{system}", system)
    rust_toolchain_repository = rust_toolchain_repository.replace("{triple}", host_triple)
    rust_toolchain_repository = rust_toolchain_repository.replace("{arch}", arch)

    cargo_path = repository_ctx.path(Label("@{}{}".format(rust_toolchain_repository, "//:bin/cargo" + extension)))
    rustc_path = repository_ctx.path(Label("@{}{}".format(rust_toolchain_repository, "//:bin/rustc" + extension)))

    return struct(
        cargo = cargo_path,
        rustc = rustc_path,
    )

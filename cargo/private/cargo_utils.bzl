"""Utility functions for the cargo rules"""

load("//rust/platform:triple.bzl", "triple")
load(
    "//rust/platform:triple_mappings.bzl",
    "system_to_binary_ext",
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

def get_cargo_and_rustc(repository_ctx, toolchain_repository_template, host_triple, version):
    """Retrieve a cargo and rustc binary based on the host triple.

    Args:
        repository_ctx (repository_ctx): The rule's context object
        toolchain_repository_template (str): A template used to identify the host `rust_toolchain_repository`.
        host_triple (struct): The host's triple. See `@rules_rust//rust/platform:triple.bzl`.
        version (str): The version of Cargo+Rustc to use.

    Returns:
        struct: A struct containing the expected tools
    """

    rust_toolchain_repository = toolchain_repository_template
    rust_toolchain_repository = rust_toolchain_repository.replace("{version}", version)
    rust_toolchain_repository = rust_toolchain_repository.replace("{triple}", host_triple.triple)

    if host_triple.arch:
        rust_toolchain_repository = rust_toolchain_repository.replace("{arch}", host_triple.arch)

    if host_triple.vendor:
        rust_toolchain_repository = rust_toolchain_repository.replace("{vendor}", host_triple.vendor)

    if host_triple.system:
        rust_toolchain_repository = rust_toolchain_repository.replace("{system}", host_triple.system)

    if host_triple.abi:
        rust_toolchain_repository = rust_toolchain_repository.replace("{abi}", host_triple.abi)

    extension = system_to_binary_ext(host_triple.system)

    cargo_path = repository_ctx.path(Label("@{}{}".format(rust_toolchain_repository, "//:bin/cargo" + extension)))
    rustc_path = repository_ctx.path(Label("@{}{}".format(rust_toolchain_repository, "//:bin/rustc" + extension)))

    return struct(
        cargo = cargo_path,
        rustc = rustc_path,
    )

"""Triples are a way to define information about a platform/system. This module provides
a way to convert a triple string into a well structured object to avoid constant string
parsing in starlark code, and a way for a repository_rule to extract the target triple
of the host platform.

Triples can be described at the following link:
https://clang.llvm.org/docs/CrossCompilation.html#target-triple
"""

def triple(triple):
    """Constructs a struct containing each component of the provided triple

    Args:
        triple (str): A platform triple. eg: `x86_64-unknown-linux-gnu`

    Returns:
        struct:
            - arch (str): The triple's CPU architecture
            - vendor (str): The vendor of the system
            - system (str): The name of the system
            - abi (str, optional): The abi to use or None if abi does not apply.
            - str (str): Original string representation of the triple
    """
    if triple == "wasm32-wasi":
        return struct(
            arch = "wasm32",
            system = "wasi",
            vendor = "wasi",
            abi = None,
            str = triple,
        )
    elif triple in ("aarch64-fuchsia", "x86_64-fuchsia"):
        return struct(
            arch = triple.split("-")[0],
            system = "fuchsia",
            vendor = "fuchsia",
            abi = None,
            str = triple,
        )

    component_parts = triple.split("-")
    if len(component_parts) < 3:
        fail("Expected target triple to contain at least three sections separated by '-'")

    cpu_arch = component_parts[0]
    vendor = component_parts[1]
    system = component_parts[2]
    abi = None

    if cpu_arch.startswith(("thumbv8m", "thumbv7m", "thumbv7e", "thumbv6m")):
        abi = system
        system = vendor
        vendor = None

    if system == "androideabi":
        system = "android"
        abi = "eabi"

    if len(component_parts) == 4:
        abi = component_parts[3]

    return struct(
        arch = cpu_arch,
        vendor = vendor,
        system = system,
        abi = abi,
        str = triple,
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
        repository_ctx (repository_ctx): The repository_rule's context object
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
        #
        # In some cases windows can return the same but with an uppercase b
        # OSArchitecture
        # 64-Bit
        lines = result.stdout.split("\n")
        arch = lines[1].strip().lower()

        # Translate 64-bit to a compatible rust platform
        # https://doc.rust-lang.org/nightly/rustc/platform-support.html
        if arch.startswith("arm 64-bit"):
            arch = "aarch64"
        elif arch == "64-bit":
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
    """Query host information for the appropriate triple to use with load_arbitrary_tool or the crate_universe resolver

    Example:

    ```python
    load("@rules_rust//rust:repositories.bzl", "load_arbitrary_tool")
    load("@rules_rust//rust/platform:triple.bzl", "get_host_triple")

    def _impl(repository_ctx):
        host_triple = get_host_triple(repository_ctx)

        load_arbitrary_tool(
            ctx = repository_ctx,
            tool_name = "cargo",
            tool_subdirectories = ["cargo"],
            target_triple = host_triple.str,
        )

    example = repository_rule(implementation = _impl)
    ```

    Args:
        repository_ctx (repository_ctx): The repository_rule's context object
        abi (str): Since there's no consistent way to check for ABI, this info
            may be explicitly provided

    Returns:
        struct: A triple struct; see the `triple` function in this module
    """

    # Detect the host's cpu architecture

    supported_architectures = {
        "linux": ["aarch64", "x86_64"],
        "macos": ["aarch64", "x86_64"],
        "windows": ["aarch64", "x86_64"],
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

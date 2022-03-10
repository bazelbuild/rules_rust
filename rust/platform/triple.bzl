"""Triples are a way to define information about a platform/system. This module provides
a way to convert a triple string into a well structured object to avoid constant string
parsing in starlark code.

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
            - triple (str): The original triple
    """
    if triple == "wasm32-wasi":
        return struct(
            arch = "wasm32",
            system = "wasi",
            vendor = "wasi",
            abi = None,
            triple = triple,
        )

    component_parts = triple.split("-")
    if len(component_parts) < 3:
        fail("Expected target triple to contain at least three sections separated by '-'")

    cpu_arch = component_parts[0]
    vendor = component_parts[1]
    system = component_parts[2]
    abi = None

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
        triple = triple,
    )

"""Parser for rust-toolchain.toml files."""

def normalize_toml_multiline_arrays(content):
    """Normalize multi-line TOML arrays to single-line for simpler parsing.

    Handles arrays like:
        targets = [
          "wasm32-unknown-unknown",
          "x86_64-unknown-linux-gnu",
        ]

    Args:
        content: The raw TOML file content.

    Returns:
        Content with multi-line arrays collapsed to single lines.
    """
    result = []
    in_array = False
    array_buffer = ""

    for line in content.split("\n"):
        stripped = line.strip()

        # Preserve comments and empty lines outside arrays
        if not stripped or stripped.startswith("#"):
            if not in_array:
                result.append(line)
            continue

        if in_array:
            array_buffer += " " + stripped
            if "]" in stripped:
                in_array = False
                result.append(array_buffer)
                array_buffer = ""
        elif "= [" in stripped and "]" not in stripped:
            # Start of multi-line array
            in_array = True
            array_buffer = stripped
        else:
            result.append(line)

    return "\n".join(result)

def parse_toml_string(line):
    """Parse a TOML string value: key = "value" -> value

    Args:
        line: A line containing a TOML key-value pair.

    Returns:
        The parsed string value, or None if parsing fails.
    """
    parts = line.split("=", 1)
    if len(parts) == 2:
        return parts[1].strip().strip("\"'")
    return None

def parse_toml_list(line):
    """Parse a TOML list value: key = ["a", "b"] -> ["a", "b"]

    Args:
        line: A line containing a TOML key-value pair with a list value.

    Returns:
        The parsed list of strings, or an empty list if parsing fails.
    """
    parts = line.split("=", 1)
    if len(parts) == 2:
        list_str = parts[1].strip()
        if list_str.startswith("[") and list_str.endswith("]"):
            items = list_str[1:-1].split(",")
            return [item.strip().strip("\"'") for item in items if item.strip().strip("\"'")]
    return []

def parse_rust_toolchain_file(content):
    """Parse rust-toolchain.toml content and extract toolchain configuration.

    Supports:
    - channel: The toolchain version (e.g., "1.92.0", "nightly-2024-01-01")
    - targets: Additional target triples to install
    - components: Additional components (sets dev_components=True if "rustc-dev" present)

    Both single-line and multi-line TOML arrays are supported.

    Args:
        content: The content of the rust-toolchain.toml file.

    Returns:
        A struct with versions, extra_target_triples, and dev_components fields,
        or None if parsing fails completely.
    """

    # Normalize multi-line arrays first
    content = normalize_toml_multiline_arrays(content)

    versions = None
    extra_target_triples = []
    dev_components = False

    for line in content.split("\n"):
        line = line.strip()

        # Skip empty lines, comments, and section headers
        if not line or line.startswith("#") or line.startswith("["):
            continue

        if line.startswith("channel"):
            version = parse_toml_string(line)
            if version:
                versions = [version]

        elif line.startswith("targets"):
            targets = parse_toml_list(line)
            if targets:
                extra_target_triples = targets

        elif line.startswith("components"):
            components = parse_toml_list(line)
            if "rustc-dev" in components:
                dev_components = True

    # If no channel was found, try simple format (just version string)
    if not versions:
        for line in content.split("\n"):
            line = line.strip()
            if line and not line.startswith("#") and not line.startswith("[") and "=" not in line:
                versions = [line]
                break

    if not versions:
        return None

    return struct(
        versions = versions,
        extra_target_triples = extra_target_triples,
        dev_components = dev_components,
    )

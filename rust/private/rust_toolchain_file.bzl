"""Reads the `rust-toolchain.toml` file that rustup and cargo read."""

load("@toml.bzl", "toml")

def parse_rust_toolchain_file(content):
    """Turns a `rust-toolchain.toml` file into `rust.toolchain` settings.

    Only what rules_rust can act on without rustup is read: `channel` must name
    an exact release (`1.85.0`, `nightly-2025-01-01`, `beta-2025-01-01`),
    because resolving `stable` or `1.85` to a release is something rustup does
    with the network. `targets` adds to `extra_target_triples`, and
    `components` enables `dev_components` if it lists `rustc-dev`.

    Args:
        content (str): The contents of a `rust-toolchain.toml` file.

    Returns:
        struct: With `versions`, `extra_target_triples` and `dev_components`
            fields, in the shape the `rust.toolchain` tag takes.
    """
    toolchain = toml.decode(content).get("toolchain", {})
    channel = toolchain.get("channel")
    if not channel:
        fail("rust-toolchain.toml has no `channel` in its `[toolchain]` table")

    if channel.startswith("nightly-") or channel.startswith("beta-"):
        name, iso_date = channel.split("-", 1)
        version = "{}/{}".format(name, iso_date)
    elif channel[0].isdigit() and channel.count(".") == 2:
        version = channel
    else:
        fail((
            "rust-toolchain.toml channel `{}` is not an exact release: rules_rust " +
            "downloads a fixed release, so the channel must be a full version " +
            "(`1.85.0`) or a dated nightly or beta (`nightly-2025-01-01`)"
        ).format(channel))

    return struct(
        versions = [version],
        extra_target_triples = toolchain.get("targets", []),
        dev_components = "rustc-dev" in toolchain.get("components", []),
    )

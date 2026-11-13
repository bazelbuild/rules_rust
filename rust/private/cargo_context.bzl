"""Preserve the originating Cargo target when compiling execution dependencies."""

CARGO_TARGET = str(Label("//cargo/settings:cargo_target_triple"))
CARGO_INPUTS = [CARGO_TARGET, "//command_line_option:is exec configuration"]

def cargo_context(settings, attr):
    """Preserve a Cargo target marker, or canonicalize its execution context.

    Args:
        settings: Incoming transition settings, including CARGO_INPUTS.
        attr: Rule attributes with an optional execution-context equivalence map.

    Returns:
        The Cargo target setting, unchanged when unset or in a target configuration.
    """
    original = settings[CARGO_TARGET]
    if original and settings["//command_line_option:is exec configuration"]:
        original = original.removeprefix("target/")
        original = attr.cargo_target_triple_map.get(original, original)
    return {CARGO_TARGET: original}

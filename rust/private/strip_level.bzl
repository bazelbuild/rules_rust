"""Helpers for looking up strip levels."""

def build_strip_levels(*, strip_level_selects, default_strip_level, triples):
    """Look up the per-triple `strip_level` with defaults.

    Args:
        strip_level_selects (list): The `strip_level_select` tags, each with a
            `triples` list and specified strip levels.
        default_strip_level (dict): The fallback strip levels.
        triples (list): The target triples toolchains are being registered for.
            Must not be empty.

    Returns:
        dict: Mapping of target triple to strip levels (compilation mode to
            level).
    """
    if not triples:
        fail("`triples` must not be empty.")

    levels_by_triple = {}  # { "x86_64-darwin" : { "dbg" = ...} }
    for select in strip_level_selects:
        # a select fully defines the strip level for each mode
        levels = {
            "dbg": select.dbg,
            "fastbuild": select.fastbuild,
            "opt": select.opt,
        }

        # insert all of this select's triples
        for triple in select.triples:
            # error out if triple is selected multiple times
            if triple in levels_by_triple:
                fail("Triple `{}` is configured by more than one `strip_level_select` tag.".format(triple))
            levels_by_triple[triple] = levels

    strip_level = {}
    for triple in triples:
        if triple in levels_by_triple:
            strip_level[triple] = levels_by_triple[triple]
        elif default_strip_level:
            strip_level[triple] = default_strip_level

    # Honor selects for triples that aren't part of the default triple set.
    for triple, levels in levels_by_triple.items():
        strip_level.setdefault(triple, levels)

    return strip_level

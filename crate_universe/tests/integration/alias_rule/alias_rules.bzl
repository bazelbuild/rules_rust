"""Wrapper around `native.alias()` to test supplying a custom `alias_rule`."""

def alias_rule(name, actual, tags):
    native.alias(
        name = name,
        actual = actual,
        tags = tags,
    )

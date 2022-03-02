"""A helper module solving for complex select statements in rendered cargo-bazel modules"""

def select_with_or(input_dict, no_match_error = ""):
    """Drop-in replacement for `select()` that supports ORed keys.

    This is notably different from [@bazel_skylib//lib:selects.bzl%selects.with_or][swo] in that
    the input dict must have a list as it's values and they keys will continue to expand for each
    entry instead of failing on duplicates.

    Example:
    ```starlark
    deps = selects.with_or({
        "//configs:one": [":dep1"],
        ("//configs:two", "//configs:three"): [":dep2or3"],
        "//configs:four": [":dep4"],
        "//conditions:default": [":default"]
    })
    ```
    Key labels may appear at most once anywhere in the input.

    This macro eturns a native `select` that expands `("//configs:two", "//configs:three"): [":dep2or3"]` to
    ```starlark
    "//configs:two": [":dep2or3"],
    "//configs:three": [":dep2or3"],
    ```

    [swo]: https://github.com/bazelbuild/bazel-skylib/blob/1.1.1/docs/selects_doc.md#selectswith_or

    Args:
        input_dict: The same dictionary `select()` takes, except keys may take
            either the usual form `"//foo:config1"` or
            `("//foo:config1", "//foo:config2", ...)` to signify
            `//foo:config1` OR `//foo:config2` OR `...`.
        no_match_error: Optional custom error to report if no condition matches.

    Returns:
        A native `select()`
    """
    output_dict = {}
    for (key, value) in input_dict.items():
        if type(key) == type(()):
            for config_setting in key:
                if config_setting in output_dict:
                    output_dict[config_setting].extend(value)
                else:
                    output_dict[config_setting] = list(value)
        elif key in output_dict:
            output_dict[key].extend(value)
        else:
            output_dict[key] = list(value)

    # return a dict with deduped lists
    return select(
        {key: depset(value).to_list() for key, value in output_dict.items()},
        no_match_error = no_match_error,
    )

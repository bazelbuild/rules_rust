"""Function for preserving `select` entries for Cargo cfg expressions which did
not match any enabled target triple / Bazel platform.

For example we might generate:

    rust_library(
        ...
        deps = [
            "//common:unconditional_dep",
        ] + selects.with_unmapped({
            "@rules_rust//rust/platform:x86_64-pc-windows-msvc": [
                "//third-party/rust:windows-sys",  # cfg(windows)
            ],
            "@rules_rust//rust/platform:x86_64-unknown-linux-gnu": [
                "//third-party/rust:libc",  # cfg(any(unix, target_os = "wasi"))
            ],
            "//conditions:default": [],
            selects.NO_MATCHING_PLATFORM_TRIPLES: [
                "//third-party/rust:hermit-abi",  # cfg(target_os = "hermit")
            ],
        })
    )
"""

_SENTINEL = struct()

def _with_unmapped(configurations):
    configurations.pop(_SENTINEL)
    return select(configurations)

selects = struct(
    with_unmapped = _with_unmapped,
    NO_MATCHING_PLATFORM_TRIPLES = _SENTINEL,
)

# TODO: No longer used by the serde_starlark-based renderer. Delete after all
# BUILD files using it have been regenerated.
#
# buildifier: disable=function-docstring
def select_with_or(input_dict, no_match_error = ""):
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

"""cargo_build_info wrapper that only exists until the min supported version
of Bazel includes https://github.com/bazelbuild/bazel/issues/7989
"""

load(":cargo_build_info.bzl", _cargo_build_info = "cargo_build_info")

def cargo_build_info(
        name,
        out_dir_files = {},
        cc_lib = None,
        rustc_flags = None,
        rustc_env = None,
        dep_env = None,
        links = "",
        **kwargs):
    """Packages files into an `OUT_DIR` and returns a `BuildInfo` provider.

    This is a generic build-script replacement for `-sys` crates. It places
    arbitrary files into an `OUT_DIR` directory, optionally propagates `CcInfo`
    from a `cc_library`, and returns `BuildInfo` so the crate's `lib.rs` can
    use `include!(concat!(env!("OUT_DIR"), "/..."))` unchanged.

    Use with `override_target_build_script` in crate annotations:

    ```python
    crate.annotation(
        crate = "my-native-sys",
        override_target_build_script = "//path:my_sys_bs",
    )
    ```

    Args:
        name: Unique name for this target.
        out_dir_files: Dict mapping destination filenames (within `OUT_DIR`) to
            source file labels. A single label can appear as multiple destinations.
            Example: `{"bindings.rs": ":my_bindgen", "config.h": ":my_header"}`
        cc_lib: Optional `cc_library` label for `CcInfo` propagation (link flags,
            search paths). The library's static archives are added as link dependencies.
        rustc_flags: Extra flags to pass to rustc.
        rustc_env: Extra environment variables for rustc.
        dep_env: Environment variables exported to dependent build scripts.
            Auto-prefixed with `DEP_{LINKS}_` when `links` is set.
        links: Cargo `links` field value, used to prefix `dep_env` keys.
        **kwargs: Common attributes forwarded to the underlying rule
            (`visibility`, `tags`, `target_compatible_with`, `exec_compatible_with`).
    """
    inverted = {}
    for dest, label in out_dir_files.items():
        if label not in inverted:
            inverted[label] = []
        inverted[label].append(dest)

    _cargo_build_info(
        name = name,
        out_dir_files = {label: json.encode(dests) for label, dests in inverted.items()},
        cc_lib = cc_lib,
        rustc_flags = rustc_flags or [],
        rustc_env = rustc_env or {},
        dep_env = dep_env or {},
        links = links,
        **kwargs
    )

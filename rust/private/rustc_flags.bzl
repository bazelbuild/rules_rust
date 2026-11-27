"""A module defining the `rustc_flags` rule."""

RustcFlagsInfo = provider(
    doc = "A provider describing flags for rustc.",
    fields = {
        "flags": "list[str]: The flags to pass to rustc.",
    },
)

def _rustc_flags_impl(ctx):
    flags = [flag for dep in ctx.attr.deps for flag in dep[RustcFlagsInfo].flags]
    return [RustcFlagsInfo(flags = flags + ctx.attr.flags)]

rustc_flags = rule(
    doc = """Flags for rustc, for use in the `rustc_flags` attribute of `rust_toolchain`.

These targets are configured with the toolchain that uses them, so `flags` may `select()` on the
platform. One toolchain can then serve platforms that share a target triple, such as x86-64 machines
at different microarchitecture levels:

```python
rustc_flags(
    name = "x86_64_v3",
    flags = select({
        "//platforms:x86_64_v3": ["-Ctarget-cpu=x86-64-v3"],
        "//conditions:default": [],
    }),
)
```
""",
    implementation = _rustc_flags_impl,
    attrs = {
        "deps": attr.label_list(
            doc = "Other `rustc_flags` targets, whose flags come before `flags`.",
            providers = [RustcFlagsInfo],
        ),
        "flags": attr.string_list(
            doc = "The flags to pass to rustc.",
        ),
    },
)

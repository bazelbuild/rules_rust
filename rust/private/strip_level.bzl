"""A module defining Rust strip-level rules"""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

RustStripLevelInfo = provider(
    doc = "A provider describing the strip-level settings per compilation mode.",
    fields = {
        "levels": "dict[str, str]: Mapping of compilation mode to strip-level string.",
    },
)

def _rust_strip_level_flag_impl(ctx):
    levels = {}
    for mode in ("dbg", "fastbuild", "opt"):
        levels[mode] = getattr(ctx.attr, mode)[BuildSettingInfo].value
    return [RustStripLevelInfo(levels = levels)]

rust_strip_level_flag = rule(
    doc = "Aggregates the three per-mode strip-level flags into a single RustStripLevelInfo provider. Valid values are defined by rustc: https://doc.rust-lang.org/rustc/codegen-options/index.html#strip",
    implementation = _rust_strip_level_flag_impl,
    attrs = {
        "dbg": attr.label(default = "//rust/settings:strip_level_dbg"),
        "fastbuild": attr.label(default = "//rust/settings:strip_level_fastbuild"),
        "opt": attr.label(default = "//rust/settings:strip_level_opt"),
    },
)

"""A module defining Rust opt-level rules"""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

RustOptLevelInfo = provider(
    doc = "A provider describing the opt-level settings per compilation mode.",
    fields = {
        "levels": "dict[str, str]: Mapping of compilation mode to opt-level string.",
    },
)

def _rust_opt_level_flag_impl(ctx):
    levels = {}
    for mode in ("dbg", "fastbuild", "opt"):
        levels[mode] = getattr(ctx.attr, mode)[BuildSettingInfo].value
    return [RustOptLevelInfo(levels = levels)]

rust_opt_level_flag = rule(
    doc = "Aggregates the three per-mode opt-level flags into a single RustOptLevelInfo provider. Valid values are defined by rustc: https://doc.rust-lang.org/rustc/codegen-options/index.html#opt-level",
    implementation = _rust_opt_level_flag_impl,
    attrs = {
        "dbg": attr.label(default = "//rust/settings:opt_level_dbg"),
        "fastbuild": attr.label(default = "//rust/settings:opt_level_fastbuild"),
        "opt": attr.label(default = "//rust/settings:opt_level_opt"),
    },
)

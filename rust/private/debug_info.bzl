"""A module defining Rust debug-info rules"""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

RustDebugInfoInfo = provider(
    doc = "A provider describing the debug-info settings per compilation mode.",
    fields = {
        "levels": "dict[str, str]: Mapping of compilation mode to debug-info string.",
    },
)

def _rust_debug_info_flag_impl(ctx):
    levels = {}
    for mode in ("dbg", "fastbuild", "opt"):
        levels[mode] = getattr(ctx.attr, mode)[BuildSettingInfo].value
    return [RustDebugInfoInfo(levels = levels)]

rust_debug_info_flag = rule(
    doc = "Aggregates the three per-mode debug-info flags into a single RustDebugInfoInfo provider. Valid values are defined by rustc: https://doc.rust-lang.org/rustc/codegen-options/index.html#debuginfo.",
    implementation = _rust_debug_info_flag_impl,
    attrs = {
        "dbg": attr.label(default = "//rust/settings:debug_info_dbg"),
        "fastbuild": attr.label(default = "//rust/settings:debug_info_fastbuild"),
        "opt": attr.label(default = "//rust/settings:debug_info_opt"),
    },
)

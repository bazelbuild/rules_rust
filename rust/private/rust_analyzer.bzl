# Copyright 2020 Google
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Rust Analyzer Bazel rules.

rust_analyzer will generate a rust-project.json file for the
given targets. This file can be consumed by rust-analyzer as an alternative
to Cargo.toml files.
"""

load("//rust/platform:triple_mappings.bzl", "system_to_dylib_ext", "triple_to_system")
load("//rust/private:common.bzl", "rust_common")
load("//rust/private:rustc.bzl", "BuildInfo")
load(
    "//rust/private:utils.bzl",
    "concat",
    "dedent",
    "dedup_expand_location",
    "find_toolchain",
)

RustAnalyzerInfo = provider(
    doc = "RustAnalyzerInfo holds rust crate metadata for targets",
    fields = {
        "build_info": "BuildInfo: build info for this crate if present",
        "cfgs": "List[String]: features or other compilation --cfg settings",
        "crate": "rust_common.crate_info",
        "crate_specs": "Depset[File]: transitive closure of OutputGroupInfo files",
        "deps": "List[RustAnalyzerInfo]: direct dependencies",
        "env": "Dict{String: String}: Environment variables, used for the `env!` macro",
        "proc_macro_dylib_path": "File: compiled shared library output of proc-macro rule",
    },
)

RustAnalyzerGroupInfo = provider(
    doc = "RustAnalyzerGroupInfo holds multiple RustAnalyzerInfos",
    fields = {
        "deps": "List[RustAnalyzerInfo]: direct dependencies",
    },
)

def _rust_analyzer_aspect_impl(target, ctx):
    if (rust_common.crate_info not in target and
        rust_common.test_crate_info not in target and
        rust_common.crate_group_info not in target):
        return []

    toolchain = find_toolchain(ctx)

    # Always add `test` & `debug_assertions`. See rust-analyzer source code:
    # https://github.com/rust-analyzer/rust-analyzer/blob/2021-11-15/crates/project_model/src/workspace.rs#L529-L531
    cfgs = ["test", "debug_assertions"]
    if hasattr(ctx.rule.attr, "crate_features"):
        cfgs += ['feature="{}"'.format(f) for f in ctx.rule.attr.crate_features]
    if hasattr(ctx.rule.attr, "rustc_flags"):
        cfgs += [f[6:] for f in ctx.rule.attr.rustc_flags if f.startswith("--cfg ") or f.startswith("--cfg=")]

    build_info = None
    dep_infos = []
    if hasattr(ctx.rule.attr, "deps"):
        for dep in ctx.rule.attr.deps:
            # Save BuildInfo if we find any (for build script output)
            if BuildInfo in dep:
                build_info = dep[BuildInfo]
        dep_infos = [dep[RustAnalyzerInfo] for dep in ctx.rule.attr.deps if RustAnalyzerInfo in dep]

        group_infos = [dep[RustAnalyzerGroupInfo] for dep in ctx.rule.attr.deps if RustAnalyzerGroupInfo in dep]
        for group_info in group_infos:
            dep_infos.extend(group_info.deps)

    if hasattr(ctx.rule.attr, "proc_macro_deps"):
        dep_infos += [dep[RustAnalyzerInfo] for dep in ctx.rule.attr.proc_macro_deps if RustAnalyzerInfo in dep]

        group_infos = [dep[RustAnalyzerGroupInfo] for dep in ctx.rule.attr.proc_macro_deps if RustAnalyzerGroupInfo in dep]
        for group_info in group_infos:
            dep_infos.extend(group_info.deps)

    if hasattr(ctx.rule.attr, "crate") and ctx.rule.attr.crate != None:
        if RustAnalyzerInfo in ctx.rule.attr.crate:
            dep_infos.append(ctx.rule.attr.crate[RustAnalyzerInfo])

        if RustAnalyzerGroupInfo in ctx.rule.attr.crate:
            dep_infos.extend(ctx.rule.attr.crate[RustAnalyzerGroupInfo])

    if hasattr(ctx.rule.attr, "actual") and ctx.rule.attr.actual != None:
        if RustAnalyzerInfo in ctx.rule.attr.actual:
            dep_infos.append(ctx.rule.attr.actual[RustAnalyzerInfo])

        if RustAnalyzerGroupInfo in ctx.rule.attr.actual:
            dep_infos.extend(ctx.rule.attr.actul[RustAnalyzerGroupInfo])

    if rust_common.crate_group_info in target:
        return [RustAnalyzerGroupInfo(deps = dep_infos)]

    if rust_common.crate_info in target:
        crate_info = target[rust_common.crate_info]
    elif rust_common.test_crate_info in target:
        crate_info = target[rust_common.test_crate_info].crate
    else:
        fail("Unexpected target type: {}".format(target))

    crate_spec = ctx.actions.declare_file(ctx.label.name + ".rust_analyzer_crate_spec")

    rust_analyzer_info = RustAnalyzerInfo(
        crate = crate_info,
        cfgs = cfgs,
        env = getattr(ctx.rule.attr, "rustc_env", {}),
        deps = dep_infos,
        crate_specs = depset(direct = [crate_spec], transitive = [dep.crate_specs for dep in dep_infos]),
        proc_macro_dylib_path = find_proc_macro_dylib_path(toolchain, target),
        build_info = build_info,
    )

    ctx.actions.write(
        output = crate_spec,
        content = json.encode(_create_single_crate(ctx, rust_analyzer_info)),
    )

    return [
        rust_analyzer_info,
        OutputGroupInfo(rust_analyzer_crate_spec = rust_analyzer_info.crate_specs),
    ]

def find_proc_macro_dylib_path(toolchain, target):
    """Find the proc_macro_dylib_path of target. Returns None if target crate is not type proc-macro.

    Args:
        toolchain: The current rust toolchain.
        target: The current target.
    Returns:
        (path): The path to the proc macro dylib, or None if this crate is not a proc-macro.
    """
    if rust_common.crate_info in target:
        crate_info = target[rust_common.crate_info]
    elif rust_common.test_crate_info in target:
        crate_info = target[rust_common.test_crate_info].crate
    else:
        return None

    if crate_info.type != "proc-macro":
        return None

    dylib_ext = system_to_dylib_ext(triple_to_system(toolchain.target_triple))
    for action in target.actions:
        for output in action.outputs.to_list():
            if output.extension == dylib_ext[1:]:
                return output.path

    # Failed to find the dylib path inside a proc-macro crate.
    # TODO: Should this be an error?
    return None

rust_analyzer_aspect = aspect(
    attr_aspects = ["deps", "proc_macro_deps", "crate", "actual"],
    implementation = _rust_analyzer_aspect_impl,
    toolchains = [str(Label("//rust:toolchain_type"))],
    incompatible_use_toolchain_transition = True,
    doc = "Annotates rust rules with RustAnalyzerInfo later used to build a rust-project.json",
)

_EXEC_ROOT_TEMPLATE = "__EXEC_ROOT__/"
_OUTPUT_BASE_TEMPLATE = "__OUTPUT_BASE__/"

def _crate_id(crate_info):
    """Returns a unique stable identifier for a crate

    Returns:
        (string): This crate's unique stable id.
    """
    return "ID-" + crate_info.root.path

def _create_single_crate(ctx, info):
    """Creates a crate in the rust-project.json format.

    Args:
        ctx (ctx): The rule context
        info (RustAnalyzerInfo): RustAnalyzerInfo for the current crate

    Returns:
        (dict) The crate rust-project.json representation
    """
    crate_name = info.crate.name
    crate = dict()
    crate_id = _crate_id(info.crate)
    crate["crate_id"] = crate_id
    crate["display_name"] = crate_name
    crate["edition"] = info.crate.edition
    crate["env"] = {}
    crate["crate_type"] = info.crate.type

    # Switch on external/ to determine if crates are in the workspace or remote.
    # TODO: Some folks may want to override this for vendored dependencies.
    is_external = info.crate.root.path.startswith("external/")
    is_generated = not info.crate.root.is_source
    path_prefix = _EXEC_ROOT_TEMPLATE if is_external or is_generated else ""
    crate["is_workspace_member"] = not is_external
    crate["root_module"] = path_prefix + info.crate.root.path
    crate_root = path_prefix + info.crate.root.dirname

    if info.build_info != None:
        out_dir_path = info.build_info.out_dir.path
        crate["env"].update({"OUT_DIR": _EXEC_ROOT_TEMPLATE + out_dir_path})
        crate["source"] = {
            # We have to tell rust-analyzer about our out_dir since it's not under the crate root.
            "exclude_dirs": [],
            "include_dirs": [crate_root, _EXEC_ROOT_TEMPLATE + out_dir_path],
        }

    # TODO: The only imagined use case is an env var holding a filename in the workspace passed to a
    # macro like include_bytes!. Other use cases might exist that require more complex logic.
    expand_targets = concat([getattr(ctx.rule.attr, attr, []) for attr in ["data", "compile_data"]])

    crate["env"].update({k: dedup_expand_location(ctx, v, expand_targets) for k, v in info.env.items()})

    # Omit when a crate appears to depend on itself (e.g. foo_test crates).
    # It can happen a single source file is present in multiple crates - there can
    # be a `rust_library` with a `lib.rs` file, and a `rust_test` for the `test`
    # module in that file. Tests can declare more dependencies than what library
    # had. Therefore we had to collect all RustAnalyzerInfos for a given crate
    # and take deps from all of them.

    # There's one exception - if the dependency is the same crate name as the
    # the crate being processed, we don't add it as a dependency to itself. This is
    # common and expected - `rust_test.crate` pointing to the `rust_library`.
    crate["deps"] = [_crate_id(dep.crate) for dep in info.deps if _crate_id(dep.crate) != crate_id]
    crate["cfg"] = info.cfgs
    crate["target"] = find_toolchain(ctx).target_triple.str
    if info.proc_macro_dylib_path != None:
        crate["proc_macro_dylib_path"] = _EXEC_ROOT_TEMPLATE + info.proc_macro_dylib_path
    return crate

def _rust_analyzer_toolchain_impl(ctx):
    toolchain = platform_common.ToolchainInfo(
        proc_macro_srv = ctx.executable.proc_macro_srv,
        rustc = ctx.executable.rustc,
        rustc_srcs = ctx.attr.rustc_srcs,
    )

    return [toolchain]

rust_analyzer_toolchain = rule(
    implementation = _rust_analyzer_toolchain_impl,
    doc = "A toolchain for [rust-analyzer](https://rust-analyzer.github.io/).",
    attrs = {
        "proc_macro_srv": attr.label(
            doc = "The path to a `rust_analyzer_proc_macro_srv` binary.",
            cfg = "exec",
            executable = True,
            allow_single_file = True,
        ),
        "rustc": attr.label(
            doc = "The path to a `rustc` binary.",
            cfg = "exec",
            executable = True,
            allow_single_file = True,
            mandatory = True,
        ),
        "rustc_srcs": attr.label(
            doc = "The source code of rustc.",
            mandatory = True,
        ),
    },
    incompatible_use_toolchain_transition = True,
)

def _rust_analyzer_detect_sysroot_impl(ctx):
    rust_analyzer_toolchain = ctx.toolchains[Label("@rules_rust//rust/rust_analyzer:toolchain_type")]

    if not rust_analyzer_toolchain.rustc_srcs:
        fail(
            "Current Rust-Analyzer toolchain doesn't contain rustc sources in `rustc_srcs` attribute.",
            "These are needed by rust-analyzer. If you are using the default Rust toolchain, add `rust_repositories(include_rustc_srcs = True, ...).` to your WORKSPACE file.",
        )

    rustc_srcs = rust_analyzer_toolchain.rustc_srcs

    sysroot_src = rustc_srcs.label.package + "/library"
    if rustc_srcs.label.workspace_root:
        sysroot_src = _OUTPUT_BASE_TEMPLATE + rustc_srcs.label.workspace_root + "/" + sysroot_src

    rustc = rust_analyzer_toolchain.rustc
    sysroot_dir, _, bin_dir = rustc.dirname.rpartition("/")
    if bin_dir != "bin":
        fail("The rustc path is expected to be relative to the sysroot as `bin/rustc`. Instead got: {}".format(
            rustc.path,
        ))

    sysroot = "{}/{}".format(
        _OUTPUT_BASE_TEMPLATE,
        sysroot_dir,
    )

    toolchain_info = {
        "sysroot": sysroot,
        "sysroot_src": sysroot_src,
    }

    output = ctx.actions.declare_file(ctx.label.name + ".rust_analyzer_toolchain.json")
    ctx.actions.write(
        output = output,
        content = json.encode_indent(toolchain_info, indent = " " * 4),
    )

    return [DefaultInfo(files = depset([output]))]

rust_analyzer_detect_sysroot = rule(
    implementation = _rust_analyzer_detect_sysroot_impl,
    toolchains = [
        "@rules_rust//rust:toolchain_type",
        "@rules_rust//rust/rust_analyzer:toolchain_type",
    ],
    incompatible_use_toolchain_transition = True,
    doc = dedent("""\
        Detect the sysroot and store in a file for use by the gen_rust_project tool.
    """),
)

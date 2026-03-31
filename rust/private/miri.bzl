# Copyright 2026 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Miri execution rules backed by the direct `miri` driver."""

load("//rust/private:common.bzl", "rust_common")
load("//rust/private:miri_config.bzl", "miri_transition", "rlocationpath")
load("//rust/private:utils.bzl", "dedent", "find_toolchain")

_RUNFILES_BASH_INIT = """# --- begin runfiles.bash initialization v3 ---
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 \"^$f \" "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 \"^$f \" "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 \"^$f \" "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---
"""

def _shell_quote(value):
    return "'{}'".format(value.replace("'", "'\"'\"'"))

def _crate_from_target(target):
    # Wrapper rules accept either a normal crate target or a rust_test target;
    # tests store the executable harness in test_crate_info.crate.
    if rust_common.crate_info in target:
        return target[rust_common.crate_info]
    return target[rust_common.test_crate_info].crate

def _crate_info_for_extern(dep):
    return dep.dep if hasattr(dep, "dep") else dep

def _crate_name_for_extern(dep):
    return dep.name if hasattr(dep, "dep") else dep.name

def _emit_shell_array(name, values):
    lines = ["{}=(".format(name)]
    for value in values:
        lines.append("  {}".format(_shell_quote(value)))
    lines.append(")")
    return lines

def _target_flag_lines(ctx, toolchain):
    if toolchain.target_json:
        return [
            "TARGET_FLAG=$(rlocation {})".format(_shell_quote(rlocationpath(toolchain.target_json, ctx.workspace_name))),
        ]

    return ["TARGET_FLAG={}".format(_shell_quote(toolchain.target_flag_value))]

def _script_content(ctx, *, crate, dep_info, miri_toolchain, is_test, miri_flags):
    # The generated launcher reconstructs a rustc-shaped direct Miri invocation
    # from the analyzed Bazel crate graph; this keeps Cargo out of the runtime
    # path and lets Bazel stay the source of truth for dependencies.
    toolchain = find_toolchain(ctx)
    crate_type = "bin" if is_test else crate.type

    if not is_test and crate.type != "bin":
        fail("miri_binary requires a wrapped `rust_binary`-like target. {} has crate type {}".format(ctx.attr.crate.label, crate.type))

    if dep_info.transitive_noncrates.to_list():
        # The current launcher only knows how to feed Rust crate artifacts to
        # Miri. Mixed Rust/native graphs need extra modeling that this V1 does
        # not implement yet.
        fail("{} depends on native linker inputs. Direct `miri` execution is only supported for pure-Rust dependency graphs right now.".format(ctx.attr.crate.label))

    # Pass direct Rust dependencies as explicit --extern flags and transitive
    # crate outputs as -Ldependency search paths, mirroring the rustc command
    # line shape that Miri expects.
    extern_specs = []
    for dep in dep_info.direct_crates.to_list():
        dep_crate = _crate_info_for_extern(dep)
        extern_specs.append("{}|{}".format(
            _crate_name_for_extern(dep),
            rlocationpath(dep_crate.output, ctx.workspace_name),
        ))

    dependency_outputs = []
    seen_outputs = {}
    for dep in dep_info.transitive_crates.to_list():
        dep_output = rlocationpath(dep.output, ctx.workspace_name)
        if dep_output not in seen_outputs:
            seen_outputs[dep_output] = None
            dependency_outputs.append(dep_output)

    rustc_env_exports = []
    for key in sorted(crate.rustc_env.keys()):
        rustc_env_exports.append("export {}={}".format(key, _shell_quote(crate.rustc_env[key])))

    rustc_env_files = [rlocationpath(file, ctx.workspace_name) for file in crate.rustc_env_files]

    lines = [
        "#!/usr/bin/env bash",
        _RUNFILES_BASH_INIT.rstrip(),
        "",
        "set -euo pipefail",
        "",
        # Resolve runtime inputs out of Bazel runfiles so the launcher works
        # the same under `bazel run`, `bazel test`, and direct execution.
        "MIRI=$(rlocation {})".format(_shell_quote(rlocationpath(miri_toolchain.miri, ctx.workspace_name))),
        "CRATE_ROOT=$(rlocation {})".format(_shell_quote(rlocationpath(crate.root, ctx.workspace_name))),
        "SYSROOT=$(dirname \"$(rlocation {})\")".format(_shell_quote(rlocationpath(miri_toolchain.sysroot_anchor, ctx.workspace_name))),
    ]
    lines.extend(_target_flag_lines(ctx, toolchain))
    lines.extend([
        "",
        "export CARGO_MANIFEST_DIR=$(dirname \"${CRATE_ROOT}\")",
        "export REPOSITORY_NAME={}".format(_shell_quote(ctx.label.workspace_name)),
    ])
    lines.extend(rustc_env_exports)

    if rustc_env_files:
        lines.append("")
        lines.extend(_emit_shell_array("rustc_env_files", rustc_env_files))
        lines.extend([
            'for env_file in "${rustc_env_files[@]}"; do',
            "  set -a",
            "  # shellcheck disable=SC1090",
            '  source "$(rlocation "$env_file")"',
            "  set +a",
            "done",
        ])

    lines.append("")
    lines.extend(_emit_shell_array("extern_specs", extern_specs))
    lines.extend(_emit_shell_array("dependency_outputs", dependency_outputs))
    lines.extend(_emit_shell_array("cfg_values", crate.cfgs))
    lines.extend(_emit_shell_array("miri_flags", miri_flags))
    lines.extend(_emit_shell_array("launcher_args", ctx.attr.miri_args))
    lines.extend([
        "",
        "cmd=(",
        '  "${MIRI}"',
        '  "--sysroot=${SYSROOT}"',
        '  "--crate-name={}"'.format(crate.name),
        '  "--crate-type={}"'.format(crate_type),
        '  "--edition={}"'.format(crate.edition),
        '  "--target=${TARGET_FLAG}"',
        '  "--error-format=human"',
        '  "--color=always"',
    ])
    if is_test:
        lines.append('  "--test"')
    lines.extend([
        '  "${CRATE_ROOT}"',
        ")",
        'for cfg in "${cfg_values[@]}"; do',
        '  cmd+=("--cfg" "$cfg")',
        "done",
        'for flag in "${miri_flags[@]}"; do',
        '  cmd+=("$flag")',
        "done",
        'for spec in "${extern_specs[@]}"; do',
        '  name="${spec%%|*}"',
        '  path="${spec#*|}"',
        '  cmd+=("--extern=${name}=$(rlocation "$path")")',
        "done",
        'for dep_output in "${dependency_outputs[@]}"; do',
        '  cmd+=("-Ldependency=$(dirname "$(rlocation "$dep_output")")")',
        "done",
    ])
    if is_test:
        lines.extend([
            # Tests are executed through the standard libtest harness, so the
            # launcher forwards Bazel test filtering after the `--` separator.
            'cmd+=("--" "--test-threads=1")',
            'if [[ -n "${TESTBRIDGE_TEST_ONLY:-}" ]]; then',
            '  cmd+=("${TESTBRIDGE_TEST_ONLY}")',
            "fi",
            'for arg in "${launcher_args[@]}"; do',
            '  cmd+=("$arg")',
            "done",
            'if [[ "$#" -gt 0 ]]; then',
            '  cmd+=("$@")',
            "fi",
        ])
    else:
        lines.extend([
            'if [[ ${#launcher_args[@]} -gt 0 || "$#" -gt 0 ]]; then',
            '  cmd+=("--")',
            '  for arg in "${launcher_args[@]}"; do',
            '    cmd+=("$arg")',
            "  done",
            '  if [[ "$#" -gt 0 ]]; then',
            '    cmd+=("$@")',
            "  fi",
            "fi",
        ])
    lines.extend([
        'exec "${cmd[@]}"',
        "",
    ])
    return "\n".join(lines)

def _miri_impl(ctx, *, is_test):
    # The wrapped Rust target is already re-analyzed in Miri mode by the rule
    # transition; this implementation only has to assemble the final launcher
    # over that rebuilt crate graph.
    toolchain = find_toolchain(ctx)
    miri_toolchain = ctx.toolchains[str(Label("//rust:miri_toolchain_type"))]
    if not miri_toolchain:
        fail("No `@rules_rust//rust:miri_toolchain_type` is registered. Register a Miri toolchain before using {}.".format(ctx.label))

    crate = _crate_from_target(ctx.attr.crate)
    dep_info = ctx.attr.crate[rust_common.dep_info]

    script = ctx.actions.declare_file(ctx.label.name + (".miri_test.sh" if is_test else ".miri_binary.sh"))
    ctx.actions.write(
        output = script,
        content = _script_content(
            ctx,
            crate = crate,
            dep_info = dep_info,
            miri_toolchain = miri_toolchain,
            is_test = is_test,
            miri_flags = ctx.attr.miri_flags,
        ),
        is_executable = True,
    )

    # Include both compile-time Rust artifacts and the Bazel test harness
    # scripts so the generated launcher behaves like a normal Bazel executable.
    runfiles = ctx.runfiles(
        transitive_files = depset(
            transitive = [
                crate.srcs,
                crate.compile_data,
                dep_info.transitive_crate_outputs,
                dep_info.transitive_proc_macro_data,
                dep_info.transitive_data,
                toolchain.all_files,
                miri_toolchain.all_files,
                ctx.attr._bash_runfiles[DefaultInfo].files,
                ctx.attr._test_setup[DefaultInfo].files,
                ctx.attr._bazel_test_setup_script[DefaultInfo].files,
            ],
        ),
    ).merge(ctx.attr._test_setup[DefaultInfo].default_runfiles)

    return [
        DefaultInfo(executable = script, runfiles = runfiles),
        RunEnvironmentInfo(
            environment = dict(ctx.attr.env),
            inherited_environment = ctx.attr.env_inherit,
        ),
    ]

def _miri_test_impl(ctx):
    return _miri_impl(ctx, is_test = True)

def _miri_binary_impl(ctx):
    return _miri_impl(ctx, is_test = False)

_MIRI_COMMON_ATTRS = {
    "crate": attr.label(
        mandatory = True,
        providers = [
            [rust_common.dep_info, rust_common.crate_info],
            [rust_common.dep_info, rust_common.test_crate_info],
        ],
        doc = dedent("""\
            Existing Rust target to execute under Miri.

            For `miri_test`, prefer wrapping an existing `rust_test` target so the
            wrapped target already carries any test-only dependencies.
        """),
    ),
    "env": attr.string_dict(
        doc = "Additional runtime environment variables for the generated launcher.",
    ),
    "env_inherit": attr.string_list(
        doc = "Runtime environment variables to inherit from the outer test/run environment.",
    ),
    # `miri_flags` affect the Miri driver itself, while `miri_args` are passed
    # through to the interpreted test harness or binary after the `--` split.
    "miri_args": attr.string_list(
        doc = "Arguments baked into the generated launcher and forwarded after the libtest/program separator.",
    ),
    "miri_flags": attr.string_list(
        default = ["-Zmiri-disable-isolation"],
        doc = "Extra flags forwarded directly to the `miri` driver.",
    ),
    "platform": attr.label(
        doc = "Optional platform to transition the wrapped target to before rebuilding its Rust dependency closure for Miri.",
        default = None,
    ),
    "_allowlist_function_transition": attr.label(
        default = Label("//tools/allowlists/function_transition_allowlist"),
    ),
    "_bash_runfiles": attr.label(
        default = Label("@bazel_tools//tools/bash/runfiles"),
    ),
    "_bazel_test_setup_script": attr.label(
        default = Label("@bazel_tools//tools/test:test-setup.sh"),
        allow_single_file = True,
    ),
    "_test_setup": attr.label(
        default = Label("@bazel_tools//tools/test:test_setup"),
    ),
}

# V1 keeps the public surface small: users wrap an existing rust_test target
# instead of re-declaring srcs/deps on a parallel Miri-only rule.
miri_test = rule(
    implementation = _miri_test_impl,
    executable = True,
    test = True,
    attrs = _MIRI_COMMON_ATTRS,
    cfg = miri_transition,
    toolchains = [
        str(Label("//rust:toolchain_type")),
        str(Label("//rust:miri_toolchain_type")),
    ],
    doc = dedent("""\
        Executes an existing Rust target under the direct `miri` driver.

        This first version wraps an already-declared Rust target rather than mirroring the
        full `rust_test` attribute surface. Wrap an existing `rust_test` target when you
        need test-only dependencies to be part of the interpreted harness.
    """),
)

# `miri_binary` mirrors the same wrapper approach for runnable binary crates.
miri_binary = rule(
    implementation = _miri_binary_impl,
    executable = True,
    attrs = _MIRI_COMMON_ATTRS,
    cfg = miri_transition,
    toolchains = [
        str(Label("//rust:toolchain_type")),
        str(Label("//rust:miri_toolchain_type")),
    ],
    doc = dedent("""\
        Executes an existing `rust_binary`-like target under the direct `miri` driver.
    """),
)

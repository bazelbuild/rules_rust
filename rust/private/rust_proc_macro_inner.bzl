# Copyright 2015 The Bazel Authors. All rights reserved.
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

"""rust_proc_macro implementation"""

load("//rust/private:common.bzl", "COMMON_PROVIDERS")
load("//rust/private:rust.bzl", "common_attrs", "rust_library_common")
load("//rust/private:utils.bzl", "dedent")

def _rust_proc_macro_inner_impl(ctx):
    """The implementation of the `rust_proc_macro` rule.

    Args:
        ctx (ctx): The rule's context object

    Returns:
        list: A list of providers.
    """
    return rust_library_common(ctx, "proc-macro")

def _proc_macro_dep_transition_impl(settings, _attr):
    if settings["//rust/private:is_proc_macro_dep_enabled"]:
        return {"//rust/private:is_proc_macro_dep": True}
    else:
        return []

_proc_macro_dep_transition = transition(
    inputs = ["//rust/private:is_proc_macro_dep_enabled"],
    outputs = ["//rust/private:is_proc_macro_dep"],
    implementation = _proc_macro_dep_transition_impl,
)

# Start by copying the common attributes, then override the `deps` attribute
# to apply `_proc_macro_dep_transition`. To add this transition we additionally
# need to declare `_allowlist_function_transition`, see
# https://docs.bazel.build/versions/main/skylark/config.html#user-defined-transitions.
rust_proc_macro_inner_attrs = dict(
    common_attrs.items(),
    _allowlist_function_transition = attr.label(
        default = Label("//tools/allowlists/function_transition_allowlist"),
    ),
    deps = attr.label_list(
        doc = dedent("""\
            List of other libraries to be linked to this library target.

            These can be either other `rust_library` targets or `cc_library` targets if
            linking a native library.
        """),
        cfg = _proc_macro_dep_transition,
    ),
)

rust_proc_macro = rule(
    implementation = _rust_proc_macro_inner_impl,
    provides = COMMON_PROVIDERS,
    attrs = rust_proc_macro_inner_attrs,
    fragments = ["cpp"],
    toolchains = [
        str(Label("//rust:toolchain_type")),
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    doc = "Builds a Rust proc-macro crate.",
)

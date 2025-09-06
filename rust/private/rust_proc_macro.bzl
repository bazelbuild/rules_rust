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
load(
    "//rust/private:rust_proc_macro_inner.bzl",
    "rust_proc_macro_inner_attrs",
    _rust_proc_macro_inner = "rust_proc_macro",
)

def _rust_proc_macro_impl(ctx):
    """The implementation of the `rust_proc_macro` rule.

    Args:
        ctx (ctx): The rule's context object

    Returns:
        list: A list of providers.
    """
    return [
        ctx.attr.inner[provider]
        for provider in COMMON_PROVIDERS + [OutputGroupInfo]
    ]

rust_proc_macro = rule(
    implementation = _rust_proc_macro_impl,
    provides = COMMON_PROVIDERS,
    # Take all the same attrs in case there are any aspects examining them.
    # `inner` is the only load-bearing one - providers are forwarded.
    attrs = dict(
        rust_proc_macro_inner_attrs.items(),
        inner = attr.label(
            doc = "The wrapped proc_macro crate that will be transitioned to the exec configuration.",
            cfg = "exec",
            providers = COMMON_PROVIDERS,
        ),
    ),
    fragments = ["cpp"],
    toolchains = [
        str(Label("//rust:toolchain_type")),
        "@bazel_tools//tools/cpp:toolchain_type",
    ],
    doc = "Builds a Rust proc-macro crate.",
)

def rust_proc_macro_macro(name, **kwargs):
    kwargs["crate_name"] = kwargs.get("crate_name", name)

    _rust_proc_macro_inner(
        name = name + "_inner",
        **kwargs
    )

    rust_proc_macro(
        name = name,
        inner = name + "_inner",
        **kwargs
    )

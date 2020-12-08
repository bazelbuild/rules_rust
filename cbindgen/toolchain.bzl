# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""A module defining toolchain information about the cbindgen rules"""

def _rust_cbindgen_toolchain_impl(ctx):
    """The implementation of the `rust_cbindgen_toolchain` rule

    Args:
        ctx (ctx): The rule's context object.

    Returns:
        list: A list containing a ToolchainInfo provider.
    """
    return [platform_common.ToolchainInfo(
        cbindgen = ctx.executable.cbindgen,
    )]

rust_cbindgen_toolchain = rule(
    doc = "The tools required for the cbindgen rules.",
    implementation = _rust_cbindgen_toolchain_impl,
    attrs = {
        "cbindgen": attr.label(
            doc = "The label of a `cbindgen` executable.",
            executable = True,
            cfg = "exec",
        ),
    },
)

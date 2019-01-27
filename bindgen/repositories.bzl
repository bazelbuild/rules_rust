# Copyright 2018 The Bazel Authors. All rights reserved.
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

# load("//bindgen/raze:crates.bzl", _cargo_repositories = "raze_fetch_remote_crates")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def maybe(workspace_rule, **kwargs):
    if not native.existing_rule(kwargs["name"]):
        workspace_rule(**kwargs)

def rust_bindgen_repositories():
    # nb. The bindgen rule should work on any platform.
    _linux_rust_bindgen_repositories()

def _linux_rust_bindgen_repositories():
    """Declare dependencies needed for bindgen."""

    maybe(
        http_archive,
        name = "clang",
        urls = ["http://releases.llvm.org/7.0.1/clang+llvm-7.0.1-x86_64-linux-gnu-ubuntu-18.04.tar.xz"],
        strip_prefix = "clang+llvm-7.0.1-x86_64-linux-gnu-ubuntu-18.04",
        sha256 = "e74ce06d99ed9ce42898e22d2a966f71ae785bdf4edbded93e628d696858921a",
        build_file = "@//bindgen:clang.BUILD",
    )

    # TODO: We should be able to pull libstdc++ out of the cc_toolchain eventually.
    maybe(
        native.new_local_repository,
        name = "local_linux",
        path = "/usr/lib/x86_64-linux-gnu",
        build_file_content = """
package(default_visibility = ["//visibility:public"])

cc_library(
    name = "libstdc++",
    srcs = [
        "libstdc++.so.6",
    ],
)
""",
    )

    # TODO(marco):
    #  1. Vendor bindgen with raze...
    #  2. Make rustfmt optional
    maybe(
        native.new_local_repository,
        name = "local_cargo",
        path = "/home/marco/.cargo",
        build_file_content = """
package(default_visibility = ["//visibility:public"])

sh_binary(
    name = "bindgen",
    srcs = ["bin/bindgen"],
)

sh_binary(
    name = "rustfmt",
    srcs = ["bin/rustfmt"],
)
""",
    )

    # Register toolchains
    native.register_toolchains(
        "@io_bazel_rules_rust//bindgen:example-bindgen-toolchain",
    )

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

"""Dependencies for Rust proto rules"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//proto/3rdparty/crates:defs.bzl", "crate_repositories")
load("//proto/prost:repositories.bzl", "rust_prost_dependencies")

def rust_proto_dependencies():
    maybe(
        http_archive,
        name = "rules_proto",
        sha256 = "dc3fb206a2cb3441b485eb1e423165b231235a1ea9b031b4433cf7bc1fa460dd",
        strip_prefix = "rules_proto-5.3.0-21.7",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_proto/archive/refs/tags/5.3.0-21.7.tar.gz",
            "https://github.com/bazelbuild/rules_proto/archive/refs/tags/5.3.0-21.7.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "com_google_protobuf",
        sha256 = "758249b537abba2f21ebc2d02555bf080917f0f2f88f4cbe2903e0e28c4187ed",
        strip_prefix = "protobuf-3.10.0",
        urls = [
            "https://mirror.bazel.build/github.com/protocolbuffers/protobuf/archive/v3.10.0.tar.gz",
            "https://github.com/protocolbuffers/protobuf/archive/v3.10.0.tar.gz",
        ],
        patch_args = ["-p1"],
        patches = [
            Label("//proto/3rdparty/patches:com_google_protobuf-v3.10.0-bzl_visibility.patch"),
        ],
    )

    crate_repositories()

    rust_prost_dependencies()

# buildifier: disable=unnamed-macro
def rust_proto_register_toolchains(register_proto_toolchains = True):
    """Register toolchains for proto compilation."""

    if register_proto_toolchains:
        native.register_toolchains(str(Label("//proto:default-proto-toolchain")))

# buildifier: disable=unnamed-macro
def rust_proto_repositories(register_default_toolchain = True):
    """Declare dependencies needed for proto compilation.

    Args:
        register_default_toolchain (bool, optional): If True, the default [rust_proto_toolchain](#rust_proto_toolchain)
            (`@rules_rust//proto:default-proto-toolchain`) is registered. This toolchain requires a set of dependencies
            that were generated using [crate_universe](https://github.com/bazelbuild/rules_rust/tree/main/crate_universe). These will also be loaded.
    """

    rust_proto_dependencies()
    rust_proto_register_toolchains(register_proto_toolchains = register_default_toolchain)

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

# buildifier: disable=module-docstring
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//proto/raze:crates.bzl", "rules_rust_proto_fetch_remote_crates")

# buildifier: disable=unnamed-macro
def rust_proto_repositories(register_default_toolchain = True):
    """Declare dependencies needed for proto compilation.

    Args:
        register_default_toolchain (bool, optional): If True, the default [rust_proto_toolchain](#rust_proto_toolchain)
            (`@rules_rust//proto:default-proto-toolchain`) is registered. This toolchain requires a set of dependencies
            that were generated using [cargo raze](https://github.com/google/cargo-raze). These will also be loaded.
    """
    maybe(
        http_archive,
        name = "rules_proto",
        sha256 = "bc12122a5ae4b517fa423ea03a8d82ea6352d5127ea48cb54bc324e8ab78493c",
        strip_prefix = "rules_proto-af6481970a34554c6942d993e194a9aed7987780",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_proto/archive/af6481970a34554c6942d993e194a9aed7987780.tar.gz",
            "https://github.com/bazelbuild/rules_proto/archive/af6481970a34554c6942d993e194a9aed7987780.tar.gz",
        ],
        patch_args = ["-p1"],
        patches = [
            Label("//proto/patches:rules_proto-bzl_visibility.patch"),
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
            Label("//proto/patches:com_google_protobuf-v3.10.0-bzl_visibility.patch"),
        ],
    )

    rules_rust_proto_fetch_remote_crates()

    # Register toolchains
    if register_default_toolchain:
        native.register_toolchains(str(Label("//proto:default-proto-toolchain")))

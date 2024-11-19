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
load("//proto/protobuf/3rdparty/crates:defs.bzl", "crate_repositories")

def rust_proto_protobuf_dependencies(bzlmod = False):
    """Sets up dependencies for rules_rust's proto support.

    Args:
        bzlmod (bool): Whether this function is being called from a bzlmod context rather than a workspace context.

    Returns:
        A list of structs containing information about root module deps to report to bzlmod's extension_metadata.

    """
    if not bzlmod:
        maybe(
            http_archive,
            name = "rules_proto",
            sha256 = "6fb6767d1bef535310547e03247f7518b03487740c11b6c6adb7952033fe1295",
            strip_prefix = "rules_proto-6.0.2",
            url = "https://github.com/bazelbuild/rules_proto/releases/download/6.0.2/rules_proto-6.0.2.tar.gz",
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
                Label("//proto/protobuf/3rdparty/patches:com_google_protobuf-v3.10.0-bzl_visibility.patch"),
            ],
        )

        maybe(
            http_archive,
            name = "bazel_features",
            sha256 = "5d7e4eb0bb17aee392143cd667b67d9044c270a9345776a5e5a3cccbc44aa4b3",
            strip_prefix = "bazel_features-1.13.0",
            url = "https://github.com/bazel-contrib/bazel_features/releases/download/v1.13.0/bazel_features-v1.13.0.tar.gz",
        )

    return crate_repositories()

# buildifier: disable=unnamed-macro
def rust_proto_protobuf_register_toolchains(register_toolchains = True):
    """Register toolchains for proto compilation."""

    if register_toolchains:
        native.register_toolchains(str(Label("//proto/protobuf:default-proto-toolchain")))

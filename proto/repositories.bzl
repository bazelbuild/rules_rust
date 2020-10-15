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
def rust_proto_repositories():
    """Declare dependencies needed for proto compilation."""
    maybe(
        http_archive,
        name = "com_google_protobuf",
        sha256 = "758249b537abba2f21ebc2d02555bf080917f0f2f88f4cbe2903e0e28c4187ed",
        strip_prefix = "protobuf-3.10.0",
        urls = [
            "https://mirror.bazel.build/github.com/protocolbuffers/protobuf/archive/v3.10.0.tar.gz",
            "https://github.com/protocolbuffers/protobuf/archive/v3.10.0.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "rules_python",
        strip_prefix = "rules_python-0.0.1",
        type = "zip",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_python/archive/0.0.1.zip",
            "https://github.com/bazelbuild/rules_python/archive/0.0.1.zip",
        ],
        sha256 = "f73c0cf51c32c7aaeaf02669ed03b32d12f2d92e1b05699eb938a75f35a210f4",
    )

    maybe(
        http_archive,
        name = "six",
        build_file = "@com_google_protobuf//:third_party/six.BUILD",
        sha256 = "d16a0141ec1a18405cd4ce8b4613101da75da0e9a7aec5bdd4fa804d0e0eba73",
        urls = [
            "https://mirror.bazel.build/pypi.python.org/packages/source/s/six/six-1.12.0.tar.gz",
            "https://pypi.python.org/packages/source/s/six/six-1.12.0.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "zlib",
        build_file = "@com_google_protobuf//:third_party/zlib.BUILD",
        sha256 = "c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1",
        strip_prefix = "zlib-1.2.11",
        urls = [
            "https://mirror.bazel.build/zlib.net/zlib-1.2.11.tar.gz",
            "https://zlib.net/zlib-1.2.11.tar.gz",
        ],
    )

    rules_rust_proto_fetch_remote_crates()

    # Register toolchains
    native.register_toolchains(
        "@io_bazel_rules_rust//proto:default-proto-toolchain",
    )

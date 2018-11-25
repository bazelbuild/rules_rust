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

load("//proto/raze:crates.bzl", _crate_deps = "raze_fetch_remote_crates")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def rust_proto_repositories():
    """Declare dependencies needed for proto compilation."""
    if not native.existing_rule("com_google_protobuf"):
        http_archive(
            name = "com_google_protobuf",
            # commit 7b28271a61a3da0a37f6fda399b0c4c86464e5b3 is from 2018-11-16
            urls = ["https://github.com/protocolbuffers/protobuf/archive/7b28271a61a3da0a37f6fda399b0c4c86464e5b3.tar.gz"],
            strip_prefix = "protobuf-7b28271a61a3da0a37f6fda399b0c4c86464e5b3",
            sha256 = "9dac7d7cf6e2c88bf92915f9338a26950531c00c05bf86764ab978344b69a45a",
        )

    _crate_deps()

    # Register toolchains
    native.register_toolchains(
        "@io_bazel_rules_rust//proto:default-proto-toolchain",
    )

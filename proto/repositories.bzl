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
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

def rust_proto_repositories():
    """Declare dependencies needed for proto compilation."""
    if not native.existing_rule("com_google_protobuf"):
        git_repository(
            name = "com_google_protobuf",
            remote = "https://github.com/protocolbuffers/protobuf.git",
            commit = "7b28271a61a3da0a37f6fda399b0c4c86464e5b3",  # 2018-11-16
        )

    _crate_deps()

    # Register toolchains
    native.register_toolchains(
        "@io_bazel_rules_rust//proto:default-proto-toolchain",
    )

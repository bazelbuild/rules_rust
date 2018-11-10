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

load("//proto/raze:crates.bzl", _crate_deps="raze_fetch_remote_crates")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def rust_proto_repositories():
  """Declare dependencies needed for proto compilation."""
  if not native.existing_rule("com_google_protobuf"):
    http_archive(
      name="com_google_protobuf",
      urls=["https://github.com/google/protobuf/archive/v3.5.1.zip"],
      strip_prefix="protobuf-3.5.1",
      sha256="1f8b9b202e9a4e467ff0b0f25facb1642727cdf5e69092038f15b37c75b99e45",
    )

  _crate_deps()
  
  # Register toolchains
  native.register_toolchains(
      "@io_bazel_rules_rust//proto:default-proto-toolchain",
  )
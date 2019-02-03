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

load("//bindgen/raze:crates.bzl", "raze_fetch_remote_crates")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def maybe(workspace_rule, **kwargs):
    if not native.existing_rule(kwargs["name"]):
        workspace_rule(**kwargs)

def rust_bindgen_repositories():
    """Declare dependencies needed for bindgen."""

    # nb. The bindgen rule itself should work on any platform.
    _linux_rust_bindgen_repositories()

    # This overrides the BUILD file raze generates for libloading with a handwritten one.
    # TODO: Tidier to implement https://github.com/google/cargo-raze/issues/58
    maybe(
        http_archive,
        name = "raze__libloading__0_5_0",
        url = "https://crates-io.s3-us-west-1.amazonaws.com/crates/libloading/libloading-0.5.0.crate",
        type = "tar.gz",
        sha256 = "9c3ad660d7cb8c5822cd83d10897b0f1f1526792737a179e73896152f85b88c2",
        strip_prefix = "libloading-0.5.0",
        # TODO: This is a manual patch, need https://github.com/google/cargo-raze/issues/58
        build_file = Label("//bindgen/raze:libloading.BUILD")
    )
    raze_fetch_remote_crates()

    native.register_toolchains("@io_bazel_rules_rust//bindgen:example-bindgen-toolchain")

def _linux_rust_bindgen_repositories():
    # Releases @ http://releases.llvm.org/download.html
    maybe(
        http_archive,
        name = "clang",
        urls = ["http://releases.llvm.org/7.0.1/clang+llvm-7.0.1-x86_64-linux-gnu-ubuntu-18.04.tar.xz"],
        strip_prefix = "clang+llvm-7.0.1-x86_64-linux-gnu-ubuntu-18.04",
        sha256 = "e74ce06d99ed9ce42898e22d2a966f71ae785bdf4edbded93e628d696858921a",
        build_file = "@//bindgen:clang.BUILD",
    )

    # TODO: We should be able to locate libstdc++ via cc_toolchain eventually.
    maybe(
        native.new_local_repository,
        name = "local_linux",
        path = "/usr/lib/x86_64-linux-gnu",
        build_file = "@//bindgen:local_linux.BUILD",
    )

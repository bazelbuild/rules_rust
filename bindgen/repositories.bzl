# Copyright 2019 The Bazel Authors. All rights reserved.
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

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//bindgen/raze:crates.bzl", "rules_rust_bindgen_fetch_remote_crates")

# buildifier: disable=unnamed-macro
def rust_bindgen_repositories():
    """Declare dependencies needed for bindgen."""

    # nb. The bindgen rule itself should work on any platform.
    _linux_rust_bindgen_repositories()

    maybe(
        _local_libstdcpp,
        name = "local_libstdcpp",
    )

    rules_rust_bindgen_fetch_remote_crates()

    native.register_toolchains("@io_bazel_rules_rust//bindgen:example-bindgen-toolchain")

def _linux_rust_bindgen_repositories():
    # Releases @ http://releases.llvm.org/download.html
    maybe(
        http_archive,
        name = "bindgen_clang",
        urls = ["http://releases.llvm.org/7.0.1/clang+llvm-7.0.1-x86_64-linux-gnu-ubuntu-18.04.tar.xz"],
        strip_prefix = "clang+llvm-7.0.1-x86_64-linux-gnu-ubuntu-18.04",
        sha256 = "e74ce06d99ed9ce42898e22d2a966f71ae785bdf4edbded93e628d696858921a",
        build_file = Label("//bindgen:clang.BUILD"),
    )

LIBSTDCPP_LINUX = """
cc_library(
  name = "libstdc++",
  srcs = ["libstdc++.so.6"],
  visibility = ["//visibility:public"]
)
"""

LIBSTDCPP_MAC = """
cc_library(
    name = "libstdc++",
    srcs = ["libstdc++.6.dylib"],
    visibility = ["//visibility:public"]
)
"""

def _local_libstdcpp_impl(repository_ctx):
    os = repository_ctx.os.name.lower()
    if os == "linux":
        repository_ctx.symlink("/usr/lib/x86_64-linux-gnu/libstdc++.so.6", "libstdc++.so.6")
        repository_ctx.file("BUILD.bazel", LIBSTDCPP_LINUX)
    elif os.startswith("mac"):
        repository_ctx.symlink("/usr/lib/libstdc++.6.dylib", "libstdc++.6.dylib")
        repository_ctx.file("BUILD.bazel", LIBSTDCPP_MAC)
    else:
        fail(os + " is not supported.")

_local_libstdcpp = repository_rule(
    implementation = _local_libstdcpp_impl,
)

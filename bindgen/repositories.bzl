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

# buildifier: disable=module-docstring
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//bindgen/raze:crates.bzl", "rules_rust_bindgen_fetch_remote_crates")

# buildifier: disable=unnamed-macro
def rust_bindgen_repositories():
    """Declare dependencies needed for bindgen."""

    # nb. The bindgen rule itself should work on any platform.
    _bindgen_clang_repositories()

    rules_rust_bindgen_fetch_remote_crates()

    native.register_toolchains(str(Label("//bindgen:default_bindgen_toolchain")))

_COMMON_WORKSPACE = """\
workspace(name = "{}")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_cc",
    url = "https://github.com/bazelbuild/rules_cc/archive/624b5d59dfb45672d4239422fa1e3de1822ee110.zip",
    sha256 = "8c7e8bf24a2bf515713445199a677ee2336e1c487fa1da41037c6026de04bbc3",
    strip_prefix = "rules_cc-624b5d59dfb45672d4239422fa1e3de1822ee110",
    type = "zip",
)
"""

_CLANG_BUILD_FILE = """\
load("@rules_cc//cc:defs.bzl", "cc_import")

package(default_visibility = ["//visibility:public"])

sh_binary(
    name = "clang",
    srcs = ["bin/clang"],
)

cc_import(
    name = "libclang",
    shared_library = "lib/libclang.{suffix}",
)

alias(
    name = "libclang.so",
    actual = ":libclang",
    deprecation = "Use :libclang instead",
)

cc_import(
    name = "libc++",
    shared_library = "lib/libc++.{suffix}"
)
"""

def _bindgen_clang_repositories():
    # Releases @ http://releases.llvm.org/download.html
    maybe(
        http_archive,
        name = "bindgen_clang_linux",
        urls = ["https://github.com/llvm/llvm-project/releases/download/llvmorg-10.0.0/clang+llvm-10.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz"],
        strip_prefix = "clang+llvm-10.0.0-x86_64-linux-gnu-ubuntu-18.04",
        sha256 = "b25f592a0c00686f03e3b7db68ca6dc87418f681f4ead4df4745a01d9be63843",
        build_file_content = _CLANG_BUILD_FILE.format(suffix = "so"),
        workspace_file_content = _COMMON_WORKSPACE.format("bindgen_clang_linux"),
    )

    maybe(
        http_archive,
        name = "bindgen_clang_osx",
        urls = ["https://github.com/llvm/llvm-project/releases/download/llvmorg-10.0.0/clang+llvm-10.0.0-x86_64-apple-darwin.tar.xz"],
        strip_prefix = "clang+llvm-10.0.0-x86_64-apple-darwin",
        sha256 = "633a833396bf2276094c126b072d52b59aca6249e7ce8eae14c728016edb5e61",
        build_file_content = _CLANG_BUILD_FILE.format(suffix = "dylib"),
        workspace_file_content = _COMMON_WORKSPACE.format("bindgen_clang_osx"),
    )

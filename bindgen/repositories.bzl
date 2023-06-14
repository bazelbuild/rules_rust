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

"""Dependencies for the Rust `bindgen` rules"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//bindgen/3rdparty/crates:defs.bzl", "crate_repositories")

BINDGEN_VERSION = "0.65.1"

# buildifier: disable=unnamed-macro
def rust_bindgen_dependencies():
    """Declare dependencies needed for bindgen."""

    maybe(
        http_archive,
        name = "llvm-raw",
        urls = ["https://github.com/llvm/llvm-project/releases/download/llvmorg-14.0.6/llvm-project-14.0.6.src.tar.xz"],
        strip_prefix = "llvm-project-14.0.6.src",
        sha256 = "8b3cfd7bc695bd6cea0f37f53f0981f34f87496e79e2529874fd03a2f9dd3a8a",
        build_file_content = "# empty",
        patch_args = ["-p1"],
        patches = [
            Label("//bindgen/3rdparty/patches:llvm-project.cxx17.patch"),
            Label("//bindgen/3rdparty/patches:llvm-project.incompatible_disallow_empty_glob.patch"),
        ],
    )

    maybe(
        http_archive,
        name = "rules_rust_bindgen__bindgen-cli-{}".format(BINDGEN_VERSION),
        sha256 = "33373a4e0ec8b6fa2654e0c941ad16631b0d564cfd20e7e4b3db4c5b28f4a237",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/bindgen-cli/{}/download".format(BINDGEN_VERSION)],
        strip_prefix = "bindgen-cli-{}".format(BINDGEN_VERSION),
        build_file = Label("//bindgen/3rdparty:BUILD.bindgen-cli.bazel"),
    )

    crate_repositories()

# buildifier: disable=unnamed-macro
def rust_bindgen_register_toolchains(register_toolchains = True):
    """Registers the default toolchains for the `rules_rust` [bindgen][bg] rules.

    [bg]: https://rust-lang.github.io/rust-bindgen/

    Args:
        register_toolchains (bool, optional): Whether or not to register toolchains.
    """
    if register_toolchains:
        native.register_toolchains(str(Label("//bindgen:default_bindgen_toolchain")))

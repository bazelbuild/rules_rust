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
load("//wasm_bindgen/raze:crates.bzl", "rules_rust_wasm_bindgen_fetch_remote_crates")

# buildifier: disable=unnamed-macro
def rust_wasm_bindgen_repositories(register_default_toolchain = True):
    """Declare dependencies needed for [rust_wasm_bindgen](#rust_wasm_bindgen).

    Args:
        register_default_toolchain (Label, optional): If True, the default [rust_wasm_bindgen_toolchain](#rust_wasm_bindgen_toolchain)
            (`@rules_rust//wasm_bindgen:default_wasm_bindgen_toolchain`) is registered. This toolchain requires a set of dependencies
            that were generated using [cargo raze](https://github.com/google/cargo-raze). These will also be loaded.
    """

    maybe(
        http_archive,
        name = "build_bazel_rules_nodejs",
        sha256 = "55a25a762fcf9c9b88ab54436581e671bc9f4f523cb5a1bd32459ebec7be68a8",
        urls = ["https://github.com/bazelbuild/rules_nodejs/releases/download/3.2.2/rules_nodejs-3.2.2.tar.gz"],
    )

    # Load dependencies of the default toolchain and register it.
    if register_default_toolchain:
        rules_rust_wasm_bindgen_fetch_remote_crates()
        native.register_toolchains(str(Label("//wasm_bindgen:default_wasm_bindgen_toolchain")))

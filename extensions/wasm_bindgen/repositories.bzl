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

"""Dependency definitions for wasm-bindgen rules"""

load("//3rdparty/crates:crates.bzl", "crate_repositories")
load("//private/webdrivers:webdriver_repositories.bzl", "webdriver_repositories")

WASM_BINDGEN_VERSION = "0.2.105"

# buildifier: disable=unnamed-macro
def rust_wasm_bindgen_dependencies():
    """Declare dependencies needed for the `rules_rust` [wasm-bindgen][wb] rules.

    [wb]: https://github.com/rustwasm/wasm-bindgen

    Returns:
        list[struct(repo=str, is_dev_dep=bool)]: A list of the repositories
        defined by this macro.
    """

    direct_deps = []

    direct_deps.extend(crate_repositories())
    direct_deps.extend(webdriver_repositories())
    return direct_deps

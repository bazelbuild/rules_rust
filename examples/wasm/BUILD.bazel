# Copyright 2020 The Bazel Authors. All rights reserved.
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
load("@io_bazel_rules_rust//rust:rust.bzl", "rust_binary")
load("@io_bazel_rules_rust//wasm_bindgen:wasm_bindgen.bzl", "rust_wasm_bindgen")
load("@build_bazel_rules_nodejs//:index.bzl", "nodejs_test")

package(default_visibility = ["//visibility:public"])

rust_binary(
    name = "hello_world_wasm",
    srcs = ["main.rs"],
    edition = "2018",
    deps = [
        "@io_bazel_rules_rust//wasm_bindgen/raze:wasm_bindgen",
    ],
)

rust_wasm_bindgen(
    name = "hello_world_wasm_bindgen",
    wasm_file = ":hello_world_wasm",
)

nodejs_test(
    name = "hello_world_wasm_test",
    data = [":hello_world_wasm_bindgen"],
    entry_point = "hello_world_wasm_test.js",
)

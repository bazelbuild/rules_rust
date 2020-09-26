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

"""This module contains defines helper macros for the cbindgen examples"""

load("@examples//ffi/rust_calling_c/raze:crates.bzl", "rules_rust_examples_ffi_rust_calling_c_fetch_remote_crates")

def ffi_examples_fetch_remote_crates():
    rules_rust_examples_ffi_rust_calling_c_fetch_remote_crates()
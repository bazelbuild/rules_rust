# Copyright 2015 The Bazel Authors. All rights reserved.
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

"""Module with Rust definitions required to write custom Rust rules."""

CrateInfo = provider(
    doc = "A provider containing general Crate information.",
    fields = {
        "aliases": "Dict[Label, String]: Renamed and aliased crates",
        "deps": "List[Provider]: This crate's (rust or cc) dependencies' providers.",
        "edition": "str: The edition of this crate.",
        "is_test": "bool: If the crate is being compiled in a test context",
        "name": "str: The name of this crate.",
        "output": "File: The output File that will be produced, depends on crate type.",
        "proc_macro_deps": "List[CrateInfo]: This crate's rust proc_macro dependencies' providers.",
        "root": "File: The source File entrypoint to this crate, eg. lib.rs",
        "rustc_env": "Dict[String, String]: Additional `\"key\": \"value\"` environment variables to set for rustc.",
        "srcs": "List[File]: All source Files that are part of the crate.",
        "type": "str: The type of this crate. eg. lib or bin",
    },
)

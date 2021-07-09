# Copyright 2021 The Bazel Authors. All rights reserved.
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

"""Module containing definitions of all Rust providers."""

CrateInfo = provider(
    doc = "A provider containing general Crate information.",
    fields = {
        "aliases": "Dict[Label, String]: Renamed and aliased crates",
        "deps": "depset[Provider]: This crate's (rust or cc) dependencies' providers.",
        "edition": "str: The edition of this crate.",
        "is_test": "bool: If the crate is being compiled in a test context",
        "name": "str: The name of this crate.",
        "output": "File: The output File that will be produced, depends on crate type.",
        "proc_macro_deps": "depset[CrateInfo]: This crate's rust proc_macro dependencies' providers.",
        "root": "File: The source File entrypoint to this crate, eg. lib.rs",
        "rustc_env": "Dict[String, String]: Additional `\"key\": \"value\"` environment variables to set for rustc.",
        "srcs": "depset[File]: All source Files that are part of the crate.",
        "type": "str: The type of this crate. eg. lib or bin",
        "wrapped_crate_type": (
            "str, optional: The original crate type for targets generated using a previously defined " +
            "crate (typically tests using the `rust_test::crate` attribute)"
        ),
    },
)

DepInfo = provider(
    doc = "A provider containing information about a Crate's dependencies.",
    fields = {
        "dep_env": "File: File with environment variables direct dependencies build scripts rely upon.",
        "direct_crates": "depset[CrateInfo]",
        "transitive_build_infos": "depset[BuildInfo]",
        "transitive_crates": "depset[CrateInfo]",
        "transitive_libs": "List[File]: All transitive dependencies, not filtered by type.",
        "transitive_noncrates": "depset[LinkerInput]: All transitive dependencies that aren't crates.",
    },
)

StdLibInfo = provider(
    doc = (
        "A collection of files either found within the `rust-stdlib` artifact or " +
        "generated based on existing files."
    ),
    fields = {
        "alloc_files": "List[File]: `.a` files related to the `alloc` module.",
        "between_alloc_and_core_files": "List[File]: `.a` files related to the `compiler_builtins` module.",
        "between_core_and_std_files": "List[File]: `.a` files related to all modules except `adler`, `alloc`, `compiler_builtins`, `core`, and `std`.",
        "core_files": "List[File]: `.a` files related to the `core` and `adler` modules",
        "dot_a_files": "Depset[File]: Generated `.a` files",
        "self_contained_files": "List[File]: All `.o` files from the `self-contained` directory.",
        "srcs": "List[Target]: The original `src` attribute.",
        "std_files": "Depset[File]: `.a` files associated with the `std` module.",
        "std_rlibs": "List[File]: All `.rlib` files",
    },
)

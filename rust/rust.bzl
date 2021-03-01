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

"""Deprecated, please use //rust:defs.bzl."""

load(
    "//rust:defs.bzl",
    _error_format = "error_format",
    _rust_analyzer = "rust_analyzer",
    _rust_analyzer_aspect = "rust_analyzer_aspect",
    _rust_benchmark = "rust_benchmark",
    _rust_binary = "rust_binary",
    _rust_clippy = "rust_clippy",
    _rust_clippy_aspect = "rust_clippy_aspect",
    _rust_common = "rust_common",
    _rust_doc = "rust_doc",
    _rust_doc_test = "rust_doc_test",
    _rust_library = "rust_library",
    _rust_proc_macro = "rust_proc_macro",
    _rust_shared_library = "rust_shared_library",
    _rust_static_library = "rust_static_library",
    _rust_test = "rust_test",
    _rust_test_binary = "rust_test_binary",
)

def rust_library(**args):
    """Deprecated. Use the version from "@rules_rust//rust:defs.bzl" instead.

    Args:
        **args: args to pass to the relevant rule.

    Returns:
        a target.
    """
    if "crate_type" in args:
        crate_type = args.pop("crate_type")
        if crate_type in ["lib", "rlib", "dylib"]:
            return _rust_library(**args)
        elif crate_type == "cdylib":
            return _rust_shared_library(**args)
        elif crate_type == "staticlib":
            return _rust_static_library(**args)
        elif crate_type == "proc-macro":
            return _rust_proc_macro(**args)
        else:
            fail("Unexpected crate_type: " + crate_type)
    else:
        return _rust_library(**args)

rust_binary = _rust_binary
# See @rules_rust//rust/private:rust.bzl for a complete description.

rust_test = _rust_test
# See @rules_rust//rust/private:rust.bzl for a complete description.

rust_test_binary = _rust_test_binary
# See @rules_rust//rust/private:rust.bzl for a complete description.

rust_benchmark = _rust_benchmark
# See @rules_rust//rust/private:rust.bzl for a complete description.

rust_doc = _rust_doc
# See @rules_rust//rust/private:rustdoc.bzl for a complete description.

rust_doc_test = _rust_doc_test
# See @rules_rust//rust/private:rustdoc_test.bzl for a complete description.

rust_clippy_aspect = _rust_clippy_aspect
# See @rules_rust//rust/private:clippy.bzl for a complete description.

rust_clippy = _rust_clippy
# See @rules_rust//rust:private/clippy.bzl for a complete description.

rust_analyzer_aspect = _rust_analyzer_aspect
# See @rules_rust//rust:private/rust_analyzer.bzl for a complete description.

rust_analyzer = _rust_analyzer
# See @rules_rust//rust:private/rust_analyzer.bzl for a complete description.

error_format = _error_format
# See @rules_rust//rust/private:rustc.bzl for a complete description.

rust_common = _rust_common
# See @rules_rust//rust/private:common.bzl for a complete description.

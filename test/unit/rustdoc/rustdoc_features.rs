// Copyright 2022 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#![cfg_attr(not(no_feature_test), deny(rustdoc::broken_intra_doc_links))]
#![cfg_attr(no_feature_test, allow(rustdoc::broken_intra_doc_links))]

//!
//! Checkout [inc]
//!

#[cfg(all(no_feature_test, feature = "docs"))]
compiler_error!("cannot have both no_feature_test and feature=\"docs\" enabled");

/// Increments the input.
#[cfg(feature = "docs")]
pub fn inc(n: u32) -> u32 {
    n + 1
}

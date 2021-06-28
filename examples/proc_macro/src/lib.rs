// Copyright 2020 The Bazel Authors. All rights reserved.
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

// This differs from the edition 2015 version because it does not have an `extern proc_macro`
// statement, which became optional in edition 2018.

use proc_macro::TokenStream;

/// This macro is a no-op; it is exceedingly simple as a result
/// of avoiding dependencies on both the syn and quote crates.
#[proc_macro_derive(HelloWorld)]
pub fn hello_world(_input: TokenStream) -> TokenStream {
    TokenStream::new()
}

// Copyright 2015 The Bazel Authors. All rights reserved.
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

extern crate hello_lib;

use hello_lib::greeter;

// Include the message generated at compile-time.
const MSG: &str = include_str!(concat!(env!("BAZEL_GENFILES_DIR"),
    "/external/examples/hello_world/message.string"));

fn main() {
    let hello = greeter::Greeter::new("Hello");
    hello.greet(MSG);
}

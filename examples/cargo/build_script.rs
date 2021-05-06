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
use std::env;
use std::fs::File;
use std::io::prelude::*;

fn main() {
    let bleh = env::var("CARGO_FEATURE_BLEH").unwrap();
    let some_env = env::var("SOME_ENV").unwrap();
    let out_dir = env::var("OUT_DIR").unwrap();
    let data = std::fs::read("test.txt").unwrap();
    assert!(!bleh.is_empty());
    assert_eq!(some_env, "42");
    println!(
        r#"cargo:rustc-env=FOO=BAR
cargo:rustc-env=BAR=FOO
cargo:rustc-flags=--cfg=blah="bleh"
cargo:rustc-flags=--cfg=data="{}"
cargo:rustc-cfg=foobar"#,
        std::str::from_utf8(&data).unwrap()
    );
    let mut file = File::create(format!("{}/hello.world.txt", out_dir)).unwrap();
    file.write_all(b"Hello, world!").unwrap();
}

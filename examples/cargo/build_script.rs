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
use std::io::prelude::*;
use std::fs::File;
use std::env;

fn main() {
    let bleh = env::var("CARGO_FEATURE_BLEH");
    let out_dir = env::var("OUT_DIR");
    assert!(bleh.is_ok());
    assert!(out_dir.is_ok());
    assert!(!bleh.unwrap().is_empty());
    println!(r#"cargo:rustc-env=FOO=BAR
cargo:rustc-env=BAR=FOO
cargo:rustc-flags=--cfg=blah="bleh"
cargo:rustc-cfg=foobar"#);
    assert!(true);
    let mut file = File::create(format!("{}/hello.world.txt", out_dir.unwrap())).unwrap();
    file.write_all(b"Hello, world!").unwrap();
}
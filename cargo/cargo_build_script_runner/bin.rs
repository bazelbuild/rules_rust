// Copyright 2018 The Bazel Authors. All rights reserved.
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

// A simple wrapper around a build_script execution to generate file to reuse
// by rust_library/rust_binary.
extern crate cargo_build_script_output_parser;

use cargo_build_script_output_parser::BuildScriptOutput;
use std::env;
use std::fs::File;
use std::io::Write;
use std::process::{exit, Command};

fn main() {
    let mut args = env::args().skip(1);
    match (args.next(), args.next(), args.next()) {
        (Some(progname), Some(envfile), Some(flagfile)) => {
            let output = BuildScriptOutput::from_command(Command::new(progname).args(args));
            let mut f =
                File::create(&envfile).expect(&format!("Unable to create file {}", envfile));
            f.write_all(BuildScriptOutput::to_env(&output).as_bytes())
                .expect(&format!("Unable to write file {}", envfile));
            let mut f =
                File::create(&flagfile).expect(&format!("Unable to create file {}", flagfile));
            f.write_all(BuildScriptOutput::to_flags(&output).as_bytes())
                .expect(&format!("Unable to write file {}", flagfile));
        }
        _ => {
            eprintln!("Usage: $0 progname envfile flagfile [arg1...argn]");
            exit(1);
        }
    }
}

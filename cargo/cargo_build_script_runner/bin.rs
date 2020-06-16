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
use std::fs::{File, create_dir_all};
use std::io::Write;
use std::path::Path;
use std::process::{exit, Command};

fn main() {
    // We use exec_root.join rather than std::fs::canonicalize, to avoid resolving symlinks, as
    // some execution strategies and remote execution environments may use symlinks in ways which
    // canonicalizing them may break them, e.g. by having input files be symlinks into a /cas
    // directory - resolving these may cause tools which inspect $0, or try to resolve files
    // relative to themselves, to fail.
    let exec_root = env::current_dir().expect("Failed to get current directory");

    let mut args = env::args().skip(1);
    let manifest_dir_env = env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR was not set");
    let out_dir_env = env::var("OUT_DIR").expect("OUT_DIR was not set");
    // For some reason RBE does not creat the output directory, force create it
    create_dir_all(out_dir_env.clone()).expect(&format!("Failed to create OUT_DIR: {}", out_dir_env));
    let rustc_env = env::var("RUSTC").expect("RUSTC was not set");
    // Because of the Bazel's sandbox, bazel cannot provide full path, convert all relative path to correct path.
    let manifest_dir = exec_root.join(&manifest_dir_env);
    let out_dir = exec_root.join(&out_dir_env);
    let rustc = exec_root.join(&rustc_env);

    let cc = env::var_os("CC").map(|env_var| {
        let cc_path = Path::new(&env_var);
        if cc_path.is_relative() {
            exec_root.join(cc_path).into_os_string()
        } else {
            env_var
        }
    });

    match (args.next(), args.next(), args.next(), args.next(), args.next()) {
        (Some(progname), Some(crate_name), Some(envfile), Some(flagfile), Some(depenvfile)) => {
            let mut command = Command::new(exec_root.join(&progname));
            command
                .args(args)
                .current_dir(manifest_dir.clone())
                .env("OUT_DIR", out_dir)
                .env("CARGO_MANIFEST_DIR", manifest_dir)
                .env("RUSTC", rustc);

            if let Some(cc) = cc {
                command.env("CC", cc);
            }

            let output = BuildScriptOutput::from_command(&mut command);
            let mut f =
                File::create(&envfile).expect(&format!("Unable to create file {}", envfile));
            f.write_all(BuildScriptOutput::to_env(&output).as_bytes())
                .expect(&format!("Unable to write file {}", envfile));
            let mut f =
                File::create(&depenvfile).expect(&format!("Unable to create file {}", depenvfile));
            f.write_all(BuildScriptOutput::to_dep_env(&output, &crate_name).as_bytes())
                .expect(&format!("Unable to write file {}", depenvfile));
            let mut f =
                File::create(&flagfile).expect(&format!("Unable to create file {}", flagfile));
            f.write_all(BuildScriptOutput::to_flags(&output).as_bytes())
                .expect(&format!("Unable to write file {}", flagfile));
        }
        _ => {
            eprintln!("Usage: $0 progname crate_name envfile flagfile depenvfile [arg1...argn]");
            exit(1);
        }
    }
}

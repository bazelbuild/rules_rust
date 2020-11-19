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

use cargo_build_script_output_parser::{BuildScriptOutput, CompileAndLinkFlags};
use std::collections::BTreeMap;
use std::env;
use std::ffi::OsString;
use std::fs::{create_dir_all, read_to_string, write};
use std::path::Path;
use std::process::Command;

fn main() -> Result<(), String> {
    // We use exec_root.join rather than std::fs::canonicalize, to avoid resolving symlinks, as
    // some execution strategies and remote execution environments may use symlinks in ways which
    // canonicalizing them may break them, e.g. by having input files be symlinks into a /cas
    // directory - resolving these may cause tools which inspect $0, or try to resolve files
    // relative to themselves, to fail.
    let exec_root = env::current_dir().expect("Failed to get current directory");

    let mut args = env::args().skip(1);
    let manifest_dir_env = env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR was not set");
    let rustc_env = env::var("RUSTC").expect("RUSTC was not set");
    let manifest_dir = exec_root.join(&manifest_dir_env);
    let rustc = exec_root.join(&rustc_env);

    // TODO: we should consider an alternative to positional arguments.
    match (args.next(), args.next(), args.next(), args.next(), args.next(), args.next(), args.next(), args.next()) {
        (Some(progname), Some(crate_name), Some(crate_links), Some(out_dir), Some(envfile), Some(flagfile), Some(linkflags), Some(depenvfile)) => {
            let out_dir_abs = exec_root.join(&out_dir);
            // For some reason Google's RBE does not create the output directory, force create it.
            create_dir_all(&out_dir_abs).expect(&format!("Failed to make output directory: {:?}", out_dir_abs));

            let target_env_vars = get_target_env_vars(&rustc_env).expect("Error getting target env vars from rustc");

            let mut command = Command::new(exec_root.join(&progname));
            command
                .current_dir(&manifest_dir)
                .envs(target_env_vars)
                .env("OUT_DIR", out_dir_abs)
                .env("CARGO_MANIFEST_DIR", manifest_dir)
                .env("RUSTC", rustc)
                .env("RUST_BACKTRACE", "full");

            while let Some(dep_env_path) = args.next() {
                if let Ok(contents) = read_to_string(dep_env_path) {
                    for line in contents.split('\n') {
                        // split on empty contents will still produce a single empty string in iterable.
                        if line.is_empty() {
                            continue;
                        }
                        let mut key_val = line.splitn(2, '=');
                        match (key_val.next(), key_val.next()) {
                            (Some(key), Some(value)) => {
                                command.env(key, value.replace("${pwd}", &exec_root.to_string_lossy()));
                            }
                            _ => {
                                return Err("error: Wrong environment file format, should not happen".to_owned())
                            }
                        }
                    }
                } else {
                    return Err("error: Dependency environment file unreadable".to_owned())
                }
            }

            if let Some(cc_path) = env::var_os("CC") {
                command.env("CC", absolutify(&exec_root, cc_path));
            }

            if let Some(ar_path) = env::var_os("AR") {
                // The default OSX toolchain uses libtool as ar_executable not ar.
                // This doesn't work when used as $AR, so simply don't set it - tools will probably fall back to
                // /usr/bin/ar which is probably good enough.
                if Path::new(&ar_path).file_name() == Some("libtool".as_ref()) {
                    command.env_remove("AR");
                } else {
                    command.env("AR", absolutify(&exec_root, ar_path));
                }
            }

            // replace env vars with a ${pwd} prefix with the exec_root
            for (key, value) in env::vars() {
                let exec_root_str = exec_root.to_str().expect("exec_root not in utf8");
                if value.contains("${pwd}") {
                    env::set_var(key, value.replace("${pwd}", exec_root_str));
                }
            }


            let output = BuildScriptOutput::from_command(&mut command).map_err(|exit_code| {
                format!(
                    "Build script process failed{}",
                    if let Some(exit_code) = exit_code {
                        format!(" with exit code {}", exit_code)
                    } else {
                        String::new()
                    }
                )
            })?;

            // The right way to set the dep env var is to use the links attribute from the
            // Cargo.toml, but cargo_build_script didn't used to have a `links` attribute, so for
            // backward-compatibility reasons, try to infer it from the name of the crate.
            // TODO: remove this backward-compatibility fallback in next major version.
            let crate_links = match crate_links.as_ref() {
                "" => {
                    const SYS_CRATE_SUFFIX: &str = "-sys";
                    if crate_name.ends_with(SYS_CRATE_SUFFIX) {
                        crate_name
                            .split_at(crate_name.rfind(SYS_CRATE_SUFFIX).unwrap())
                            .0
                    } else {
                        &crate_name
                    }
                },
                crate_links => crate_links,
            };

            write(&envfile, BuildScriptOutput::to_env(&output, &exec_root.to_string_lossy()).as_bytes())
                .expect(&format!("Unable to write file {:?}", envfile));
            write(&depenvfile, BuildScriptOutput::to_dep_env(&output, crate_links, &exec_root.to_string_lossy()).as_bytes())
                .expect(&format!("Unable to write file {:?}", depenvfile));

            let CompileAndLinkFlags { compile_flags, link_flags } = BuildScriptOutput::to_flags(&output, &exec_root.to_string_lossy());

            write(&flagfile, compile_flags.as_bytes())
                .expect(&format!("Unable to write file {:?}", flagfile));
            write(&linkflags, link_flags.as_bytes())
                .expect(&format!("Unable to write file {:?}", linkflags));
            Ok(())
        }
        _ => {
            Err("Usage: $0 progname crate_name out_dir envfile flagfile linkflagfile depenvfile [arg1...argn]".to_owned())
        }
    }
}

fn get_target_env_vars<P: AsRef<Path>>(rustc: &P) -> Result<BTreeMap<String, String>, String> {
    // As done by Cargo when constructing a cargo::core::compiler::build_context::target_info::TargetInfo.
    let output = Command::new(rustc.as_ref())
        .arg("--print=cfg")
        .arg(format!(
            "--target={}",
            env::var("TARGET").expect("missing TARGET")
        ))
        .output()
        .map_err(|err| format!("Error running rustc to get target information: {}", err))?;
    if !output.status.success() {
        return Err(format!(
            "Error running rustc to get target information: {:?}",
            output
        ));
    }
    let stdout = std::str::from_utf8(&output.stdout)
        .map_err(|err| format!("Non-UTF8 stdout from rustc: {:?}", err))?;

    let mut values = BTreeMap::new();

    for line in stdout.lines() {
        if line.starts_with("target_") && line.contains('=') {
            let mut parts = line.splitn(2, '=');
            // UNWRAP: Verified that line contains = and split into exactly 2 parts.
            let key = parts.next().unwrap();
            let value = parts.next().unwrap();
            if value.starts_with('"') && value.ends_with('"') && value.len() >= 2 {
                values
                    .entry(key)
                    .or_insert(vec![])
                    .push(value[1..(value.len() - 1)].to_owned());
            }
        }
    }

    Ok(values
        .into_iter()
        .map(|(key, value)| (format!("CARGO_CFG_{}", key.to_uppercase()), value.join(",")))
        .collect())
}

fn absolutify(root: &Path, maybe_relative: OsString) -> OsString {
    let path = Path::new(&maybe_relative);
    if path.is_relative() {
        root.join(path).into_os_string()
    } else {
        maybe_relative
    }
}

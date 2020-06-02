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

//! Parse the output of a cargo build.rs script and generate a list of flags and
//! environment variable for the build.
use std::io::{BufRead, BufReader, Read};
use std::process::{Command, Stdio};

/// Enum containing all the considered return value from the script
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BuildScriptOutput {
    /// cargo:rustc-link-lib
    LinkLib(String),
    /// cargo:rustc-link-search
    LinkSearch(String),
    /// cargo:rustc-cfg
    Cfg(String),
    /// cargo:rustc-flags
    Flags(String),
    /// cargo:rustc-env
    Env(String),
}

impl BuildScriptOutput {
    /// Converts a line into a [BuildScriptOutput] enum.
    ///
    /// Examples
    /// ```rust
    /// assert_eq!(BuildScriptOutput::new("cargo:rustc-link-lib=lib"), Some(BuildScriptOutput::LinkLib("lib".to_owned())));
    /// ```
    fn new(line: &str) -> Option<BuildScriptOutput> {
        let split = line.splitn(2, '=').collect::<Vec<_>>();
        if split.len() <= 1 {
            return None;
        }
        let param = split[1].trim().to_owned();
        match split[0] {
            "cargo:rustc-link-lib" => Some(BuildScriptOutput::LinkLib(param)),
            "cargo:rustc-link-search" => Some(BuildScriptOutput::LinkSearch(param)),
            "cargo:rustc-cfg" => Some(BuildScriptOutput::Cfg(param)),
            "cargo:rustc-flags" => Some(BuildScriptOutput::Flags(param)),
            "cargo:rustc-env" => Some(BuildScriptOutput::Env(param)),
            "cargo:rerun-if-changed" | "cargo:rerun-if-env-changed" =>
                // Ignored because Bazel will re-run if those change all the time.
                None,
            "cargo:warning" => {
                eprintln!("Build Script Warning: {}", split[1]);
                None
            },
            _ => {
                // Not yet supported:
                // cargo:KEY=VALUE — Metadata, used by links scripts.
                // cargo:rustc-cdylib-link-arg=FLAG — Passes custom flags to a linker for cdylib crates.
                eprintln!("Warning: build script returned unsupported directive `{}`", split[0]);
                None
            },
        }
    }

    /// Converts a [BufReader] into a vector of [BuildScriptOutput] enums.
    fn from_reader<T: Read>(mut reader: BufReader<T>) -> Vec<BuildScriptOutput> {
        let mut result = Vec::<BuildScriptOutput>::new();
        let mut line = String::new();
        while reader.read_line(&mut line).expect("Cannot read line") != 0 {
            if let Some(bso) = BuildScriptOutput::new(&line) {
                result.push(bso);
            }
            line.clear();
        }
        result
    }

    /// Take a [Command], execute it and converts its input into a vector of [BuildScriptOutput]
    pub fn from_command(cmd: &mut Command) -> Vec<BuildScriptOutput> {
        let mut child = cmd.stdout(Stdio::piped()).spawn().expect("Unable to start binary");
        let ecode = child.wait().expect("failed to wait on child");
        let reader = BufReader::new(
                child
                .stdout
                .as_mut()
                .expect("Failed to open stdout"),
            );
        assert!(ecode.success());
        Self::from_reader(reader)
    }

    /// Convert a vector of [BuildScriptOutput] into a list of environment variables.
    pub fn to_env(v: &Vec<BuildScriptOutput>) -> String {
        v.iter()
            .filter_map(|x| {
                if let BuildScriptOutput::Env(env) = x {
                    Some(env.to_owned())
                } else {
                    None
                }
            })
            .collect::<Vec<_>>()
            .join(" ")
    }

    /// Convert a vector of [BuildScriptOutput] into a flagfile.
    pub fn to_flags(v: &Vec<BuildScriptOutput>) -> String {
        v.iter()
            .filter_map(|x| match x {
                BuildScriptOutput::Cfg(e) => Some(format!("--cfg={}", e)),
                BuildScriptOutput::Flags(e) => Some(e.to_owned()),
                BuildScriptOutput::LinkLib(e) => Some(format!("-l{}", e)),
                BuildScriptOutput::LinkSearch(e) => Some(format!("-L{}", e)),
                _ => None,
            })
            .collect::<Vec<_>>()
            .join(" ")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    #[test]
    fn test_from_read_buffer_to_env_and_flags() {
        let buff = Cursor::new(
            "
cargo:rustc-link-lib=sdfsdf
cargo:rustc-env=FOO=BAR
cargo:rustc-link-search=bleh
cargo:rustc-env=BAR=FOO
cargo:rustc-flags=-Lblah
cargo:rerun-if-changed=ignored
cargo:rustc-cfg=feature=awesome
",
        );
        let reader = BufReader::new(buff);
        let result = BuildScriptOutput::from_reader(reader);
        assert_eq!(result.len(), 6);
        assert_eq!(result[0], BuildScriptOutput::LinkLib("sdfsdf".to_owned()));
        assert_eq!(result[1], BuildScriptOutput::Env("FOO=BAR".to_owned()));
        assert_eq!(result[2], BuildScriptOutput::LinkSearch("bleh".to_owned()));
        assert_eq!(result[3], BuildScriptOutput::Env("BAR=FOO".to_owned()));
        assert_eq!(result[4], BuildScriptOutput::Flags("-Lblah".to_owned()));
        assert_eq!(
            result[5],
            BuildScriptOutput::Cfg("feature=awesome".to_owned())
        );

        assert_eq!(
            BuildScriptOutput::to_env(&result),
            "FOO=BAR BAR=FOO".to_owned()
        );
        assert_eq!(
            BuildScriptOutput::to_flags(&result),
            "-lsdfsdf -Lbleh -Lblah --cfg=feature=awesome".to_owned()
        );
    }

}

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
    /// cargo:VAR=VALUE
    DepEnv(String),
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
        let key_split = split[0].splitn(2, ':').collect::<Vec<_>>();
        if key_split.len() <= 1 || key_split[0] != "cargo" {
            // Not a cargo directive.
            return None
        }
        match key_split[1] {
            "rustc-link-lib" => Some(BuildScriptOutput::LinkLib(param)),
            "rustc-link-search" => Some(BuildScriptOutput::LinkSearch(param)),
            "rustc-cfg" => Some(BuildScriptOutput::Cfg(param)),
            "rustc-flags" => Some(BuildScriptOutput::Flags(param)),
            "rustc-env" => Some(BuildScriptOutput::Env(param)),
            "rerun-if-changed" | "rerun-if-env-changed" =>
                // Ignored because Bazel will re-run if those change all the time.
                None,
            "warning" => {
                eprintln!("Build Script Warning: {}", split[1]);
                None
            },
            "rustc-cdylib-link-arg" => {
                // cargo:rustc-cdylib-link-arg=FLAG — Passes custom flags to a linker for cdylib crates.
                eprintln!("Warning: build script returned unsupported directive `{}`", split[0]);
                None
            },
            _ => {
                // cargo:KEY=VALUE — Metadata, used by links scripts.
                Some(BuildScriptOutput::DepEnv(format!("{}={}", key_split[1].to_uppercase(), param)))
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

    /// Convert a vector of [BuildScriptOutput] into a list of dependencies environment variables.
    pub fn to_dep_env(v: &Vec<BuildScriptOutput>, crate_name: &str) -> String {
        // TODO: make use of `strip_suffix`.
        const SYS_CRATE_SUFFIX: &str = "-sys";
        let name = if crate_name.ends_with(SYS_CRATE_SUFFIX) {
            crate_name.split_at(crate_name.rfind(SYS_CRATE_SUFFIX).unwrap()).0
        } else {
            crate_name
        };
        let prefix = format!("DEP_{}_", name.replace("-", "_").to_uppercase());
        v.iter()
            .filter_map(|x| {
                if let BuildScriptOutput::DepEnv(env) = x {
                    Some(format!("{}{}", prefix, env.to_owned()))
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
cargo:version=123
cargo:version_number=1010107f
",
        );
        let reader = BufReader::new(buff);
        let result = BuildScriptOutput::from_reader(reader);
        assert_eq!(result.len(), 8);
        assert_eq!(result[0], BuildScriptOutput::LinkLib("sdfsdf".to_owned()));
        assert_eq!(result[1], BuildScriptOutput::Env("FOO=BAR".to_owned()));
        assert_eq!(result[2], BuildScriptOutput::LinkSearch("bleh".to_owned()));
        assert_eq!(result[3], BuildScriptOutput::Env("BAR=FOO".to_owned()));
        assert_eq!(result[4], BuildScriptOutput::Flags("-Lblah".to_owned()));
        assert_eq!(
            result[5],
            BuildScriptOutput::Cfg("feature=awesome".to_owned())
        );
        assert_eq!(result[6], BuildScriptOutput::DepEnv("VERSION=123".to_owned()));
        assert_eq!(result[7], BuildScriptOutput::DepEnv("VERSION_NUMBER=1010107f".to_owned()));

        assert_eq!(
            BuildScriptOutput::to_dep_env(&result, "my-crate-sys"),
            "DEP_MY_CRATE_VERSION=123 DEP_MY_CRATE_VERSION_NUMBER=1010107f".to_owned()
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

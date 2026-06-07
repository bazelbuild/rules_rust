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
use std::path::Path;
use std::process::{Command, Output};

pub mod cargo_manifest_dir;

#[derive(Debug, PartialEq, Eq)]
pub struct CompileAndLinkFlags {
    pub compile_flags: String,
    pub link_flags: String,
    pub link_search_paths: String,
}

/// Enum containing all the considered return value from the script
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BuildScriptOutput {
    /// cargo::rustc-link-lib
    LinkLib(String),
    /// cargo::rustc-link-search
    LinkSearch(String),
    /// cargo::rustc-cfg
    Cfg(String),
    /// cargo::rustc-flags
    Flags(String),
    /// cargo::rustc-link-arg
    LinkArg(String),
    /// cargo::rustc-env
    Env(String),
    /// cargo::VAR=VALUE
    DepEnv(String),
}

impl BuildScriptOutput {
    pub fn nonhermetic_absolute_paths(
        outputs: &[BuildScriptOutput],
        exec_root: &str,
        out_dir: &str,
    ) -> Vec<String> {
        outputs
            .iter()
            .filter_map(|output| {
                let (directive, original_value, redacted_value) = match output {
                    BuildScriptOutput::LinkSearch(value) => (
                        "rustc-link-search",
                        value,
                        Self::redact_flags(value, exec_root, out_dir),
                    ),
                    BuildScriptOutput::Env(value) => (
                        "rustc-env",
                        value,
                        Self::redact_paths(value, exec_root, out_dir),
                    ),
                    BuildScriptOutput::DepEnv(value) => (
                        "metadata",
                        value,
                        Self::redact_paths(value, exec_root, out_dir),
                    ),
                    _ => return None,
                };
                let value = match output {
                    BuildScriptOutput::LinkSearch(_) => redacted_value
                        .split_once('=')
                        .map_or(redacted_value.as_str(), |(_, path)| path),
                    BuildScriptOutput::Env(_) | BuildScriptOutput::DepEnv(_) => redacted_value
                        .split_once('=')
                        .map_or("", |(_, value)| value),
                    _ => unreachable!(),
                };
                if Self::contains_absolute_path(value) {
                    Some(format!("cargo::{directive}={original_value}"))
                } else {
                    None
                }
            })
            .collect()
    }

    fn contains_absolute_path(value: &str) -> bool {
        let path_is_absolute = |candidate: &str| {
            let candidate = candidate.trim_matches(|character: char| {
                character.is_ascii_whitespace()
                    || matches!(character, '\'' | '"' | ',' | '(' | ')' | '[' | ']')
            });
            Path::new(candidate).is_absolute()
        };

        if path_is_absolute(value) {
            return true;
        }

        value
            .split(|character: char| character.is_ascii_whitespace() || character == ';')
            .any(|token| {
                if path_is_absolute(token) {
                    return true;
                }
                if token.contains("://") {
                    return false;
                }
                token.find(std::path::MAIN_SEPARATOR).is_some_and(|index| {
                    let prefix = &token[..index];
                    (prefix.starts_with('-') || prefix.ends_with('='))
                        && path_is_absolute(&token[index..])
                })
            })
    }

    /// Converts a line into a [BuildScriptOutput] enum.
    ///
    /// Examples
    /// ```rust
    /// assert_eq!(BuildScriptOutput::new("cargo::rustc-link-lib=lib"), Some(BuildScriptOutput::LinkLib("lib".to_owned())));
    /// ```
    fn new(line: &str) -> Option<BuildScriptOutput> {
        let split = line.splitn(2, '=').collect::<Vec<_>>();
        if split.len() <= 1 {
            // Not a cargo directive.
            return None;
        }
        let param = split[1].trim().to_owned();
        let cargo_instruction_name = {
            if split[0].starts_with("cargo::") {
                &split[0][7..]
            } else if split[0].starts_with("cargo:") {
                &split[0][6..]
            } else {
                // Not a cargo directive.
                return None;
            }
        };

        match cargo_instruction_name {
            "rustc-link-lib" => Some(BuildScriptOutput::LinkLib(param)),
            "rustc-link-search" => Some(BuildScriptOutput::LinkSearch(param)),
            "rustc-cfg" => Some(BuildScriptOutput::Cfg(param)),
            "rustc-flags" => Some(BuildScriptOutput::Flags(param)),
            "rustc-link-arg" => Some(BuildScriptOutput::LinkArg(param)),
            "rustc-env" => Some(BuildScriptOutput::Env(param)),
            "rerun-if-changed" | "rerun-if-env-changed" =>
            // Ignored because Bazel will re-run if those change all the time.
            {
                None
            }
            "warning" => {
                eprint!("Build Script Warning: {}", split[1]);
                None
            }
            "metadata" => {
                // cargo::metadata=KEY=VALUE is forwarded to dependents as
                // DEP_<links>_<KEY>=<VALUE> by Cargo.
                if let Some((key, value)) = param.split_once('=') {
                    Some(BuildScriptOutput::DepEnv(format!(
                        "{}={}",
                        key.to_uppercase().replace('-', "_"),
                        value.trim()
                    )))
                } else {
                    // Keep legacy behavior for malformed metadata payloads.
                    Some(BuildScriptOutput::DepEnv(format!("METADATA={}", param)))
                }
            }
            "rustc-cdylib-link-arg" | "rustc-link-arg-bin" | "rustc-link-arg-bins" => {
                // cargo::rustc-cdylib-link-arg=FLAG — Passes custom flags to a linker for cdylib crates.
                // cargo::rustc-link-arg-bin=BIN=FLAG – Passes custom flags to a linker for the binary BIN.
                // cargo::rustc-link-arg-bins=FLAG – Passes custom flags to a linker for binaries.
                eprint!(
                    "Warning: build script returned unsupported directive `{}`",
                    split[0]
                );
                None
            }
            _ => {
                // cargo::KEY=VALUE — Metadata, used by links scripts.
                Some(BuildScriptOutput::DepEnv(format!(
                    "{}={}",
                    cargo_instruction_name.to_uppercase().replace('-', "_"),
                    param
                )))
            }
        }
    }

    /// Converts a [BufReader] into a vector of [BuildScriptOutput] enums.
    fn outputs_from_reader<T: Read>(mut reader: BufReader<T>) -> Vec<BuildScriptOutput> {
        let mut result = Vec::<BuildScriptOutput>::new();
        let mut buf = Vec::new();
        while reader
            .read_until(b'\n', &mut buf)
            .expect("Cannot read line")
            != 0
        {
            // like cargo, ignore any lines that are not valid utf8
            if let Ok(line) = String::from_utf8(buf.clone()) {
                if let Some(bso) = BuildScriptOutput::new(&line) {
                    result.push(bso);
                }
            }
            buf.clear();
        }
        result
    }

    /// Take a [Command], execute it and converts its input into a vector of [BuildScriptOutput]
    pub fn outputs_from_command(
        cmd: &mut Command,
    ) -> Result<(Vec<BuildScriptOutput>, Output), Output> {
        let child_output = cmd
            .output()
            .unwrap_or_else(|e| panic!("Unable to start command:\n{:#?}\n{:?}", cmd, e));
        if child_output.status.success() {
            let reader = BufReader::new(child_output.stdout.as_slice());
            let output = Self::outputs_from_reader(reader);
            Ok((output, child_output))
        } else {
            Err(child_output)
        }
    }

    /// Convert a vector of [BuildScriptOutput] into a list of environment variables.
    pub fn outputs_to_env(outputs: &[BuildScriptOutput], exec_root: &str, out_dir: &str) -> String {
        outputs
            .iter()
            .filter_map(|x| {
                if let BuildScriptOutput::Env(env) = x {
                    Some(Self::escape_for_serializing(Self::redact_paths(
                        env, exec_root, out_dir,
                    )))
                } else {
                    None
                }
            })
            .collect::<Vec<_>>()
            .join("\n")
    }

    /// Convert a vector of [BuildScriptOutput] into a list of dependencies environment variables.
    pub fn outputs_to_dep_env(
        outputs: &[BuildScriptOutput],
        crate_links: &str,
        exec_root: &str,
        out_dir: &str,
    ) -> String {
        let prefix = format!("DEP_{}_", crate_links.replace('-', "_").to_uppercase());
        outputs
            .iter()
            .filter_map(|x| {
                if let BuildScriptOutput::DepEnv(env) = x {
                    Some(format!(
                        "{}{}",
                        prefix,
                        Self::escape_for_serializing(Self::redact_paths(env, exec_root, out_dir))
                    ))
                } else {
                    None
                }
            })
            .collect::<Vec<_>>()
            .join("\n")
    }

    /// Convert a vector of [BuildScriptOutput] into a flagfile.
    pub fn outputs_to_flags(
        outputs: &[BuildScriptOutput],
        exec_root: &str,
        out_dir: &str,
    ) -> CompileAndLinkFlags {
        let mut compile_flags = Vec::new();
        let mut link_flags = Vec::new();
        let mut link_search_paths = Vec::new();

        for flag in outputs {
            match flag {
                BuildScriptOutput::Cfg(e) => compile_flags.push(format!("--cfg={e}")),
                BuildScriptOutput::Flags(e) => compile_flags.push(e.to_owned()),
                BuildScriptOutput::LinkArg(e) => compile_flags.push(format!("-Clink-arg={e}")),
                BuildScriptOutput::LinkLib(e) => link_flags.push(format!("-l{e}")),
                BuildScriptOutput::LinkSearch(e) => link_search_paths.push(format!("-L{e}")),
                _ => {}
            }
        }

        CompileAndLinkFlags {
            compile_flags: compile_flags.join("\n"),
            link_flags: Self::redact_flags(&link_flags.join("\n"), exec_root, out_dir),
            link_search_paths: Self::redact_flags(
                &link_search_paths.join("\n"),
                exec_root,
                out_dir,
            ),
        }
    }

    fn redact_exec_root(value: &str, exec_root: &str) -> String {
        if exec_root.is_empty() {
            return value.to_owned();
        }
        if value == exec_root {
            return "${pwd}".to_owned();
        }

        value
            .replace(&format!("{exec_root}/"), "${pwd}/")
            .replace(&format!("{exec_root}\\"), "${pwd}\\")
    }

    /// Redact for env vars: uses the generic `${out_dir}` token, resolved
    /// by `process_wrapper`'s `--out-dir` flag. Safe because env files are
    /// only consumed by the target that directly owns the build script.
    fn redact_paths(value: &str, exec_root: &str, out_dir: &str) -> String {
        let with_pwd = Self::redact_exec_root(value, exec_root);
        if out_dir.is_empty() {
            with_pwd
        } else {
            with_pwd.replace(out_dir, "${out_dir}")
        }
    }

    /// Redact for flags (link flags, link search paths): uses the full
    /// `out_dir` relative path as the substitution key so each build
    /// script gets a unique token. This avoids collisions when flag files
    /// are consumed transitively by a target whose `--out-dir` points to
    /// a different build script. The corresponding `--subst` entries are
    /// added on the Starlark side for every transitive build info.
    fn redact_flags(value: &str, exec_root: &str, out_dir: &str) -> String {
        let with_pwd = Self::redact_exec_root(value, exec_root);
        if out_dir.is_empty() {
            with_pwd
        } else {
            with_pwd.replace(out_dir, &format!("${{{out_dir}}}"))
        }
    }

    // The process-wrapper treats trailing backslashes as escapes for following newlines.
    // If the env var ends with a backslash (and accordingly doesn't have a following newline),
    // escape it so that it doesn't get turned into a newline by the process-wrapper.
    //
    // Note that this code doesn't handle newlines in strings - that's because Cargo treats build
    // script output as single-line-oriented, so stops processing at the end of a line regardless.
    fn escape_for_serializing(mut value: String) -> String {
        if value.ends_with('\\') {
            value.push('\\');
        }
        value
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    fn from_read_buffer_to_env_and_flags_test_impl(buff: Cursor<&str>) {
        let reader = BufReader::new(buff);
        let result = BuildScriptOutput::outputs_from_reader(reader);
        assert_eq!(result.len(), 13);
        assert_eq!(result[0], BuildScriptOutput::LinkLib("sdfsdf".to_owned()));
        assert_eq!(result[1], BuildScriptOutput::Env("FOO=BAR".to_owned()));
        assert_eq!(
            result[2],
            BuildScriptOutput::LinkSearch("/some/absolute/path/bleh".to_owned())
        );
        assert_eq!(result[3], BuildScriptOutput::Env("BAR=FOO".to_owned()));
        assert_eq!(result[4], BuildScriptOutput::Flags("-Lblah".to_owned()));
        assert_eq!(
            result[5],
            BuildScriptOutput::Cfg("feature=awesome".to_owned())
        );
        assert_eq!(
            result[6],
            BuildScriptOutput::DepEnv("VERSION=123".to_owned())
        );
        assert_eq!(
            result[7],
            BuildScriptOutput::DepEnv("VERSION_NUMBER=1010107f".to_owned())
        );
        assert_eq!(
            result[9],
            BuildScriptOutput::Env("SOME_PATH=/some/absolute/path/beep".to_owned())
        );
        assert_eq!(
            result[10],
            BuildScriptOutput::LinkArg("-weak_framework".to_owned())
        );
        assert_eq!(result[11], BuildScriptOutput::LinkArg("Metal".to_owned()));
        assert_eq!(
            result[12],
            BuildScriptOutput::Env("no_trailing_newline=true".to_owned())
        );
        assert_eq!(
            BuildScriptOutput::outputs_to_dep_env(&result, "ssh2", "/some/absolute/path", ""),
            "DEP_SSH2_VERSION=123\nDEP_SSH2_VERSION_NUMBER=1010107f\nDEP_SSH2_INCLUDE_PATH=${pwd}/include".to_owned()
        );
        assert_eq!(
            BuildScriptOutput::outputs_to_env(&result, "/some/absolute/path", ""),
            "FOO=BAR\nBAR=FOO\nSOME_PATH=${pwd}/beep\nno_trailing_newline=true".to_owned()
        );
        assert_eq!(
            BuildScriptOutput::outputs_to_flags(&result, "/some/absolute/path", ""),
            CompileAndLinkFlags {
                // -Lblah was output as a rustc-flags, so even though it probably _should_ be a link
                // flag, we don't treat it like one.
                compile_flags:
                    "-Lblah\n--cfg=feature=awesome\n-Clink-arg=-weak_framework\n-Clink-arg=Metal"
                        .to_owned(),
                link_flags: "-lsdfsdf".to_owned(),
                link_search_paths: "-L${pwd}/bleh".to_owned(),
            }
        );
    }

    #[test]
    fn test_from_read_buffer_to_env_and_flags() {
        let buff = Cursor::new(
            "
cargo::rustc-link-lib=sdfsdf
cargo::rustc-env=FOO=BAR
cargo::rustc-link-search=/some/absolute/path/bleh
cargo::rustc-env=BAR=FOO
cargo::rustc-flags=-Lblah
cargo::rerun-if-changed=ignored
cargo::rustc-cfg=feature=awesome
cargo::version=123
cargo::version_number=1010107f
cargo::include_path=/some/absolute/path/include
cargo::rustc-env=SOME_PATH=/some/absolute/path/beep
cargo::rustc-link-arg=-weak_framework
cargo::rustc-link-arg=Metal
cargo::rustc-env=no_trailing_newline=true
non-cargo-prefixes::are-ignored=true
non-assignment-instructions-are-ignored",
        );
        from_read_buffer_to_env_and_flags_test_impl(buff);
    }

    /// Demonstrate that the old style single colon flags are all parsable
    #[test]
    fn test_legacy_from_read_buffer_to_env_and_flags() {
        let buff = Cursor::new(
            "
cargo:rustc-link-lib=sdfsdf
cargo:rustc-env=FOO=BAR
cargo:rustc-link-search=/some/absolute/path/bleh
cargo:rustc-env=BAR=FOO
cargo:rustc-flags=-Lblah
cargo:rerun-if-changed=ignored
cargo:rustc-cfg=feature=awesome
cargo:version=123
cargo:version_number=1010107f
cargo:include_path=/some/absolute/path/include
cargo:rustc-env=SOME_PATH=/some/absolute/path/beep
cargo:rustc-link-arg=-weak_framework
cargo:rustc-link-arg=Metal
cargo:rustc-env=no_trailing_newline=true
non-cargo-prefixes:are-ignored=true
non-assignment-instructions-are-ignored",
        );
        from_read_buffer_to_env_and_flags_test_impl(buff);
    }

    #[test]
    fn invalid_utf8() {
        let buff = Cursor::new(
            b"
cargo::rustc-env=valid1=1
cargo::rustc-env=invalid=\xc3\x28
cargo::rustc-env=valid2=2
",
        );
        let reader = BufReader::new(buff);
        let result = BuildScriptOutput::outputs_from_reader(reader);
        assert_eq!(result.len(), 2);
        assert_eq!(
            &BuildScriptOutput::outputs_to_env(&result, "/some/absolute/path", ""),
            "valid1=1\nvalid2=2"
        );
    }

    /// Demonstrate that the old style single colon flags are all parsable
    #[test]
    fn invalid_utf8_legacy() {
        let buff = Cursor::new(
            b"
cargo:rustc-env=valid1=1
cargo:rustc-env=invalid=\xc3\x28
cargo:rustc-env=valid2=2
",
        );
        let reader = BufReader::new(buff);
        let result = BuildScriptOutput::outputs_from_reader(reader);
        assert_eq!(result.len(), 2);
        assert_eq!(
            &BuildScriptOutput::outputs_to_env(&result, "/some/absolute/path", ""),
            "valid1=1\nvalid2=2"
        );
    }

    #[test]
    fn metadata_directive_maps_to_dep_env_key_value() {
        let reader = BufReader::new(Cursor::new("cargo::metadata=version_1_10_0=1\n"));
        let result = BuildScriptOutput::outputs_from_reader(reader);
        assert_eq!(
            result,
            vec![BuildScriptOutput::DepEnv("VERSION_1_10_0=1".to_owned())]
        );
    }

    /// Verify that a build-script-emitted env var that references the
    /// `out_dir` (e.g. `cargo::rustc-env=FOO=$OUT_DIR/bar`) is rewritten
    /// to use the `${out_dir}` substitution token. `process_wrapper`
    /// substitutes the token at action execution time using the value
    /// from its `--out-dir` arg, which is sourced from a `File`-typed
    /// `Args` entry on the rules_rust side and therefore picks up Bazel
    /// path mapping (`--experimental_output_paths=strip`) when the
    /// consumer Rustc action advertises `supports-path-mapping`.
    #[test]
    fn out_dir_in_env_value_is_redacted_to_substitution_token() {
        let buff = Cursor::new(
            "
cargo::rustc-env=FOO=/abs/exec_root/bazel-out/cfg/bin/_bs.out_dir/op.rs
cargo::rustc-env=BAR=/abs/exec_root/elsewhere/file.rs
",
        );
        let reader = BufReader::new(buff);
        let result = BuildScriptOutput::outputs_from_reader(reader);
        assert_eq!(
            BuildScriptOutput::outputs_to_env(
                &result,
                "/abs/exec_root",
                "bazel-out/cfg/bin/_bs.out_dir",
            ),
            "FOO=${pwd}/${out_dir}/op.rs\nBAR=${pwd}/elsewhere/file.rs"
        );
    }

    /// Link search paths use the full `out_dir` path as the substitution
    /// key so each build script gets a unique token. This avoids
    /// collisions when the flag file is consumed transitively by a target
    /// whose `--out-dir` points to a different build script.
    #[test]
    fn out_dir_in_flags_uses_full_path_as_substitution_key() {
        let buff = Cursor::new(
            "
cargo::rustc-link-search=/abs/exec_root/bazel-out/cfg/bin/pkg/_bs.out_dir
cargo::rustc-link-search=/abs/exec_root/other/path
",
        );
        let reader = BufReader::new(buff);
        let result = BuildScriptOutput::outputs_from_reader(reader);
        assert_eq!(
            BuildScriptOutput::outputs_to_flags(
                &result,
                "/abs/exec_root",
                "bazel-out/cfg/bin/pkg/_bs.out_dir",
            ),
            CompileAndLinkFlags {
                compile_flags: "".to_owned(),
                link_flags: "".to_owned(),
                link_search_paths:
                    "-L${pwd}/${bazel-out/cfg/bin/pkg/_bs.out_dir}\n-L${pwd}/other/path".to_owned(),
            }
        );
    }

    #[test]
    fn nonhermetic_absolute_paths_are_detected() {
        let outputs = vec![
            BuildScriptOutput::LinkSearch("relative/path".to_owned()),
            BuildScriptOutput::LinkSearch("native=/execroot/workspace/lib".to_owned()),
            BuildScriptOutput::LinkSearch("/execroot/bazel-out/out/lib".to_owned()),
            BuildScriptOutput::LinkSearch("/execrootish/not-redacted/lib".to_owned()),
            BuildScriptOutput::LinkSearch("framework=/usr/local/lib".to_owned()),
            BuildScriptOutput::LinkSearch("/opt/system/lib".to_owned()),
            BuildScriptOutput::Env("HERMETIC=/execroot/workspace/include".to_owned()),
            BuildScriptOutput::Env("SYSTEM_HEADER=/usr/include/zlib.h".to_owned()),
            BuildScriptOutput::Env("CFLAGS=-I/opt/system/include -DOK=1".to_owned()),
            BuildScriptOutput::DepEnv("ROOT=/usr/local/share/zlib".to_owned()),
            BuildScriptOutput::Env("DOCS=https://example.com/a/path".to_owned()),
        ];

        assert_eq!(
            BuildScriptOutput::nonhermetic_absolute_paths(&outputs, "/execroot", "bazel-out/out",),
            vec![
                "cargo::rustc-link-search=/execrootish/not-redacted/lib",
                "cargo::rustc-link-search=framework=/usr/local/lib",
                "cargo::rustc-link-search=/opt/system/lib",
                "cargo::rustc-env=SYSTEM_HEADER=/usr/include/zlib.h",
                "cargo::rustc-env=CFLAGS=-I/opt/system/include -DOK=1",
                "cargo::metadata=ROOT=/usr/local/share/zlib",
            ]
        );
    }
}

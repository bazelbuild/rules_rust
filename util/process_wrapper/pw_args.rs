// Copyright 2024 The Bazel Authors. All rights reserved.
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

//! Shared process_wrapper argument normalization.
//!
//! Types and functions in this module are used by both the standalone execution
//! path (`options.rs`) and the persistent worker path (`worker_args.rs`).

use std::collections::HashMap;
use std::fmt;

use crate::util::*;

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

#[derive(Debug)]
pub(crate) enum OptionError {
    FlagError(crate::flags::FlagParseError),
    Generic(String),
}

impl fmt::Display for OptionError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Self::FlagError(e) => write!(f, "error parsing flags: {e}"),
            Self::Generic(s) => write!(f, "{s}"),
        }
    }
}

// ---------------------------------------------------------------------------
// Pipelining mode
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum SubprocessPipeliningMode {
    Metadata,
    Full,
}

// ---------------------------------------------------------------------------
// Parsed PW args
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct ParsedPwArgs {
    pub(crate) subst: Vec<(String, String)>,
    pub(crate) env_files: Vec<String>,
    pub(crate) arg_files: Vec<String>,
    pub(crate) stable_status_file: Option<String>,
    pub(crate) volatile_status_file: Option<String>,
    pub(crate) output_file: Option<String>,
    pub(crate) rustc_output_format: Option<String>,
    pub(crate) require_explicit_unstable_features: bool,
}

impl ParsedPwArgs {
    pub(crate) fn merge_relocated(&mut self, relocated: RelocatedPwFlags) {
        self.env_files.extend(relocated.env_files);
        self.arg_files.extend(relocated.arg_files);
        if relocated.output_file.is_some() {
            self.output_file = relocated.output_file;
        }
        if relocated.rustc_output_format.is_some() {
            self.rustc_output_format = relocated.rustc_output_format;
        }
        if relocated.stable_status_file.is_some() {
            self.stable_status_file = relocated.stable_status_file;
        }
        if relocated.volatile_status_file.is_some() {
            self.volatile_status_file = relocated.volatile_status_file;
        }
    }
}

pub(crate) fn parse_pw_args(pw_args: &[String], pwd: &std::path::Path) -> ParsedPwArgs {
    let current_dir = pwd.to_string_lossy().into_owned();
    let mut parsed = ParsedPwArgs {
        subst: Vec::new(),
        env_files: Vec::new(),
        arg_files: Vec::new(),
        stable_status_file: None,
        volatile_status_file: None,
        output_file: None,
        rustc_output_format: None,
        require_explicit_unstable_features: false,
    };
    let mut i = 0;
    while i < pw_args.len() {
        match pw_args[i].as_str() {
            "--subst" => {
                if let Some(kv) = pw_args.get(i + 1) {
                    if let Some((k, v)) = kv.split_once('=') {
                        let resolved = if v == "${pwd}" { &current_dir } else { v };
                        parsed.subst.push((k.to_owned(), resolved.to_owned()));
                    }
                    i += 1;
                }
            }
            "--env-file" => {
                if let Some(path) = pw_args.get(i + 1) {
                    parsed.env_files.push(path.clone());
                    i += 1;
                }
            }
            "--arg-file" => {
                if let Some(path) = pw_args.get(i + 1) {
                    parsed.arg_files.push(path.clone());
                    i += 1;
                }
            }
            "--output-file" => {
                if let Some(path) = pw_args.get(i + 1) {
                    parsed.output_file = Some(path.clone());
                    i += 1;
                }
            }
            "--stable-status-file" => {
                if let Some(path) = pw_args.get(i + 1) {
                    parsed.stable_status_file = Some(path.clone());
                    i += 1;
                }
            }
            "--volatile-status-file" => {
                if let Some(path) = pw_args.get(i + 1) {
                    parsed.volatile_status_file = Some(path.clone());
                    i += 1;
                }
            }
            "--rustc-output-format" => {
                if let Some(val) = pw_args.get(i + 1) {
                    parsed.rustc_output_format = Some(val.clone());
                    i += 1;
                }
            }
            "--require-explicit-unstable-features" => {
                if let Some(val) = pw_args.get(i + 1) {
                    parsed.require_explicit_unstable_features = val == "true";
                    i += 1;
                }
            }
            _ => {}
        }
        i += 1;
    }
    parsed
}

// ---------------------------------------------------------------------------
// Relocated PW flags
// ---------------------------------------------------------------------------

#[derive(Default, Debug, Clone, PartialEq, Eq)]
pub(crate) struct RelocatedPwFlags {
    pub(crate) env_files: Vec<String>,
    pub(crate) arg_files: Vec<String>,
    pub(crate) output_file: Option<String>,
    pub(crate) rustc_output_format: Option<String>,
    pub(crate) stable_status_file: Option<String>,
    pub(crate) volatile_status_file: Option<String>,
    pub(crate) pipelining_mode: Option<SubprocessPipeliningMode>,
    pub(crate) pipelining_rlib_path: Option<String>,
}

impl RelocatedPwFlags {
    pub(crate) fn merge_from(&mut self, other: Self) {
        self.env_files.extend(other.env_files);
        self.arg_files.extend(other.arg_files);
        if other.output_file.is_some() {
            self.output_file = other.output_file;
        }
        if other.rustc_output_format.is_some() {
            self.rustc_output_format = other.rustc_output_format;
        }
        if other.stable_status_file.is_some() {
            self.stable_status_file = other.stable_status_file;
        }
        if other.volatile_status_file.is_some() {
            self.volatile_status_file = other.volatile_status_file;
        }
        if other.pipelining_mode.is_some() {
            self.pipelining_mode = other.pipelining_mode;
        }
        if other.pipelining_rlib_path.is_some() {
            self.pipelining_rlib_path = other.pipelining_rlib_path;
        }
    }
}

// ---------------------------------------------------------------------------
// Normalized rustc metadata
// ---------------------------------------------------------------------------

#[derive(Default, Debug, Clone, PartialEq, Eq)]
pub(crate) struct NormalizedRustcMetadata {
    pub(crate) has_allow_features: bool,
    pub(crate) relocated: RelocatedPwFlags,
    pub(crate) pipelining_key: Option<String>,
}

// ---------------------------------------------------------------------------
// Flag predicates
// ---------------------------------------------------------------------------

pub(crate) fn is_allow_features_flag(arg: &str) -> bool {
    arg.starts_with("-Zallow-features=") || arg.starts_with("allow-features=")
}

/// Returns true for worker-pipelining protocol flags that should never be
/// forwarded to rustc. These flags live in the @paramfile (rustc_flags) so
/// both RustcMetadata and Rustc actions share identical startup args (same
/// worker key). They must be stripped before the args reach rustc.
pub(crate) fn is_pipelining_flag(arg: &str) -> bool {
    arg == "--pipelining-metadata"
        || arg == "--pipelining-full"
        || arg.starts_with("--pipelining-key=")
        || arg.starts_with("--pipelining-rlib-path=")
}

/// Returns true if `arg` is a process_wrapper flag that may appear in the
/// @paramfile when worker pipelining is active.  These flags are placed in
/// the paramfile (per-request args) instead of startup args so that all
/// worker actions share the same WorkerKey.  They must be stripped before the
/// expanded paramfile reaches rustc.
///
/// Unlike pipelining flags (which are standalone), these flags consume the
/// *next* argument as their value, so the caller must skip it too.
pub(crate) fn is_relocated_pw_flag(arg: &str) -> bool {
    arg == "--output-file"
        || arg == "--rustc-output-format"
        || arg == "--env-file"
        || arg == "--arg-file"
        || arg == "--stable-status-file"
        || arg == "--volatile-status-file"
}

// ---------------------------------------------------------------------------
// External path resolution
// ---------------------------------------------------------------------------

/// On Windows, resolve `.rs` source file paths that pass through junctions
/// containing relative symlinks.  Windows cannot resolve chained reparse
/// points (junction -> relative symlink -> symlink) in a single traversal,
/// causing rustc to fail with ERROR_PATH_NOT_FOUND.
///
/// Only resolves paths ending in `.rs` to avoid changing crate identity
/// for `--extern` and `-L` paths (which would cause crate version mismatches).
#[cfg(windows)]
pub(crate) fn resolve_external_path(arg: &str) -> std::borrow::Cow<'_, str> {
    use std::borrow::Cow;
    use std::path::Path;
    if !arg.ends_with(".rs") {
        return Cow::Borrowed(arg);
    }
    if !arg.starts_with("external/") && !arg.starts_with("external\\") {
        return Cow::Borrowed(arg);
    }
    let path = Path::new(arg);
    let mut components = path.components();
    let Some(_external) = components.next() else {
        return Cow::Borrowed(arg);
    };
    let Some(repo_name) = components.next() else {
        return Cow::Borrowed(arg);
    };
    let junction = Path::new("external").join(repo_name);
    let Ok(resolved) = std::fs::read_link(&junction) else {
        return Cow::Borrowed(arg);
    };
    let remainder: std::path::PathBuf = components.collect();
    if remainder.as_os_str().is_empty() {
        return Cow::Borrowed(arg);
    }
    Cow::Owned(resolved.join(remainder).to_string_lossy().into_owned())
}

/// No-op on non-Windows: returns the argument unchanged without allocating.
#[cfg(not(windows))]
#[inline]
pub(crate) fn resolve_external_path(arg: &str) -> std::borrow::Cow<'_, str> {
    std::borrow::Cow::Borrowed(arg)
}

// ---------------------------------------------------------------------------
// Arg normalization internals
// ---------------------------------------------------------------------------

fn record_pipelining_flag(arg: &str, metadata: &mut NormalizedRustcMetadata) -> bool {
    if !is_pipelining_flag(arg) {
        return false;
    }
    if arg == "--pipelining-metadata" {
        metadata.relocated.pipelining_mode = Some(SubprocessPipeliningMode::Metadata);
    } else if arg == "--pipelining-full" {
        metadata.relocated.pipelining_mode = Some(SubprocessPipeliningMode::Full);
    } else if let Some(key) = arg.strip_prefix("--pipelining-key=") {
        metadata.pipelining_key = Some(key.to_owned());
    } else if let Some(path) = arg.strip_prefix("--pipelining-rlib-path=") {
        metadata.relocated.pipelining_rlib_path = Some(path.to_owned());
    }
    true
}

fn apply_relocated_value(flag: &str, value: String, relocated: &mut RelocatedPwFlags) {
    match flag {
        "--env-file" => relocated.env_files.push(value),
        "--arg-file" => relocated.arg_files.push(value),
        "--output-file" => relocated.output_file = Some(value),
        "--rustc-output-format" => relocated.rustc_output_format = Some(value),
        "--stable-status-file" => relocated.stable_status_file = Some(value),
        "--volatile-status-file" => relocated.volatile_status_file = Some(value),
        _ => {}
    }
}

#[derive(Clone, Copy)]
pub(crate) enum ParamFileReadErrorMode {
    Error,
    PreserveArg,
}

pub(crate) fn normalize_args_recursive(
    args: Vec<String>,
    subst_mappings: &[(String, String)],
    read_file: &mut dyn FnMut(&str) -> Result<Vec<String>, OptionError>,
    read_error_mode: ParamFileReadErrorMode,
    write_arg: &mut dyn FnMut(String) -> Result<(), OptionError>,
    metadata: &mut NormalizedRustcMetadata,
) -> Result<(), OptionError> {
    let mut pending_flag: Option<String> = None;
    for mut arg in args {
        crate::util::apply_substitutions(&mut arg, subst_mappings);
        if let Some(flag) = pending_flag.take() {
            apply_relocated_value(&flag, arg, &mut metadata.relocated);
            continue;
        }
        if record_pipelining_flag(&arg, metadata) {
            continue;
        }
        if is_relocated_pw_flag(&arg) {
            pending_flag = Some(arg);
            continue;
        }
        if let Some(arg_file) = arg.strip_prefix('@') {
            let nested_args = match read_file(arg_file) {
                Ok(args) => args,
                Err(err) => match read_error_mode {
                    ParamFileReadErrorMode::Error => return Err(err),
                    ParamFileReadErrorMode::PreserveArg => {
                        write_arg(arg)?;
                        continue;
                    }
                },
            };
            normalize_args_recursive(
                nested_args,
                subst_mappings,
                read_file,
                read_error_mode,
                write_arg,
                metadata,
            )?;
            continue;
        }
        metadata.has_allow_features |= is_allow_features_flag(&arg);
        let resolved = resolve_external_path(&arg);
        write_arg(match resolved {
            std::borrow::Cow::Borrowed(_) => arg,
            std::borrow::Cow::Owned(s) => s,
        })?;
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// expand_args_inline — worker-path arg expansion
// ---------------------------------------------------------------------------

pub(crate) fn expand_args_inline(
    args: &[String],
    subst_mappings: &[(String, String)],
    require_explicit_unstable_features: bool,
    read_file: Option<&mut dyn FnMut(&str) -> Result<Vec<String>, OptionError>>,
    preserve_unreadable_paramfiles: bool,
) -> Result<(Vec<String>, NormalizedRustcMetadata), OptionError> {
    let mut metadata = NormalizedRustcMetadata::default();
    let mut expanded = Vec::new();
    let mut read_file_wrapper = |s: &str| read_file_to_array(s).map_err(OptionError::Generic);
    let mut read_file = read_file.unwrap_or(&mut read_file_wrapper);
    let read_error_mode = if preserve_unreadable_paramfiles {
        ParamFileReadErrorMode::PreserveArg
    } else {
        ParamFileReadErrorMode::Error
    };
    let mut write_arg = |arg: String| {
        expanded.push(arg);
        Ok(())
    };
    normalize_args_recursive(
        args.to_vec(),
        subst_mappings,
        &mut read_file,
        read_error_mode,
        &mut write_arg,
        &mut metadata,
    )?;
    if !metadata.has_allow_features && require_explicit_unstable_features {
        expanded.push("-Zallow-features=".to_string());
    }
    Ok((expanded, metadata))
}

// ---------------------------------------------------------------------------
// Environment building
// ---------------------------------------------------------------------------

fn env_from_files(paths: &[String]) -> Result<HashMap<String, String>, String> {
    let mut env_vars = HashMap::new();
    for path in paths {
        let lines = read_file_to_array(path)
            .map_err(|err| format!("failed to read env-file '{}': {}", path, err))?;
        for line in lines.into_iter() {
            let (k, v) = line
                .split_once('=')
                .ok_or_else(|| format!("env-file '{}': invalid line (no '='): {}", path, line))?;
            env_vars.insert(k.to_owned(), v.to_owned());
        }
    }
    Ok(env_vars)
}

pub(crate) fn environment_block(
    environment_file_block: HashMap<String, String>,
    stable_stamp_mappings: &[(String, String)],
    volatile_stamp_mappings: &[(String, String)],
    subst_mappings: &[(String, String)],
) -> HashMap<String, String> {
    // Taking all environment variables from the current process
    // and sending them down to the child process
    let mut environment_variables: HashMap<String, String> = std::env::vars().collect();
    // Have the last values added take precedence over the first.
    // This is simpler than needing to track duplicates and explicitly override
    // them.
    environment_variables.extend(environment_file_block);
    for (f, replace_with) in &[stable_stamp_mappings, volatile_stamp_mappings].concat() {
        for value in environment_variables.values_mut() {
            let from = format!("{{{f}}}");
            let new = value.replace(from.as_str(), replace_with);
            *value = new;
        }
    }
    for value in environment_variables.values_mut() {
        crate::util::apply_substitutions(value, subst_mappings);
    }
    environment_variables
}

pub(crate) fn build_child_environment(
    env_files: &[String],
    stable_status_file: Option<&str>,
    volatile_status_file: Option<&str>,
    subst_mappings: &[(String, String)],
) -> Result<HashMap<String, String>, String> {
    let environment_file_block = env_from_files(env_files)?;
    let stable_stamp_mappings = match stable_status_file {
        Some(path) => read_stamp_status_with_context(path, "stable-status")?,
        None => Vec::new(),
    };
    let volatile_stamp_mappings = match volatile_status_file {
        Some(path) => read_stamp_status_with_context(path, "volatile-status")?,
        None => Vec::new(),
    };
    Ok(environment_block(
        environment_file_block,
        &stable_stamp_mappings,
        &volatile_stamp_mappings,
        subst_mappings,
    ))
}

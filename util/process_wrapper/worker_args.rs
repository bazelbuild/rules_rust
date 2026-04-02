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

//! Argument parsing and rewriting for the persistent worker.

use std::collections::HashMap;

use crate::options::{
    build_child_environment, is_pipelining_flag, is_relocated_pw_flag, NormalizedRustcMetadata,
    OptionError, ParsedPwArgs, RelocatedPwFlags,
};
use crate::pw_args::{normalize_args_recursive, ParamFileReadErrorMode};
use crate::ProcessWrapperError;

use super::exec::{resolve_request_relative_path, ExpandedRustcOutputs};
use super::pipeline::pipelining_err;
use super::request::RequestKind;
use super::request::WorkRequest;
use super::types::{OutputDir, PipelineKey};

/// Scans an iterator of argument strings for pipelining flags and returns a
/// classified `RequestKind`.
pub(super) fn scan_pipelining_flags<'a>(iter: impl Iterator<Item = &'a str>) -> RequestKind {
    let mut is_metadata = false;
    let mut is_full = false;
    let mut key: Option<String> = None;
    for arg in iter {
        if arg == "--pipelining-metadata" {
            is_metadata = true;
        } else if arg == "--pipelining-full" {
            is_full = true;
        } else if let Some(k) = arg.strip_prefix("--pipelining-key=") {
            key = Some(k.to_string());
        }
    }
    match (is_metadata, is_full, key) {
        (true, _, Some(k)) => RequestKind::Metadata {
            key: PipelineKey(k),
        },
        (_, true, Some(k)) => RequestKind::Full {
            key: PipelineKey(k),
        },
        _ => RequestKind::NonPipelined,
    }
}

/// Strips pipelining protocol flags from a direct arg list.
pub(super) fn strip_pipelining_flags(args: &[String]) -> Vec<String> {
    args.iter()
        .filter(|a| !is_pipelining_flag(a))
        .cloned()
        .collect()
}

/// Startup args split at `--`.
pub(super) struct StartupLayout {
    /// Process-wrapper flags before `--` (e.g. `["--subst", "pwd=${pwd}"]`).
    pub(super) pw_args: Vec<String>,
    /// Child-program prefix after `--` (e.g. `["/path/to/rustc"]`).
    pub(super) child_prefix: Vec<String>,
}

/// Splits startup args at the `--` boundary.
pub(super) fn split_startup_args(
    startup_args: &[String],
) -> Result<StartupLayout, ProcessWrapperError> {
    let mut parts = startup_args.splitn(2, |a| a == "--");
    let pw_args = parts.next().unwrap().to_vec();
    let child_prefix = parts
        .next()
        .ok_or_else(|| ProcessWrapperError("startup args missing '--' separator".into()))?
        .to_vec();
    Ok(StartupLayout {
        pw_args,
        child_prefix,
    })
}

/// Splits per-request process_wrapper flags from child args.
pub(super) fn extract_direct_request_pw_flags(
    request_args: &[String],
) -> (Vec<String>, Vec<String>) {
    let mut remaining = Vec::new();
    let mut pw_pairs = Vec::new();
    let mut iter = request_args.iter();
    while let Some(arg) = iter.next() {
        if is_relocated_pw_flag(arg) {
            pw_pairs.push(arg.clone());
            if let Some(val) = iter.next() {
                pw_pairs.push(val.clone());
            }
        } else {
            remaining.push(arg.clone());
        }
    }
    (remaining, pw_pairs)
}

/// Combines startup args with per-request args into the final argv.
pub(super) fn assemble_request_argv(
    startup_args: &[String],
    request_args: &[String],
) -> Result<Vec<String>, ProcessWrapperError> {
    let layout = split_startup_args(startup_args)?;
    let (remaining_child, direct_pw) = extract_direct_request_pw_flags(request_args);
    Ok([
        layout.pw_args,
        direct_pw,
        vec!["--".into()],
        layout.child_prefix,
        remaining_child,
    ]
    .concat())
}

pub(super) fn expand_rustc_args_with_metadata(
    rustc_and_after: &[String],
    subst: &[(String, String)],
    require_explicit_unstable_features: bool,
    execroot_dir: &std::path::Path,
) -> Result<(Vec<String>, NormalizedRustcMetadata), OptionError> {
    let mut metadata = NormalizedRustcMetadata::default();
    let mut expanded = Vec::new();
    let mut read_file = |path: &str| {
        let resolved = resolve_request_relative_path(path, Some(execroot_dir))
            .display()
            .to_string();
        crate::util::read_file_to_array(&resolved).map_err(OptionError::Generic)
    };
    let mut write_arg = |arg: String| {
        expanded.push(arg);
        Ok(())
    };
    normalize_args_recursive(
        rustc_and_after.to_vec(),
        subst,
        &mut read_file,
        ParamFileReadErrorMode::PreserveArg,
        &mut write_arg,
        &mut metadata,
    )?;
    if !metadata.has_allow_features && require_explicit_unstable_features {
        expanded.push("-Zallow-features=".to_string());
    }
    Ok((expanded, metadata))
}

/// Builds the rustc environment from inherited vars, env files, and substitutions.
pub(super) fn build_rustc_env(
    env_files: &[String],
    stable_status_file: Option<&str>,
    volatile_status_file: Option<&str>,
    subst: &[(String, String)],
) -> Result<HashMap<String, String>, String> {
    build_child_environment(env_files, stable_status_file, volatile_status_file, subst)
}

/// Prepares rustc arguments: expand @paramfiles, apply substitutions, strip
/// pipelining flags, and append args from --arg-file files.
///
/// Returns `(rustc_args, original_out_dir, relocated_pw_flags)` on success.
pub(super) fn prepare_rustc_args(
    rustc_and_after: &[String],
    pw_args: &ParsedPwArgs,
    execroot_dir: &std::path::Path,
) -> Result<(Vec<String>, OutputDir, RelocatedPwFlags), (i32, String)> {
    let (mut rustc_args, metadata) = expand_rustc_args_with_metadata(
        rustc_and_after,
        &pw_args.subst,
        pw_args.require_explicit_unstable_features,
        execroot_dir,
    )
    .map_err(|e| pipelining_err(e))?;
    if rustc_args.is_empty() {
        return Err(pipelining_err("no rustc arguments after expansion"));
    }

    // Append args from any `--arg-file` inputs.
    let mut arg_files = pw_args.arg_files.clone();
    arg_files.extend(metadata.relocated.arg_files.iter().cloned());
    for path in arg_files {
        let resolved = resolve_request_relative_path(&path, Some(execroot_dir));
        let resolved = resolved.display().to_string();
        let lines = crate::util::read_file_to_array(&resolved)
            .map_err(|e| (1, format!("failed to read arg-file '{}': {}", resolved, e)))?;
        for line in lines {
            rustc_args.push(apply_substs(&line, &pw_args.subst));
        }
    }

    let original_out_dir = OutputDir(find_out_dir_in_expanded(&rustc_args).unwrap_or_default());

    Ok((rustc_args, original_out_dir, metadata.relocated))
}

/// Rewrites output-related rustc args in one pass and returns the writable
/// paths needed by `prepare_expanded_rustc_outputs`.
pub(super) fn rewrite_expanded_rustc_outputs(
    args: Vec<String>,
    new_out_dir: &std::path::Path,
) -> (Vec<String>, ExpandedRustcOutputs) {
    let mut rewritten = Vec::with_capacity(args.len());
    let mut outputs = ExpandedRustcOutputs::default();
    let rewritten_out_dir = new_out_dir.display().to_string();

    for arg in args {
        if arg.starts_with("--out-dir=") {
            outputs.out_dir = Some(rewritten_out_dir.clone());
            rewritten.push(format!("--out-dir={rewritten_out_dir}"));
            continue;
        }

        let Some(emit) = arg.strip_prefix("--emit=") else {
            rewritten.push(arg);
            continue;
        };

        let mut rewritten_parts = Vec::new();
        for part in emit.split(',') {
            let Some((kind, path)) = part.split_once('=') else {
                rewritten_parts.push(part.to_owned());
                continue;
            };

            let path = if kind == "metadata" {
                let filename = std::path::Path::new(path)
                    .file_name()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .into_owned();
                new_out_dir.join(filename).display().to_string()
            } else {
                path.to_owned()
            };
            outputs.emit_paths.push(path.clone());
            rewritten_parts.push(format!("{kind}={path}"));
        }
        rewritten.push(format!("--emit={}", rewritten_parts.join(",")));
    }

    (rewritten, outputs)
}

fn resolve_paths(paths: Vec<String>, base: &std::path::Path) -> Vec<String> {
    paths
        .into_iter()
        .map(|p| {
            resolve_request_relative_path(&p, Some(base))
                .display()
                .to_string()
        })
        .collect()
}

pub(super) fn resolve_pw_args_for_request(
    mut pw_args: ParsedPwArgs,
    request: &WorkRequest,
    execroot_dir: &std::path::Path,
) -> ParsedPwArgs {
    let resolve = |path: String, base: &std::path::Path| -> String {
        resolve_request_relative_path(&path, Some(base))
            .display()
            .to_string()
    };
    pw_args.env_files = resolve_paths(pw_args.env_files, execroot_dir);
    pw_args.arg_files = resolve_paths(pw_args.arg_files, execroot_dir);
    pw_args.stable_status_file = pw_args
        .stable_status_file
        .map(|p| resolve(p, execroot_dir));
    pw_args.volatile_status_file = pw_args
        .volatile_status_file
        .map(|p| resolve(p, execroot_dir));
    pw_args.output_file = pw_args.output_file.map(|path| {
        let base = request
            .sandbox_dir
            .as_ref()
            .map(|sd| sd.as_path())
            .unwrap_or(execroot_dir);
        resolve(path, base)
    });
    pw_args
}

/// Applies substitutions to one argument string.
pub(super) fn apply_substs(arg: &str, subst: &[(String, String)]) -> String {
    let mut a = arg.to_owned();
    crate::util::apply_substitutions(&mut a, subst);
    a
}

/// Searches already-expanded rustc args for `--out-dir=<path>`.
pub(super) fn find_out_dir_in_expanded(args: &[String]) -> Option<String> {
    args.iter()
        .find_map(|arg| arg.strip_prefix("--out-dir=").map(|d| d.to_string()))
}



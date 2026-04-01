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

//! Argument parsing, expansion, rewriting, and environment building
//! for the persistent worker.

use std::collections::HashMap;

use crate::options::{
    build_child_environment, expand_args_inline, is_pipelining_flag, is_relocated_pw_flag,
    parse_pw_args as parse_shared_pw_args, NormalizedRustcMetadata, OptionError, ParsedPwArgs,
    RelocatedPwFlags,
};

use super::exec::{make_dir_files_writable, make_path_writable, resolve_request_relative_path};
use super::pipeline::pipelining_err;
use super::protocol::ParsedWorkRequest;
use super::types::OutputDir;

/// Scans an iterator of argument strings for pipelining flags.
/// Returns `(is_metadata, is_full, pipeline_key)`.
pub(super) fn scan_pipelining_flags<'a>(
    iter: impl Iterator<Item = &'a str>,
) -> (bool, bool, Option<String>) {
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
    (is_metadata, is_full, key)
}

/// Strips pipelining protocol flags from a direct arg list.
///
/// Used for the full-action fallback path (where pipelining flags may appear
/// in direct args if no @paramfile was used). When flags are in a @paramfile,
/// `options.rs` `prepare_param_file` handles stripping during expansion.
pub(super) fn strip_pipelining_flags(args: &[String]) -> Vec<String> {
    args.iter()
        .filter(|a| !is_pipelining_flag(a))
        .cloned()
        .collect()
}

/// Move process_wrapper flags that appear after `--` to before it.
///
/// When worker pipelining is active, per-action flags like `--output-file`
/// are placed in the @paramfile (so all actions share the same WorkerKey).
/// After the worker concatenates startup_args + request.arguments, these
/// flags end up after the `--` separator.  Both the subprocess path
/// (`options.rs`) and the pipelining path (`parse_pw_args`) expect them
/// before `--`, so we relocate them here.
pub(super) fn relocate_pw_flags(args: &mut Vec<String>) {
    let sep_pos = match args.iter().position(|a| a == "--") {
        Some(pos) => pos,
        None => return,
    };

    // Collect indices of relocated pw flags (and their values) after --.
    let mut to_relocate: Vec<String> = Vec::new();
    let mut remove_indices: Vec<usize> = Vec::new();
    let mut i = sep_pos + 1;
    while i < args.len() {
        if is_relocated_pw_flag(&args[i]) {
            remove_indices.push(i);
            to_relocate.push(args[i].clone());
            if i + 1 < args.len() {
                remove_indices.push(i + 1);
                to_relocate.push(args[i + 1].clone());
                i += 2;
            } else {
                i += 1;
            }
        } else {
            i += 1;
        }
    }

    if to_relocate.is_empty() {
        return;
    }

    // Remove from after -- in reverse order to preserve indices.
    for &idx in remove_indices.iter().rev() {
        args.remove(idx);
    }

    // Insert before -- (which may have shifted after removals).
    let sep_pos = args.iter().position(|a| a == "--").unwrap_or(0);
    for (offset, flag) in to_relocate.into_iter().enumerate() {
        args.insert(sep_pos + offset, flag);
    }
}

/// Parses process_wrapper flags from the pre-`--` portion of args.
pub(super) fn parse_pw_args(pw_args: &[String], pwd: &std::path::Path) -> ParsedPwArgs {
    parse_shared_pw_args(pw_args, pwd)
}

fn read_args_file_in_dir(
    path: &str,
    base_dir: &std::path::Path,
) -> Result<Vec<String>, OptionError> {
    let resolved = resolve_request_relative_path(path, Some(base_dir));
    let resolved = resolved.display().to_string();
    crate::util::read_file_to_array(&resolved).map_err(OptionError::Generic)
}

pub(super) fn expand_rustc_args_with_metadata(
    rustc_and_after: &[String],
    subst: &[(String, String)],
    require_explicit_unstable_features: bool,
    execroot_dir: &std::path::Path,
) -> Result<(Vec<String>, NormalizedRustcMetadata), OptionError> {
    let mut read_file = |path: &str| read_args_file_in_dir(path, execroot_dir);
    expand_args_inline(
        rustc_and_after,
        subst,
        require_explicit_unstable_features,
        Some(&mut read_file),
        true,
    )
}

/// Builds the environment map: inherit current process + env files + apply substitutions.
///
/// Returns `Err` if any env-file or stamp-file cannot be read, aligning with
/// the standalone path's error behavior (Finding 5 fix).
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

    // Append args from --arg-file files (e.g. build script output: --cfg=..., -L ...).
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

fn resolve_path(path: String, base: &std::path::Path) -> String {
    resolve_request_relative_path(&path, Some(base))
        .display()
        .to_string()
}

pub(super) fn resolve_pw_args_for_request(
    mut pw_args: ParsedPwArgs,
    request: &ParsedWorkRequest,
    execroot_dir: &std::path::Path,
) -> ParsedPwArgs {
    pw_args.env_files = resolve_paths(pw_args.env_files, execroot_dir);
    pw_args.arg_files = resolve_paths(pw_args.arg_files, execroot_dir);
    pw_args.stable_status_file = pw_args
        .stable_status_file
        .map(|p| resolve_path(p, execroot_dir));
    pw_args.volatile_status_file = pw_args
        .volatile_status_file
        .map(|p| resolve_path(p, execroot_dir));
    pw_args.output_file = pw_args.output_file.map(|path| {
        let base = request
            .sandbox_dir
            .as_ref()
            .map(|sd| sd.as_path())
            .unwrap_or(execroot_dir);
        resolve_path(path, base)
    });
    pw_args
}

/// Applies `${key}` → `value` substitution mappings to a single argument string.
///
/// Delegates to [`crate::util::apply_substitutions`], which couples substitution
/// with Windows verbatim path normalization so callers cannot forget it.
pub(super) fn apply_substs(arg: &str, subst: &[(String, String)]) -> String {
    let mut a = arg.to_owned();
    crate::util::apply_substitutions(&mut a, subst);
    a
}

/// Builds the rustc argument list from the post-`--` section of process_wrapper
/// args, expanding any @paramfile references inline and stripping pipelining flags.
///
/// Rustc natively supports @paramfile expansion, but the paramfile may contain
/// pipelining protocol flags (`--pipelining-metadata`, `--pipelining-key=*`) that
/// rustc doesn't understand. By expanding and filtering here we avoid passing
/// unknown flags to rustc.
#[cfg(test)]
pub(super) fn expand_rustc_args(
    rustc_and_after: &[String],
    subst: &[(String, String)],
    execroot_dir: &std::path::Path,
) -> Vec<String> {
    expand_rustc_args_with_metadata(rustc_and_after, subst, false, execroot_dir)
        .map(|(args, _)| args)
        .unwrap_or_else(|_| {
            rustc_and_after
                .iter()
                .map(|arg| apply_substs(arg, subst))
                .collect()
        })
}

/// Searches already-expanded rustc args for `--out-dir=<path>`.
pub(super) fn find_out_dir_in_expanded(args: &[String]) -> Option<String> {
    args.iter()
        .find_map(|arg| arg.strip_prefix("--out-dir=").map(|d| d.to_string()))
}

/// Returns a copy of `args` where `--out-dir=<old>` is replaced by
/// `--out-dir=<new_out_dir>`. Other args are unchanged.
pub(super) fn rewrite_out_dir_in_expanded(
    args: Vec<String>,
    new_out_dir: &std::path::Path,
) -> Vec<String> {
    args.into_iter()
        .map(|arg| {
            if arg.starts_with("--out-dir=") {
                format!("--out-dir={}", new_out_dir.display())
            } else {
                arg
            }
        })
        .collect()
}

/// Rewrites `--emit=metadata=<path>` to write the .rmeta into the pipeline outputs dir.
/// The original relative path's filename is preserved; only the directory changes.
pub(super) fn rewrite_emit_metadata_path(
    args: Vec<String>,
    outputs_dir: &std::path::Path,
) -> Vec<String> {
    args.into_iter()
        .map(|arg| {
            if let Some(path_str) = arg.strip_prefix("--emit=metadata=") {
                let filename = std::path::Path::new(path_str)
                    .file_name()
                    .unwrap_or_default()
                    .to_string_lossy();
                format!(
                    "--emit=metadata={}",
                    outputs_dir.join(filename.as_ref()).display()
                )
            } else {
                arg
            }
        })
        .collect()
}

pub(super) fn prepare_expanded_rustc_outputs(args: &[String]) {
    for arg in args {
        if let Some(dir) = arg.strip_prefix("--out-dir=") {
            make_dir_files_writable(dir);
            let pipeline_dir = format!("{dir}/_pipeline");
            make_dir_files_writable(&pipeline_dir);
            continue;
        }

        let Some(emit) = arg.strip_prefix("--emit=") else {
            continue;
        };
        for part in emit.split(',') {
            let Some((_, path)) = part.split_once('=') else {
                continue;
            };
            make_path_writable(std::path::Path::new(path));
        }
    }
}

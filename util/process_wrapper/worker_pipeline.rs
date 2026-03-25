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

//! Pipelining state and handlers for the persistent worker.

use std::collections::HashMap;
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;

use tinyjson::JsonValue;

use crate::options::{is_pipelining_flag, is_relocated_pw_flag};
use crate::util::read_stamp_status_to_array;
use crate::ProcessWrapperError;

use super::protocol::WorkRequestContext;
use super::sandbox::{
    copy_all_outputs_to_sandbox, copy_output_to_sandbox, make_dir_files_writable,
    make_path_writable, prepare_outputs, resolve_relative_to, run_request,
    run_sandboxed_request,
};
use super::{append_worker_lifecycle_log, current_pid, lock_or_recover};

/// Pipelining mode for a worker request, parsed from process_wrapper flags.
pub(super) enum PipeliningMode {
    /// No pipelining flags present — handle as a normal subprocess request.
    None,
    /// `--pipelining-metadata --pipelining-key=<key>` present.
    /// Start a full rustc, return as soon as `.rmeta` is ready, cache the Child.
    Metadata { key: String },
    /// `--pipelining-full --pipelining-key=<key>` present.
    /// Retrieve the cached Child from PipelineState and wait for it to finish.
    Full { key: String },
}

/// A background rustc process started by a RustcMetadata action.
///
/// After the `.rmeta` artifact notification, the handler stores the Child
/// here and spawns a background thread to drain the remaining stderr output.
/// The full compile handler retrieves this, joins the drain thread, and waits
/// for the child to exit.
pub(super) struct BackgroundRustc {
    pub(super) child: std::process::Child,
    /// Request ID of the metadata action that spawned this background rustc.
    /// Used by the cancel handler to find which pipeline key to kill.
    pub(super) metadata_request_id: i64,
    /// Diagnostics captured from rustc stderr before the metadata signal.
    pub(super) diagnostics_before: String,
    /// Background thread draining rustc's remaining stderr output after the
    /// metadata signal. Must be joined before waiting on `child` to avoid
    /// deadlock (child blocks on stderr write if the pipe buffer fills up).
    /// Returns the diagnostics captured after the metadata signal.
    pub(super) stderr_drain: thread::JoinHandle<String>,
    /// Worker-managed persistent root for this pipelined compile.
    pub(super) pipeline_root_dir: PathBuf,
    /// Worker-managed persistent output directory used by the background rustc.
    pub(super) pipeline_output_dir: PathBuf,
    /// Original `--out-dir` value (before rewriting to `pipeline_output_dir`).
    /// Used by the full handler to copy outputs from the persistent dir to the
    /// correct sandbox-relative location.
    pub(super) original_out_dir: String,
}

/// In-process store of background rustc processes for worker-managed pipelining.
///
/// Keyed by the pipeline key (crate name + output hash), set by the Bazel-side
/// `--pipelining-key=<key>` argument.
pub(super) struct PipelineState {
    pub(super) active: HashMap<String, BackgroundRustc>,
}

impl PipelineState {
    pub(super) fn new() -> Self {
        Self {
            active: HashMap::new(),
        }
    }

    pub(super) fn store(&mut self, key: String, bg: BackgroundRustc) {
        self.active.insert(key, bg);
    }

    pub(super) fn take(&mut self, key: &str) -> Option<BackgroundRustc> {
        self.active.remove(key)
    }
}

/// Parsed process_wrapper arguments from before the `--` separator.
pub(super) struct ParsedPwArgs {
    pub(super) subst: Vec<(String, String)>,
    pub(super) env_files: Vec<String>,
    pub(super) arg_files: Vec<String>,
    pub(super) stable_status_file: Option<String>,
    pub(super) volatile_status_file: Option<String>,
    pub(super) output_file: Option<String>,
}

/// Pipeline context for worker-managed pipelining.
///
/// Two modes:
/// - **Unsandboxed**: uses the real execroot as rustc's CWD.
/// - **Sandboxed**: uses the Bazel-provided `sandbox_dir` as CWD, keeping all
///   reads rooted in the sandbox per the multiplex sandbox contract.
pub(super) struct PipelineContext {
    pub(super) root_dir: PathBuf,
    /// Directory used as rustc's CWD and for resolving relative paths.
    /// Sandboxed: absolute `sandbox_dir`. Unsandboxed: canonicalized real execroot.
    pub(super) execroot_dir: PathBuf,
    pub(super) outputs_dir: PathBuf,
}

#[derive(Default)]
pub(super) struct OutputMaterializationStats {
    pub(super) files: usize,
    pub(super) hardlinked_files: usize,
    pub(super) copied_files: usize,
}

#[derive(Clone, Debug)]
pub(super) struct WorkerStateRoots {
    pipeline_root: PathBuf,
}

impl WorkerStateRoots {
    pub(super) fn ensure() -> Result<Self, ProcessWrapperError> {
        let pipeline_root = PathBuf::from("_pw_state/pipeline");
        std::fs::create_dir_all(&pipeline_root).map_err(|e| {
            ProcessWrapperError(format!("failed to create worker pipeline root: {e}"))
        })?;
        Ok(Self { pipeline_root })
    }

    pub(super) fn pipeline_dir(&self, key: &str) -> PathBuf {
        self.pipeline_root.join(key)
    }
}

/// Parses pipelining mode from worker request arguments.
///
/// Pipelining flags live in `rustc_flags` (the @paramfile) so both
/// RustcMetadata and Rustc actions have identical startup args (same worker
/// key). This function checks both direct args and any @paramfile content
/// found after the `--` separator.
pub(super) fn detect_pipelining_mode(args: &[String]) -> PipeliningMode {
    // First pass: check direct args (handles the no-paramfile case and is fast).
    let (mut is_metadata, mut is_full, mut key) =
        scan_pipelining_flags(args.iter().map(String::as_str));

    // Second pass: if not found yet, read @paramfiles from the rustc args
    // (everything after "--"). With always_use_param_file, pipelining flags
    // are inside the @paramfile rather than in direct args.
    if !is_metadata && !is_full {
        let sep_pos = args.iter().position(|a| a == "--");
        let rustc_args = match sep_pos {
            Some(pos) => &args[pos + 1..],
            None => &[][..],
        };
        for arg in rustc_args {
            if let Some(path) = arg.strip_prefix('@') {
                if let Ok(content) = std::fs::read_to_string(path) {
                    let (m, f, k) = scan_pipelining_flags(content.lines());
                    is_metadata |= m;
                    is_full |= f;
                    if k.is_some() {
                        key = k;
                    }
                    if is_metadata || is_full {
                        break;
                    }
                }
            }
        }
    }

    match (is_metadata, is_full, key) {
        (true, _, Some(k)) => PipeliningMode::Metadata { key: k },
        (_, true, Some(k)) => PipeliningMode::Full { key: k },
        _ => PipeliningMode::None,
    }
}

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
    let current_dir = pwd.to_string_lossy().into_owned();
    let mut parsed = ParsedPwArgs {
        subst: Vec::new(),
        env_files: Vec::new(),
        arg_files: Vec::new(),
        stable_status_file: None,
        volatile_status_file: None,
        output_file: None,
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
            _ => {}
        }
        i += 1;
    }
    parsed
}

/// Builds the environment map: inherit current process + env files + apply substitutions.
pub(super) fn build_rustc_env(
    env_files: &[String],
    stable_status_file: Option<&str>,
    volatile_status_file: Option<&str>,
    subst: &[(String, String)],
) -> HashMap<String, String> {
    let mut env: HashMap<String, String> = std::env::vars().collect();
    for path in env_files {
        if let Ok(content) = std::fs::read_to_string(path) {
            for line in content.lines() {
                if line.is_empty() {
                    continue;
                }
                if let Some((k, v)) = line.split_once('=') {
                    env.insert(k.to_owned(), v.to_owned());
                }
            }
        }
    }
    let stable_stamp_mappings: Vec<(String, String)> = stable_status_file
        .map(|path| read_stamp_status_to_array(path.to_owned()))
        .transpose()
        .unwrap_or_default()
        .unwrap_or_default();
    let volatile_stamp_mappings: Vec<(String, String)> = volatile_status_file
        .map(|path| read_stamp_status_to_array(path.to_owned()))
        .transpose()
        .unwrap_or_default()
        .unwrap_or_default();
    for (k, v) in stable_stamp_mappings
        .iter()
        .chain(volatile_stamp_mappings.iter())
    {
        for val in env.values_mut() {
            *val = val.replace(&format!("{{{k}}}"), v);
        }
    }
    for val in env.values_mut() {
        crate::util::apply_substitutions(val, subst);
    }
    env
}

/// Prepares rustc arguments: expand @paramfiles, apply substitutions, strip
/// pipelining flags, and append args from --arg-file files.
///
/// Returns `(rustc_args, original_out_dir)` on success.
pub(super) fn prepare_rustc_args(
    rustc_and_after: &[String],
    pw_args: &ParsedPwArgs,
    execroot_dir: &std::path::Path,
) -> Result<(Vec<String>, String), (i32, String)> {
    let mut rustc_args = expand_rustc_args(rustc_and_after, &pw_args.subst, execroot_dir);
    if rustc_args.is_empty() {
        return Err((
            1,
            "pipelining: no rustc arguments after expansion".to_string(),
        ));
    }

    // Append args from --arg-file files (e.g. build script output: --cfg=..., -L ...).
    for path in &pw_args.arg_files {
        if let Ok(content) = std::fs::read_to_string(path) {
            for line in content.lines() {
                if !line.is_empty() {
                    rustc_args.push(apply_substs(line, &pw_args.subst));
                }
            }
        }
    }

    let original_out_dir = find_out_dir_in_expanded(&rustc_args).unwrap_or_default();

    Ok((rustc_args, original_out_dir))
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
pub(super) fn expand_rustc_args(
    rustc_and_after: &[String],
    subst: &[(String, String)],
    execroot_dir: &std::path::Path,
) -> Vec<String> {
    let mut result = Vec::new();
    for raw in rustc_and_after {
        let arg = apply_substs(raw, subst);
        if let Some(path) = arg.strip_prefix('@') {
            let resolved_path = resolve_relative_to(path, execroot_dir);
            match std::fs::read_to_string(&resolved_path) {
                Ok(content) => {
                    for line in content.lines() {
                        if line.is_empty() {
                            continue;
                        }
                        let line = apply_substs(line, subst);
                        if !is_pipelining_flag(&line) {
                            let resolved = crate::options::resolve_external_path(&line);
                            result.push(resolved.into_owned());
                        }
                    }
                }
                Err(_) => {
                    // Can't read the paramfile — pass it through and let rustc error.
                    if !is_pipelining_flag(&arg) {
                        result.push(arg);
                    }
                }
            }
        } else if !is_pipelining_flag(&arg) {
            let resolved = crate::options::resolve_external_path(&arg);
            result.push(match resolved {
                std::borrow::Cow::Borrowed(_) => arg,
                std::borrow::Cow::Owned(s) => s,
            });
        }
    }
    result
}

/// Searches already-expanded rustc args for `--out-dir=<path>`.
pub(super) fn find_out_dir_in_expanded(args: &[String]) -> Option<String> {
    for arg in args {
        if let Some(dir) = arg.strip_prefix("--out-dir=") {
            return Some(dir.to_string());
        }
    }
    None
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

/// Creates a pipeline context for worker-managed pipelining.
///
/// When sandboxed, uses sandbox_dir as rustc's CWD so all reads go through the
/// sandbox (Bazel multiplex sandbox contract compliance). When unsandboxed, uses
/// the real execroot. In both cases, outputs are redirected to a persistent
/// worker-owned directory to prevent inter-request interference.
pub(super) fn create_pipeline_context(
    state_roots: &WorkerStateRoots,
    key: &str,
    request: &WorkRequestContext,
) -> Result<PipelineContext, (i32, String)> {
    let root_dir = state_roots.pipeline_dir(key);

    // Create the pipeline root and outputs dir.
    // Clear any leftover outputs from a previous failed run for this key.
    let outputs_dir = root_dir.join("outputs");
    if let Err(e) = std::fs::remove_dir_all(&outputs_dir) {
        if e.kind() != std::io::ErrorKind::NotFound {
            return Err((
                1,
                format!("pipelining: failed to clear pipeline outputs dir: {e}"),
            ));
        }
    }
    std::fs::create_dir_all(&outputs_dir).map_err(|e| {
        (
            1,
            format!("pipelining: failed to create pipeline outputs dir: {e}"),
        )
    })?;
    let root_dir = std::fs::canonicalize(root_dir).map_err(|e| {
        (
            1,
            format!("pipelining: failed to resolve pipeline dir: {e}"),
        )
    })?;
    let outputs_dir = std::fs::canonicalize(outputs_dir).map_err(|e| {
        (
            1,
            format!("pipelining: failed to resolve pipeline outputs dir: {e}"),
        )
    })?;

    // Two modes for determining rustc's CWD:
    //
    // SANDBOXED: Use sandbox_dir directly as CWD. All relative paths in rustc
    // args (--extern, -Ldependency, source files) resolve against sandbox_dir
    // where Bazel placed the inputs. This satisfies Rule 1 of the multiplex
    // sandbox contract ("use sandbox_dir as prefix for all reads and writes").
    // After .rmeta emission, background rustc only writes to --out-dir
    // (redirected to persistent pipeline dir), so sandbox cleanup after the
    // metadata response doesn't affect it (verified via strace — Gate 0).
    //
    // UNSANDBOXED: Use the worker's real execroot as CWD.
    let execroot_dir = if let Some(sandbox_dir) = request.sandbox_dir.as_deref() {
        // Make absolute WITHOUT canonicalizing — canonicalize() follows symlinks
        // inside the sandbox back to the real execroot, which defeats the purpose.
        // We need the sandbox path itself so rustc reads through sandbox_dir.
        let sandbox_path = std::path::Path::new(sandbox_dir);
        if sandbox_path.is_absolute() {
            sandbox_path.to_path_buf()
        } else {
            let cwd = std::env::current_dir().map_err(|e| {
                (1, format!("pipelining: failed to get worker CWD: {e}"))
            })?;
            cwd.join(sandbox_path)
        }
    } else {
        let cwd = std::env::current_dir()
            .map_err(|e| (1, format!("pipelining: failed to get worker CWD: {e}")))?;
        std::fs::canonicalize(cwd).map_err(|e| {
            (
                1,
                format!("pipelining: failed to canonicalize worker CWD: {e}"),
            )
        })?
    };

    Ok(PipelineContext {
        root_dir,
        execroot_dir,
        outputs_dir,
    })
}

// ---------------------------------------------------------------------------
// Pipelining handlers
// ---------------------------------------------------------------------------

/// Handles a `--pipelining-metadata` request (sandboxed or unsandboxed).
///
/// Starts a full rustc with `--emit=dep-info,metadata,link --json=artifacts`,
/// reads stderr until the `{"artifact":"...rmeta","emit":"metadata"}` JSON
/// notification appears, stores the running Child in PipelineState, and returns
/// success immediately so Bazel can unblock downstream rlib compiles.
///
/// Two modes:
/// - **Sandboxed**: rustc runs from `sandbox_dir` directly. All relative paths
///   in args resolve against the sandbox where Bazel placed inputs. Compliant
///   with the Bazel multiplex sandbox contract (Rule 1: all reads via sandbox_dir).
/// - **Unsandboxed**: rustc runs from the real execroot.
pub(super) fn handle_pipelining_metadata(
    request: &WorkRequestContext,
    args: Vec<String>,
    key: String,
    state_roots: &WorkerStateRoots,
    pipeline_state: &Arc<Mutex<PipelineState>>,
) -> (i32, String) {
    let filtered = strip_pipelining_flags(&args);

    let sep = filtered.iter().position(|a| a == "--");
    let (pw_raw, rustc_and_after) = match sep {
        Some(pos) => (&filtered[..pos], &filtered[pos + 1..]),
        None => return (1, "pipelining: no '--' separator in args".to_string()),
    };
    if rustc_and_after.is_empty() {
        return (1, "pipelining: no rustc executable after '--'".to_string());
    }

    // Note: we intentionally do NOT drain completed entries here. Background rustc
    // entries must remain in PipelineState until handle_pipelining_full() takes them,
    // even if the child has already exited (fast-compiling crates often finish codegen
    // before the full action arrives). Entries are cleaned up by take() in the full
    // handler, or persist harmlessly until worker exit for orphaned entries.

    let ctx = match create_pipeline_context(state_roots, &key, request) {
        Ok(v) => v,
        Err(e) => return e,
    };

    // execroot_dir is already canonicalized (absolute) in both sandboxed and
    // unsandboxed modes, so ${pwd} substitution produces correct absolute paths
    // for env vars like OUT_DIR=${pwd}/bazel-out/...
    let raw_pw_args = parse_pw_args(pw_raw, &ctx.execroot_dir);
    let pw_args = ParsedPwArgs {
        subst: raw_pw_args.subst,
        env_files: raw_pw_args
            .env_files
            .into_iter()
            .map(|path| {
                resolve_relative_to(&path, &ctx.execroot_dir)
                    .display()
                    .to_string()
            })
            .collect(),
        arg_files: raw_pw_args
            .arg_files
            .into_iter()
            .map(|path| {
                resolve_relative_to(&path, &ctx.execroot_dir)
                    .display()
                    .to_string()
            })
            .collect(),
        stable_status_file: raw_pw_args.stable_status_file.map(|path| {
            resolve_relative_to(&path, &ctx.execroot_dir)
                .display()
                .to_string()
        }),
        volatile_status_file: raw_pw_args.volatile_status_file.map(|path| {
            resolve_relative_to(&path, &ctx.execroot_dir)
                .display()
                .to_string()
        }),
        output_file: raw_pw_args.output_file.map(|path| {
            let base = request
                .sandbox_dir
                .as_deref()
                .map(std::path::Path::new)
                .unwrap_or(ctx.execroot_dir.as_path());
            resolve_relative_to(&path, base).display().to_string()
        }),
    };
    let env = build_rustc_env(
        &pw_args.env_files,
        pw_args.stable_status_file.as_deref(),
        pw_args.volatile_status_file.as_deref(),
        &pw_args.subst,
    );

    let (rustc_args, original_out_dir) =
        match prepare_rustc_args(rustc_and_after, &pw_args, &ctx.execroot_dir) {
            Ok(v) => v,
            Err(e) => return e,
        };

    // Redirect --out-dir to our persistent directory so rustc writes all outputs
    // (.rlib, .d) there instead of the Bazel-managed out-dir.
    let rustc_args = rewrite_out_dir_in_expanded(rustc_args, &ctx.outputs_dir);
    // Also redirect --emit=metadata=<path> to the outputs dir so the .rmeta is
    // written alongside other outputs in the persistent pipeline dir, not in the
    // real execroot where it could conflict with concurrent builds.
    let rustc_args = rewrite_emit_metadata_path(rustc_args, &ctx.outputs_dir);
    prepare_expanded_rustc_outputs(&rustc_args);
    append_pipeline_log(
        &ctx.root_dir,
        &format!(
            "metadata start request_id={} key={} sandbox_dir={:?} inputs={} original_out_dir={} execroot={} outputs={}",
            request.request_id,
            key,
            request.sandbox_dir,
            request.inputs.len(),
            original_out_dir,
            ctx.execroot_dir.display(),
            ctx.outputs_dir.display(),
        ),
    );
    // On Windows, rustc's internal search-path buffer is limited to ~32K characters.
    // Consolidate all -Ldependency dirs into one directory with hardlinks, then
    // write all args to a response file to also avoid CreateProcessW limits.
    #[cfg(windows)]
    let _consolidated_dir_guard: Option<PathBuf>;
    #[cfg(windows)]
    let mut rustc_args = rustc_args;
    #[cfg(windows)]
    {
        let unified_dir = ctx.root_dir.join("deps");
        let _ = std::fs::remove_dir_all(&unified_dir);
        if let Err(e) = std::fs::create_dir_all(&unified_dir) {
            return (
                1,
                format!("pipelining: failed to create deps dir: {e}"),
            );
        }

        let dep_dirs: Vec<PathBuf> = rustc_args
            .iter()
            .filter_map(|a| a.strip_prefix("-Ldependency=").map(PathBuf::from))
            .collect();
        crate::util::consolidate_deps_into(&dep_dirs, &unified_dir);
        rustc_args.retain(|a| !a.starts_with("-Ldependency="));
        rustc_args.push(format!("-Ldependency={}", unified_dir.display()));
        _consolidated_dir_guard = Some(unified_dir);
    }

    // Spawn rustc with the prepared env and args.
    // On Windows, write args to a response file to avoid CreateProcessW length limits.
    let mut cmd = Command::new(&rustc_args[0]);
    #[cfg(windows)]
    {
        let response_file_path = ctx.root_dir.join("metadata_rustc.args");
        let content = rustc_args[1..].join("\n");
        if let Err(e) = std::fs::write(&response_file_path, &content) {
            return (
                1,
                format!("pipelining: failed to write response file: {e}"),
            );
        }
        cmd.arg(format!("@{}", response_file_path.display()));
    }
    #[cfg(not(windows))]
    {
        cmd.args(&rustc_args[1..]);
    }
    cmd.env_clear()
        .envs(&env)
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .current_dir(&ctx.execroot_dir);
    let mut child = match cmd.spawn() {
        Ok(c) => c,
        Err(e) => return (1, format!("pipelining: failed to spawn rustc: {e}")),
    };

    let stderr = child.stderr.take().expect("stderr was piped");
    let mut reader = BufReader::new(stderr);
    let mut diagnostics = String::new();

    loop {
        let mut line = String::new();
        match reader.read_line(&mut line) {
            Ok(0) => break,
            Err(_) => break,
            Ok(_) => {}
        }
        let trimmed = line.trim_end_matches('\n').trim_end_matches('\r');

        if let Some(rmeta_path_str) = extract_rmeta_path(trimmed) {
            // Resolve the rmeta path relative to rustc's CWD (ctx.execroot_dir)
            // to get an absolute path, since the worker process has a different CWD.
            let rmeta_resolved = resolve_relative_to(&rmeta_path_str, &ctx.execroot_dir);
            let rmeta_resolved_str = rmeta_resolved.display().to_string();
            append_pipeline_log(
                &ctx.root_dir,
                &format!("metadata rmeta ready: {}", rmeta_resolved_str),
            );
            // Copy .rmeta to the declared output location (_pipeline/ subdirectory).
            match request.sandbox_dir.as_ref() {
                Some(dir) => {
                    copy_output_to_sandbox(
                        &rmeta_resolved_str,
                        dir,
                        &original_out_dir,
                        "_pipeline",
                    );
                }
                None => {
                    let rmeta_src = &rmeta_resolved;
                    if let Some(filename) = rmeta_src.file_name() {
                        let dest_pipeline =
                            std::path::Path::new(&original_out_dir).join("_pipeline");
                        let _ = std::fs::create_dir_all(&dest_pipeline);
                        let dest = dest_pipeline.join(filename);
                        // Skip copy if source and dest resolve to the same file.
                        let same_file = rmeta_src
                            .canonicalize()
                            .ok()
                            .zip(dest.canonicalize().ok())
                            .is_some_and(|(a, b)| a == b);
                        if !same_file {
                            let _ = std::fs::copy(rmeta_src, &dest);
                        }
                    }
                }
            }
            // .rmeta is ready! Spawn a drain thread to prevent pipe buffer deadlock.
            let drain = thread::spawn(move || {
                let mut remaining = String::new();
                let mut buf = String::new();
                while reader.read_line(&mut buf).unwrap_or(0) > 0 {
                    let l = buf.trim_end_matches('\n').trim_end_matches('\r');
                    if let Ok(json) = l.parse::<JsonValue>() {
                        if let Some(rendered) = extract_rendered_diagnostic(&json) {
                            remaining.push_str(&rendered);
                            remaining.push('\n');
                        }
                    }
                    buf.clear();
                }
                remaining
            });

            let diagnostics_before = diagnostics.clone();
            lock_or_recover(pipeline_state).store(
                key.clone(),
                BackgroundRustc {
                    child,
                    metadata_request_id: request.request_id,
                    diagnostics_before,
                    stderr_drain: drain,
                    pipeline_root_dir: ctx.root_dir.clone(),
                    pipeline_output_dir: ctx.outputs_dir.clone(),
                    original_out_dir,
                },
            );
            append_pipeline_log(&ctx.root_dir, &format!("metadata stored key={}", key));
            if let Some(ref path) = pw_args.output_file {
                let _ = std::fs::write(path, &diagnostics);
            }
            return (0, diagnostics);
        }

        if let Ok(json) = trimmed.parse::<JsonValue>() {
            if let Some(rendered) = extract_rendered_diagnostic(&json) {
                diagnostics.push_str(&rendered);
                diagnostics.push('\n');
            }
        }
    }

    // EOF: rustc exited before emitting the metadata artifact (compilation error).
    let exit_code = child.wait().ok().and_then(|s| s.code()).unwrap_or(1);
    maybe_cleanup_pipeline_dir(
        &ctx.root_dir,
        true,
        "metadata rustc exited before emitting rmeta",
    );
    if let Some(ref path) = pw_args.output_file {
        let _ = std::fs::write(path, &diagnostics);
    }
    (exit_code, diagnostics)
}

/// Handles a `--pipelining-full` request (sandboxed or unsandboxed).
///
/// Looks up the background rustc by pipeline key. If found, waits for it to
/// finish and copies outputs to the correct location. If not found (worker was
/// restarted), falls back to running rustc normally as a one-shot compilation.
pub(super) fn handle_pipelining_full(
    request: &WorkRequestContext,
    args: Vec<String>,
    key: String,
    pipeline_state: &Arc<Mutex<PipelineState>>,
    self_path: &std::path::Path,
) -> (i32, String) {
    let bg = lock_or_recover(pipeline_state).take(&key);

    match bg {
        Some(mut bg) => {
            append_pipeline_log(&bg.pipeline_root_dir, &format!("full start key={}", key));
            // Join the drain thread first (avoids deadlock: child blocks on stderr
            // write if the pipe buffer fills up before we drain it).
            let remaining = bg.stderr_drain.join().unwrap_or_default();
            let all_diagnostics = bg.diagnostics_before + &remaining;

            match bg.child.wait() {
                Ok(status) => {
                    let exit_code = status.code().unwrap_or(1);
                    if exit_code == 0 {
                        // Copy all outputs from the persistent pipeline dir.
                        match request.sandbox_dir.as_ref() {
                            Some(dir) => {
                                copy_all_outputs_to_sandbox(
                                    &bg.pipeline_output_dir,
                                    dir,
                                    &bg.original_out_dir,
                                );
                            }
                            None => {
                                let dest_dir = std::path::Path::new(&bg.original_out_dir);
                                let _ = std::fs::create_dir_all(dest_dir);
                                if let Ok(entries) = std::fs::read_dir(&bg.pipeline_output_dir) {
                                    for entry in entries.flatten() {
                                        if let Ok(meta) = entry.metadata() {
                                            if meta.is_file() {
                                                let dest = dest_dir.join(entry.file_name());
                                                let _ = std::fs::copy(entry.path(), &dest);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    append_pipeline_log(
                        &bg.pipeline_root_dir,
                        &format!("full done key={} exit_code={}", key, exit_code),
                    );
                    maybe_cleanup_pipeline_dir(
                        &bg.pipeline_root_dir,
                        exit_code != 0,
                        "full action failed",
                    );
                    (exit_code, all_diagnostics)
                }
                Err(e) => (1, format!("failed to wait for background rustc: {e}")),
            }
        }
        None => {
            let worker_state_root = std::env::current_dir()
                .ok()
                .map(|cwd| cwd.join("_pw_state").join("fallback.log"));
            if let Some(path) = worker_state_root {
                if let Ok(mut file) = std::fs::OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open(path)
                {
                    let _ = writeln!(
                        file,
                        "full missing bg request_id={} key={} sandbox_dir={:?}",
                        request.request_id, key, request.sandbox_dir
                    );
                }
            }
            // No cached process found (worker was restarted between the metadata
            // and full actions, or metadata was a cache hit). Fall back to a normal
            // one-shot compilation.
            let filtered_args = strip_pipelining_flags(&args);
            match request.sandbox_dir.as_ref() {
                Some(dir) => run_sandboxed_request(self_path, filtered_args, dir)
                    .unwrap_or_else(|e| (1, format!("pipelining fallback error: {e}"))),
                None => {
                    prepare_outputs(&filtered_args);
                    run_request(self_path, filtered_args)
                        .unwrap_or_else(|e| (1, format!("pipelining fallback error: {e}")))
                }
            }
        }
    }
}

/// Kills the background rustc process associated with a cancelled request.
///
/// Looks up the pipeline key by metadata_request_id, then kills the child
/// process and joins the stderr drain thread. This prevents wasted CPU when
/// the remote leg wins a dynamic execution race.
pub(super) fn kill_pipelined_request(pipeline_state: &Arc<Mutex<PipelineState>>, request_id: i64) {
    let mut state = lock_or_recover(pipeline_state);
    let key_to_kill: Option<String> = state.active.iter().find_map(|(key, bg)| {
        if bg.metadata_request_id == request_id {
            Some(key.clone())
        } else {
            None
        }
    });
    if let Some(key) = key_to_kill {
        if let Some(mut bg) = state.active.remove(&key) {
            append_worker_lifecycle_log(&format!(
                "pid={} event=cancel_kill request_id={} key={}",
                current_pid(),
                request_id,
                key,
            ));
            let _ = bg.child.kill();
            let _ = bg.child.wait(); // reap zombie
            let _ = bg.stderr_drain.join();
        }
    }
}

/// Extracts the artifact path from an rmeta artifact notification JSON line.
/// Returns `Some(path)` for `{"artifact":"path/to/lib.rmeta","emit":"metadata"}`,
/// `None` for all other lines.
pub(super) fn extract_rmeta_path(line: &str) -> Option<String> {
    if let Ok(JsonValue::Object(ref map)) = line.parse::<JsonValue>() {
        if let (Some(JsonValue::String(artifact)), Some(JsonValue::String(emit))) =
            (map.get("artifact"), map.get("emit"))
        {
            if artifact.ends_with(".rmeta") && emit == "metadata" {
                return Some(artifact.clone());
            }
        }
    }
    None
}

/// Extracts the `"rendered"` field from a rustc JSON diagnostic message.
pub(super) fn extract_rendered_diagnostic(json: &JsonValue) -> Option<String> {
    if let JsonValue::Object(ref map) = json {
        if let Some(JsonValue::String(rendered)) = map.get("rendered") {
            return Some(rendered.clone());
        }
    }
    None
}

pub(super) fn append_pipeline_log(pipeline_root: &std::path::Path, message: &str) {
    let path = pipeline_root.join("pipeline.log");
    let mut file = match std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)
    {
        Ok(file) => file,
        Err(_) => return,
    };
    let _ = writeln!(file, "{message}");
}

pub(super) fn maybe_cleanup_pipeline_dir(
    pipeline_root: &std::path::Path,
    keep: bool,
    reason: &str,
) {
    if keep {
        append_pipeline_log(
            pipeline_root,
            &format!("preserving pipeline dir for inspection: {reason}"),
        );
        return;
    }

    if let Err(err) = std::fs::remove_dir_all(pipeline_root) {
        append_pipeline_log(
            pipeline_root,
            &format!("failed to remove pipeline dir during cleanup: {err}"),
        );
    }
}

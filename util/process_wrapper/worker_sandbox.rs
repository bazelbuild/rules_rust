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

//! Sandbox helpers for the persistent worker.

use std::path::PathBuf;
use std::process::{Command, Stdio};

use super::pipeline::OutputMaterializationStats;
use super::types::MaterializeError;
use crate::ProcessWrapperError;

/// Returns `true` if both paths resolve to the same inode after canonicalization.
/// Returns `false` if either path doesn't exist or can't be canonicalized.
pub(super) fn is_same_file(a: &std::path::Path, b: &std::path::Path) -> bool {
    match (a.canonicalize(), b.canonicalize()) {
        (Ok(a), Ok(b)) => a == b,
        _ => false,
    }
}

pub(super) fn resolve_relative_to(path: &str, base_dir: &std::path::Path) -> PathBuf {
    let path = std::path::Path::new(path);
    if path.is_absolute() {
        path.to_path_buf()
    } else {
        base_dir.join(path)
    }
}

pub(super) fn resolve_request_relative_path(
    path: &str,
    request_base_dir: Option<&std::path::Path>,
) -> PathBuf {
    match request_base_dir {
        Some(base_dir) => resolve_relative_to(path, base_dir),
        None => PathBuf::from(path),
    }
}

pub(super) fn materialize_output_file(
    src: &std::path::Path,
    dest: &std::path::Path,
) -> Result<bool, std::io::Error> {
    if let Some(parent) = dest.parent() {
        std::fs::create_dir_all(parent)?;
    }

    // Skip if src and dest resolve to the same file (e.g., when rustc writes
    // directly into the sandbox via --emit=metadata=<relative-path> and the
    // copy destination is the same location). Removing dest would delete src.
    if is_same_file(src, dest) {
        return Ok(false);
    }

    if dest.exists() {
        std::fs::remove_file(dest)?;
    }

    match std::fs::hard_link(src, dest) {
        Ok(()) => Ok(true),
        Err(link_err) => match std::fs::copy(src, dest) {
            Ok(_) => Ok(false),
            Err(copy_err) => Err(std::io::Error::new(
                copy_err.kind(),
                format!(
                    "failed to materialize {} at {} via hardlink ({link_err}) or copy ({copy_err})",
                    src.display(),
                    dest.display(),
                ),
            )),
        },
    }
}

#[cfg(unix)]
pub(super) fn symlink_path(
    src: &std::path::Path,
    dest: &std::path::Path,
    _is_dir: bool,
) -> Result<(), std::io::Error> {
    std::os::unix::fs::symlink(src, dest)
}

#[cfg(windows)]
pub(super) fn symlink_path(
    src: &std::path::Path,
    dest: &std::path::Path,
    is_dir: bool,
) -> Result<(), std::io::Error> {
    if is_dir {
        std::os::windows::fs::symlink_dir(src, dest)
    } else {
        std::os::windows::fs::symlink_file(src, dest)
    }
}

pub(super) fn seed_sandbox_cache_root(
    sandbox_dir: &std::path::Path,
) -> Result<(), ProcessWrapperError> {
    let dest = sandbox_dir.join("cache");
    if dest.exists() {
        return Ok(());
    }

    let entries = std::fs::read_dir(sandbox_dir).map_err(|e| {
        ProcessWrapperError(format!(
            "failed to read request sandbox for cache seeding: {e}"
        ))
    })?;

    for entry in entries {
        let entry = entry.map_err(|e| {
            ProcessWrapperError(format!("failed to enumerate request sandbox entry: {e}"))
        })?;
        let source = entry.path();
        let Ok(resolved) = source.canonicalize() else {
            continue;
        };

        let mut cache_root = None;
        for ancestor in resolved.ancestors() {
            if ancestor.file_name().is_some_and(|name| name == "cache") {
                cache_root = Some(ancestor.to_path_buf());
                break;
            }
        }

        let Some(cache_root) = cache_root else {
            continue;
        };
        return symlink_path(&cache_root, &dest, true).map_err(|e| {
            ProcessWrapperError(format!(
                "failed to seed request sandbox cache root {} -> {}: {e}",
                cache_root.display(),
                dest.display(),
            ))
        });
    }

    Ok(())
}

/// Copies the file at `src` into `<sandbox_dir>/<original_out_dir>/<dest_subdir>/`.
///
/// Used after the metadata action to make the `.rmeta` file visible to Bazel
/// inside the sandbox before the sandbox is cleaned up.
pub(super) fn copy_output_to_sandbox(
    src: &str,
    sandbox_dir: &str,
    original_out_dir: &str,
    dest_subdir: &str,
) -> Result<OutputMaterializationStats, MaterializeError> {
    let mut stats = OutputMaterializationStats::default();
    let src_path = std::path::Path::new(src);
    let filename = match src_path.file_name() {
        Some(n) => n,
        None => {
            return Err(MaterializeError {
                path: src_path.to_path_buf(),
                cause: std::io::Error::new(
                    std::io::ErrorKind::InvalidInput,
                    "source path has no filename",
                ),
            });
        }
    };
    let dest_dir = std::path::Path::new(sandbox_dir)
        .join(original_out_dir)
        .join(dest_subdir);
    let dest = dest_dir.join(filename);
    let hardlinked = materialize_output_file(src_path, &dest)
        .map_err(|cause| MaterializeError { path: dest, cause })?;
    stats.files = 1;
    if hardlinked {
        stats.hardlinked_files = 1;
    } else {
        stats.copied_files = 1;
    }
    Ok(stats)
}

/// Copies all regular files from `pipeline_dir` into `<sandbox_dir>/<original_out_dir>/`.
///
/// Used by the full action to move the `.rlib` (and `.d`, etc.) from the
/// persistent directory into the sandbox before responding to Bazel.
pub(super) fn copy_all_outputs_to_sandbox(
    pipeline_dir: &PathBuf,
    sandbox_dir: &str,
    original_out_dir: &str,
) -> Result<OutputMaterializationStats, MaterializeError> {
    let dest_dir = std::path::Path::new(sandbox_dir).join(original_out_dir);
    let mut stats = OutputMaterializationStats::default();
    let entries = std::fs::read_dir(pipeline_dir).map_err(|cause| MaterializeError {
        path: pipeline_dir.clone(),
        cause,
    })?;
    for entry in entries {
        let entry = entry.map_err(|cause| MaterializeError {
            path: pipeline_dir.clone(),
            cause,
        })?;
        let meta = entry.metadata().map_err(|cause| MaterializeError {
            path: entry.path(),
            cause,
        })?;
        if meta.is_file() {
            let dest = dest_dir.join(entry.file_name());
            let hardlinked = materialize_output_file(&entry.path(), &dest)
                .map_err(|cause| MaterializeError { path: dest, cause })?;
            stats.files += 1;
            if hardlinked {
                stats.hardlinked_files += 1;
            } else {
                stats.copied_files += 1;
            }
        }
    }
    Ok(stats)
}

/// Like `run_request` but sets `current_dir(sandbox_dir)` on the subprocess.
///
/// When Bazel provides a `sandboxDir`, setting the subprocess CWD to it makes
/// all relative paths in arguments resolve correctly within the sandbox.
pub(super) fn run_sandboxed_request(
    self_path: &std::path::Path,
    arguments: Vec<String>,
    sandbox_dir: &str,
) -> Result<(i32, String), ProcessWrapperError> {
    let _ = seed_sandbox_cache_root(std::path::Path::new(sandbox_dir));
    run_request_with_current_dir(
        self_path,
        arguments,
        Some(sandbox_dir),
        "sandboxed subprocess",
    )
}

/// Ensures output files in rustc's `--out-dir` are writable before each request.
///
/// Workers run in execroot without sandboxing. Bazel marks action outputs
/// read-only after each successful action, and the disk cache hardlinks them
/// as read-only. With pipelined compilation, two separate actions (RustcMetadata
/// and Rustc) both write to the same `.rmeta` path. After the first succeeds,
/// Bazel makes its output read-only; the second worker request then fails with
/// "output file ... is not writeable".
///
/// This function scans `args` for `--out-dir=<dir>` — both inline and inside any
/// `--arg-file <path>` (process_wrapper's own arg-file mechanism) or `@flagfile`
/// (Bazel's param file convention) — and makes all regular files in those
/// directories writable.
pub(super) fn prepare_outputs(args: &[String]) {
    prepare_outputs_impl(args, None);
}

pub(super) fn prepare_outputs_in_dir(args: &[String], request_base_dir: &std::path::Path) {
    prepare_outputs_impl(args, Some(request_base_dir));
}

fn prepare_outputs_impl(args: &[String], request_base_dir: Option<&std::path::Path>) {
    let mut out_dirs: Vec<String> = Vec::new();

    let mut i = 0;
    while i < args.len() {
        let arg = &args[i];
        if let Some(dir) = arg.strip_prefix("--out-dir=") {
            out_dirs.push(
                resolve_request_relative_path(dir, request_base_dir)
                    .display()
                    .to_string(),
            );
        } else if let Some(flagfile_path) = arg.strip_prefix('@') {
            scan_file_for_out_dir(flagfile_path, request_base_dir, &mut out_dirs);
        } else if arg == "--arg-file" {
            if let Some(path) = args.get(i + 1) {
                scan_file_for_out_dir(path, request_base_dir, &mut out_dirs);
                i += 1;
            }
        }
        i += 1;
    }

    for out_dir in out_dirs {
        make_dir_files_writable(&out_dir);
        let pipeline_dir = format!("{out_dir}/_pipeline");
        make_dir_files_writable(&pipeline_dir);
    }
}

/// Reads `path` line-by-line, collecting any `--out-dir=<dir>` values.
/// When `request_base_dir` is `Some`, resolves both the paramfile path and any
/// discovered output directories against it.
pub(super) fn scan_file_for_out_dir(
    path: &str,
    request_base_dir: Option<&std::path::Path>,
    out_dirs: &mut Vec<String>,
) {
    let path = resolve_request_relative_path(path, request_base_dir);
    let Ok(content) = std::fs::read_to_string(&path) else {
        return;
    };
    for line in content.lines() {
        if let Some(dir) = line.strip_prefix("--out-dir=") {
            out_dirs.push(
                resolve_request_relative_path(dir, request_base_dir)
                    .display()
                    .to_string(),
            );
        }
    }
}

/// Makes all regular files in `dir` writable (removes read-only bit).
pub(super) fn make_dir_files_writable(dir: &str) {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        if let Ok(meta) = entry.metadata() {
            if meta.is_file() {
                let mut perms = meta.permissions();
                if perms.readonly() {
                    perms.set_readonly(false);
                    let _ = std::fs::set_permissions(entry.path(), perms);
                }
            }
        }
    }
}

pub(super) fn make_path_writable(path: &std::path::Path) {
    let Ok(meta) = std::fs::metadata(path) else {
        return;
    };
    if !meta.is_file() {
        return;
    }

    let mut perms = meta.permissions();
    if perms.readonly() {
        perms.set_readonly(false);
        let _ = std::fs::set_permissions(path, perms);
    }
}

/// Executes a single WorkRequest by spawning process_wrapper with the given
/// arguments. Returns (exit_code, combined_output).
///
/// The spawned process runs with the worker's environment and working directory
/// (Bazel's execroot), so incremental compilation caches see stable paths.
pub(super) fn run_request(
    self_path: &std::path::Path,
    arguments: Vec<String>,
) -> Result<(i32, String), ProcessWrapperError> {
    run_request_with_current_dir(self_path, arguments, None, "process_wrapper subprocess")
}

fn run_request_with_current_dir(
    self_path: &std::path::Path,
    arguments: Vec<String>,
    current_dir: Option<&str>,
    context: &str,
) -> Result<(i32, String), ProcessWrapperError> {
    let mut command = Command::new(self_path);
    command
        .args(&arguments)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    if let Some(dir) = current_dir {
        command.current_dir(dir);
    }
    let output = command
        .output()
        .map_err(|e| ProcessWrapperError(format!("failed to spawn {context}: {e}")))?;
    Ok(collect_subprocess_output(output))
}

/// Spawns a process_wrapper subprocess and returns the Child handle.
/// The caller is responsible for waiting on the child.
pub(super) fn spawn_request(
    self_path: &std::path::Path,
    arguments: Vec<String>,
    current_dir: Option<&str>,
    context: &str,
) -> Result<std::process::Child, ProcessWrapperError> {
    let mut command = Command::new(self_path);
    command
        .args(&arguments)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    if let Some(dir) = current_dir {
        command.current_dir(dir);
    }
    command
        .spawn()
        .map_err(|e| ProcessWrapperError(format!("failed to spawn {context}: {e}")))
}

fn collect_subprocess_output(output: std::process::Output) -> (i32, String) {
    let exit_code = output.status.code().unwrap_or(1);
    let mut combined = String::from_utf8_lossy(&output.stdout).into_owned();
    combined.push_str(&String::from_utf8_lossy(&output.stderr));
    (exit_code, combined)
}

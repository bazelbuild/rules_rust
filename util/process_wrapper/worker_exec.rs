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

//! General subprocess execution, file utilities, and process management
//! for the persistent worker.
//!
//! Functions here are used by both sandboxed and non-sandboxed code paths.
//! Sandbox-specific logic stays in worker_sandbox.rs.

use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::time::Duration;

use crate::ProcessWrapperError;

// ---------------------------------------------------------------------------
// Platform-specific kill helpers
// ---------------------------------------------------------------------------

#[cfg(unix)]
unsafe extern "C" {
    fn kill(pid: i32, sig: i32) -> i32;
}

#[cfg(unix)]
pub(super) fn send_sigterm(pid: u32) {
    if pid > i32::MAX as u32 {
        return; // Prevent wrapping to negative (process group kill).
    }
    unsafe {
        kill(pid as i32, 15); // SIGTERM
    }
}

#[cfg(not(unix))]
pub(super) fn send_sigterm(_pid: u32) {
    // No SIGTERM on non-Unix; graceful_kill will use Child::kill().
}

/// Send SIGTERM, poll try_wait for 500ms (10 x 50ms), then SIGKILL + wait.
pub(crate) fn graceful_kill(child: &mut Child) {
    #[cfg(unix)]
    {
        send_sigterm(child.id());
        for _ in 0..10 {
            match child.try_wait() {
                Ok(Some(_)) => return,
                _ => std::thread::sleep(Duration::from_millis(50)),
            }
        }
        let _ = child.kill();
        let _ = child.wait();
    }
    #[cfg(not(unix))]
    {
        let _ = child.kill();
        let _ = child.wait();
    }
}

// ---------------------------------------------------------------------------
// Path utilities
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Output writability helpers
// ---------------------------------------------------------------------------

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

pub(super) fn prepare_outputs_impl(args: &[String], request_base_dir: Option<&std::path::Path>) {
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

// ---------------------------------------------------------------------------
// Subprocess execution
// ---------------------------------------------------------------------------

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

pub(super) fn run_request_with_current_dir(
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

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

//! Shared subprocess and filesystem helpers for the persistent worker.

use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::time::Duration;

use crate::ProcessWrapperError;

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
    // Non-Unix falls back to `Child::kill()` in `graceful_kill`.
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

    // Avoid deleting the source when rustc already wrote to the destination.
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

/// Makes files under each discovered `--out-dir` writable before a request runs.
///
/// Bazel can leave prior outputs read-only, especially when metadata and full
/// actions reuse the same paths. This scans direct args, `--arg-file`, and
/// `@flagfile` contents.
///
/// When `request_base_dir` is `Some`, relative paths in args are resolved against
/// that directory (used for sandboxed requests). When `None`, paths resolve
/// against the current working directory.
pub(super) fn prepare_outputs(args: &[String], request_base_dir: Option<&std::path::Path>) {
    let mut out_dirs: Vec<String> = Vec::new();

    let mut args_iter = args.iter().peekable();
    while let Some(arg) = args_iter.next() {
        if let Some(dir) = arg.strip_prefix("--out-dir=") {
            out_dirs.push(
                resolve_request_relative_path(dir, request_base_dir)
                    .display()
                    .to_string(),
            );
        } else if let Some(flagfile_path) = arg.strip_prefix('@') {
            scan_file_for_out_dir(flagfile_path, request_base_dir, &mut out_dirs);
        } else if arg == "--arg-file" {
            if let Some(path) = args_iter.peek() {
                scan_file_for_out_dir(path, request_base_dir, &mut out_dirs);
                args_iter.next();
            }
        }
    }

    for out_dir in out_dirs {
        make_dir_files_writable(&out_dir);
        let pipeline_dir = format!("{out_dir}/_pipeline");
        make_dir_files_writable(&pipeline_dir);
    }
}

/// Reads `path` and collects any `--out-dir=<dir>` values.
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

/// Makes all regular files in `dir` writable.
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

/// Runs one process_wrapper subprocess and returns its exit code and output.
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

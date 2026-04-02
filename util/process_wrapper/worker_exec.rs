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

use std::path::{Path, PathBuf};
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
pub(super) fn is_same_file(a: &Path, b: &Path) -> bool {
    match (a.canonicalize(), b.canonicalize()) {
        (Ok(a), Ok(b)) => a == b,
        _ => false,
    }
}

pub(super) fn resolve_request_relative_path(
    path: &str,
    request_base_dir: Option<&Path>,
) -> PathBuf {
    match request_base_dir {
        Some(base_dir) => {
            let path = Path::new(path);
            if path.is_absolute() {
                path.to_path_buf()
            } else {
                base_dir.join(path)
            }
        }
        None => PathBuf::from(path),
    }
}

pub(super) fn materialize_output_file(src: &Path, dest: &Path) -> Result<bool, std::io::Error> {
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
pub(super) fn prepare_outputs(args: &[String], request_base_dir: Option<&Path>) {
    let mut out_dirs: Vec<PathBuf> = Vec::new();

    let mut args_iter = args.iter().peekable();
    while let Some(arg) = args_iter.next() {
        if let Some(dir) = arg.strip_prefix("--out-dir=") {
            out_dirs.push(resolve_request_relative_path(dir, request_base_dir));
        } else if let Some(flagfile_path) = arg.strip_prefix('@') {
            let resolved = resolve_request_relative_path(flagfile_path, request_base_dir);
            out_dirs.extend(scan_file_for_out_dir(&resolved, request_base_dir));
        } else if arg == "--arg-file" {
            if let Some(path) = args_iter.peek() {
                let resolved = resolve_request_relative_path(path, request_base_dir);
                out_dirs.extend(scan_file_for_out_dir(&resolved, request_base_dir));
                args_iter.next();
            }
        }
    }

    for out_dir in &out_dirs {
        make_dir_files_writable(out_dir);
        make_dir_files_writable(&out_dir.join("_pipeline"));
    }
}

/// Reads a param/arg file and returns any `--out-dir=<dir>` values found.
pub(super) fn scan_file_for_out_dir(
    argfile_path: &Path,
    request_base_dir: Option<&Path>,
) -> Vec<PathBuf> {
    let Ok(content) = std::fs::read_to_string(argfile_path) else {
        return Vec::new();
    };
    content
        .lines()
        .filter_map(|line| line.strip_prefix("--out-dir="))
        .map(|dir| resolve_request_relative_path(dir, request_base_dir))
        .collect()
}

/// Makes all regular files in `dir` writable.
pub(super) fn make_dir_files_writable(dir: &Path) {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    for entry in entries.flatten() {
        let Ok(meta) = entry.metadata() else {
            continue;
        };
        if !meta.is_file() || !meta.permissions().readonly() {
            continue;
        }
        let mut perms = meta.permissions();
        perms.set_readonly(false);
        let _ = std::fs::set_permissions(entry.path(), perms);
    }
}

#[derive(Default, Debug, Clone, PartialEq, Eq)]
pub(super) struct ExpandedRustcOutputs {
    pub(super) out_dir: Option<String>,
    pub(super) emit_paths: Vec<String>,
}

pub(super) fn prepare_expanded_rustc_outputs(outputs: &ExpandedRustcOutputs) {
    if let Some(dir) = outputs.out_dir.as_deref() {
        let dir = Path::new(dir);
        make_dir_files_writable(dir);
        make_dir_files_writable(&dir.join("_pipeline"));
    }

    for path in &outputs.emit_paths {
        let path = Path::new(path);
        if let Ok(meta) = std::fs::metadata(path) {
            if meta.is_file() && meta.permissions().readonly() {
                let mut perms = meta.permissions();
                perms.set_readonly(false);
                let _ = std::fs::set_permissions(path, perms);
            }
        }
    }
}

/// Spawns a process_wrapper subprocess and returns the Child handle.
/// The caller is responsible for waiting on the child.
pub(super) fn spawn_request(
    self_path: &Path,
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

pub(super) fn run_request(
    self_path: &Path,
    arguments: Vec<String>,
    current_dir: Option<&str>,
    context: &str,
) -> Result<(i32, String), ProcessWrapperError> {
    let child = spawn_request(self_path, arguments, current_dir, context)?;
    let output = child
        .wait_with_output()
        .map_err(|e| ProcessWrapperError(format!("failed to wait on {context}: {e}")))?;
    let exit_code = output.status.code().unwrap_or(1);
    let mut combined = String::from_utf8_lossy(&output.stdout).into_owned();
    combined.push_str(&String::from_utf8_lossy(&output.stderr));
    Ok((exit_code, combined))
}

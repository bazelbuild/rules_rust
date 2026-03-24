// Copyright 2020 The Bazel Authors. All rights reserved.
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

mod flags;
mod options;
mod output;
mod rustc;
mod util;

use std::collections::HashMap;
use std::fmt;
use std::fs::{self, copy, OpenOptions};
use std::io;
use std::path::Path;
use std::process::{exit, Command, ExitStatus, Stdio};

use tinyjson::JsonValue;

use crate::options::options;
use crate::output::{process_output, LineOutput};
use crate::rustc::ErrorFormat;

#[cfg(windows)]
fn status_code(status: ExitStatus, was_killed: bool) -> i32 {
    // On windows, there's no good way to know if the process was killed by a signal.
    // If we killed the process, we override the code to signal success.
    if was_killed {
        0
    } else {
        status.code().unwrap_or(1)
    }
}

#[cfg(not(windows))]
fn status_code(status: ExitStatus, was_killed: bool) -> i32 {
    // On unix, if code is None it means that the process was killed by a signal.
    // https://doc.rust-lang.org/std/process/struct.ExitStatus.html#method.success
    match status.code() {
        Some(code) => code,
        // If we killed the process, we expect None here
        None if was_killed => 0,
        // Otherwise it's some unexpected signal
        None => 1,
    }
}

#[derive(Debug)]
struct ProcessWrapperError(String);

impl fmt::Display for ProcessWrapperError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "process wrapper error: {}", self.0)
    }
}

impl std::error::Error for ProcessWrapperError {}

macro_rules! debug_log {
    ($($arg:tt)*) => {
        if std::env::var_os("RULES_RUST_PROCESS_WRAPPER_DEBUG").is_some() {
            eprintln!($($arg)*);
        }
    };
}

fn json_warning(line: &str) -> JsonValue {
    JsonValue::Object(HashMap::from([
        (
            "$message_type".to_string(),
            JsonValue::String("diagnostic".to_string()),
        ),
        ("message".to_string(), JsonValue::String(line.to_string())),
        ("code".to_string(), JsonValue::Null),
        (
            "level".to_string(),
            JsonValue::String("warning".to_string()),
        ),
        ("spans".to_string(), JsonValue::Array(Vec::new())),
        ("children".to_string(), JsonValue::Array(Vec::new())),
        ("rendered".to_string(), JsonValue::String(line.to_string())),
    ]))
}

fn process_line(
    mut line: String,
    quit_on_rmeta: bool,
    format: ErrorFormat,
    metadata_emitted: &mut bool,
) -> Result<LineOutput, String> {
    // LLVM can emit lines that look like the following, and these will be interspersed
    // with the regular JSON output. Arguably, rustc should be fixed not to emit lines
    // like these (or to convert them to JSON), but for now we convert them to JSON
    // ourselves.
    if line.contains("is not a recognized feature for this target (ignoring feature)")
        || line.starts_with(" WARN ")
    {
        if let Ok(json_str) = json_warning(&line).stringify() {
            line = json_str;
        } else {
            return Ok(LineOutput::Skip);
        }
    }
    if quit_on_rmeta {
        rustc::stop_on_rmeta_completion(line, format, metadata_emitted)
    } else {
        rustc::process_json(line, format)
    }
}

/// Cross-device link error (POSIX `EXDEV`, errno 18).
const EXDEV_RAW: i32 = 18;

/// Result of walking a directory tree.
struct TreeWalk {
    /// Destination directories to create, in parent-before-child order.
    dirs: Vec<std::path::PathBuf>,
    /// (source, destination) file pairs to hardlink or copy.
    files: Vec<(std::path::PathBuf, std::path::PathBuf)>,
    /// Total size of all source files in bytes.
    total_bytes: u64,
}

/// Walk `src` recursively, collecting directory and file entries mapped to `dst`.
/// Symlinks are skipped (defense-in-depth).  Also computes the total file size
/// in a single pass.
fn collect_tree_entries(src: &Path, dst: &Path) -> io::Result<TreeWalk> {
    let mut dirs = Vec::new();
    let mut files = Vec::new();
    let mut total_bytes = 0u64;
    let mut stack = vec![(src.to_path_buf(), dst.to_path_buf())];
    while let Some((s, d)) = stack.pop() {
        let entries = match fs::read_dir(&s) {
            Ok(e) => e,
            Err(e) if e.kind() == io::ErrorKind::NotFound => continue,
            Err(e) => return Err(e),
        };
        for entry in entries {
            let entry = entry?;
            let ft = entry.file_type()?;
            if ft.is_symlink() {
                continue;
            }
            let src_path = entry.path();
            let dst_path = d.join(entry.file_name());
            if ft.is_dir() {
                dirs.push(dst_path.clone());
                stack.push((src_path, dst_path));
            } else {
                if let Ok(meta) = entry.metadata() {
                    total_bytes += meta.len();
                }
                files.push((src_path, dst_path));
            }
        }
    }
    Ok(TreeWalk {
        dirs,
        files,
        total_bytes,
    })
}

/// Hardlink (or copy on `EXDEV`) a single file from `src` to `dst`.
fn hardlink_one(src: &Path, dst: &Path) -> io::Result<()> {
    match fs::hard_link(src, dst) {
        Ok(()) => Ok(()),
        Err(e) if e.raw_os_error() == Some(EXDEV_RAW) => {
            fs::copy(src, dst)?;
            Ok(())
        }
        Err(e) => Err(e),
    }
}

/// Create directories and hardlink files from a pre-collected tree walk.
/// Falls back to `fs::copy` on cross-device errors.
/// File hardlinks are parallelized across threads for large trees.
fn hardlink_entries(walk: &TreeWalk) -> io::Result<usize> {
    for dir in &walk.dirs {
        fs::create_dir(dir)?;
    }

    let count = walk.files.len();
    if count == 0 {
        return Ok(0);
    }

    const PARALLEL_THRESHOLD: usize = 256;
    if count < PARALLEL_THRESHOLD {
        for (s, d) in &walk.files {
            hardlink_one(s, d)?;
        }
        return Ok(count);
    }

    let n_threads = std::thread::available_parallelism()
        .map(std::num::NonZero::get)
        .unwrap_or(4)
        .min(8);
    let chunk_size = (count + n_threads - 1) / n_threads;

    std::thread::scope(|s| {
        let handles: Vec<_> = walk
            .files
            .chunks(chunk_size)
            .map(|chunk| {
                s.spawn(move || -> io::Result<()> {
                    for (src, dst) in chunk {
                        hardlink_one(src, dst)?;
                    }
                    Ok(())
                })
            })
            .collect();
        for handle in handles {
            handle.join().expect("hardlink thread panicked")?;
        }
        Ok(count)
    })
}

/// Seed the incremental compilation cache by hardlinking from a source
/// directory.  Skips seeding when the source is below `min_bytes`.
/// Errors are logged but never fatal (cold start fallback).
fn seed_incremental_cache(src: &Path, dst: &Path, min_bytes: u64, label: &str) {
    let walk = match collect_tree_entries(src, dst) {
        Ok(w) => w,
        Err(e) => {
            eprintln!("process_wrapper: {label} seed walk failed: {e}, starting cold");
            return;
        }
    };
    if walk.total_bytes < min_bytes {
        debug_log!(
            "process_wrapper: {label} seed {} below threshold ({} < {min_bytes}), skipping",
            src.display(),
            walk.total_bytes
        );
        return;
    }
    match hardlink_entries(&walk) {
        Ok(0) => debug_log!("process_wrapper: empty {label} seed at {}", src.display()),
        Ok(n) => debug_log!(
            "process_wrapper: {label} seeded {n} files ({} bytes) {} -> {}",
            walk.total_bytes,
            src.display(),
            dst.display()
        ),
        Err(e) => eprintln!("process_wrapper: {label} seed hardlink failed: {e}, starting cold"),
    }
}

fn main() -> Result<(), ProcessWrapperError> {
    let opts = options().map_err(|e| ProcessWrapperError(e.to_string()))?;

    // Seed the incremental compilation cache from the previous build's output.
    let seed_min_bytes = opts.seed_min_mb * 1024 * 1024;
    if let Some((ref seed_dir, ref dest_dir)) = opts.copy_seed {
        seed_incremental_cache(
            Path::new(seed_dir),
            Path::new(dest_dir),
            seed_min_bytes,
            "copy",
        );
    }

    if let Some((ref prev_dir, ref dest_dir)) = opts.seed_prev_dir {
        let prev_path = Path::new(prev_dir);
        if prev_path.is_dir() {
            seed_incremental_cache(prev_path, Path::new(dest_dir), seed_min_bytes, "prev");
        } else {
            debug_log!("process_wrapper: prev seed {prev_dir} not found, cold start");
        }
    }

    if opts.exit_early {
        return Ok(());
    }

    let mut command = Command::new(opts.executable);
    command
        .args(opts.child_arguments)
        .env_clear()
        .envs(opts.child_environment)
        .stdout(if let Some(stdout_file) = opts.stdout_file {
            OpenOptions::new()
                .create(true)
                .truncate(true)
                .write(true)
                .open(stdout_file)
                .map_err(|e| ProcessWrapperError(format!("unable to open stdout file: {}", e)))?
                .into()
        } else {
            Stdio::inherit()
        })
        .stderr(Stdio::piped());
    debug_log!("{:#?}", command);
    let mut child = command
        .spawn()
        .map_err(|e| ProcessWrapperError(format!("failed to spawn child process: {}", e)))?;

    let mut stderr: Box<dyn io::Write> = if let Some(stderr_file) = opts.stderr_file {
        Box::new(
            OpenOptions::new()
                .create(true)
                .truncate(true)
                .write(true)
                .open(stderr_file)
                .map_err(|e| ProcessWrapperError(format!("unable to open stderr file: {}", e)))?,
        )
    } else {
        Box::new(io::stderr())
    };

    let mut child_stderr = child.stderr.take().ok_or(ProcessWrapperError(
        "unable to get child stderr".to_string(),
    ))?;

    let mut output_file: Option<std::fs::File> = if let Some(output_file_name) = opts.output_file {
        Some(
            OpenOptions::new()
                .create(true)
                .truncate(true)
                .write(true)
                .open(output_file_name)
                .map_err(|e| ProcessWrapperError(format!("Unable to open output_file: {}", e)))?,
        )
    } else {
        None
    };

    let mut was_killed = false;
    let result = if let Some(format) = opts.rustc_output_format {
        let quit_on_rmeta = opts.rustc_quit_on_rmeta;
        // Process json rustc output and kill the subprocess when we get a signal
        // that we emitted a metadata file.
        let mut me = false;
        let metadata_emitted = &mut me;
        let result = process_output(
            &mut child_stderr,
            stderr.as_mut(),
            output_file.as_mut(),
            move |line| process_line(line, quit_on_rmeta, format, metadata_emitted),
        );
        if me {
            // If recv returns Ok(), a signal was sent in this channel so we should terminate the child process.
            // We can safely ignore the Result from kill() as we don't care if the process already terminated.
            let _ = child.kill();
            was_killed = true;
        }
        result
    } else {
        // Process output normally by forwarding stderr
        process_output(
            &mut child_stderr,
            stderr.as_mut(),
            output_file.as_mut(),
            move |line| Ok(LineOutput::Message(line)),
        )
    };
    result.map_err(|e| ProcessWrapperError(format!("failed to process stderr: {}", e)))?;

    let status = child
        .wait()
        .map_err(|e| ProcessWrapperError(format!("failed to wait for child process: {}", e)))?;
    // If the child process is rustc and is killed after metadata generation, that's also a success.
    let code = status_code(status, was_killed);
    let success = code == 0;
    if success {
        if let Some(tf) = opts.touch_file {
            OpenOptions::new()
                .create(true)
                .truncate(true)
                .write(true)
                .open(tf)
                .map_err(|e| ProcessWrapperError(format!("failed to create touch file: {}", e)))?;
        }
        if let Some((copy_source, copy_dest)) = opts.copy_output {
            copy(&copy_source, &copy_dest).map_err(|e| {
                ProcessWrapperError(format!(
                    "failed to copy {} into {}: {}",
                    copy_source, copy_dest, e
                ))
            })?;
        }
        // Write the unused inputs list so Bazel excludes the seed directory
        // from cache key computation.  This ensures that changes to the
        // incremental seed (which changes every build) don't cause cache
        // misses for the rustc action -- only source file changes do.
        if let Some((ref unused_file, ref input_path)) = opts.write_unused_inputs {
            std::fs::write(unused_file, format!("{input_path}\n")).unwrap_or_else(|e| {
                eprintln!("process_wrapper: failed to write unused inputs to {unused_file}: {e}");
            });
        }
    }

    exit(code)
}

#[cfg(test)]
mod test {
    use super::*;

    fn parse_json(json_str: &str) -> Result<JsonValue, String> {
        json_str.parse::<JsonValue>().map_err(|e| e.to_string())
    }

    #[test]
    fn test_process_line_diagnostic_json() -> Result<(), String> {
        let mut metadata_emitted = false;
        let LineOutput::Message(msg) = process_line(
            r#"
                {
                    "$message_type": "diagnostic",
                    "rendered": "Diagnostic message"
                }
            "#
            .to_string(),
            false,
            ErrorFormat::Json,
            &mut metadata_emitted,
        )?
        else {
            return Err("Expected a LineOutput::Message".to_string());
        };
        assert_eq!(
            parse_json(&msg)?,
            parse_json(
                r#"
                {
                    "$message_type": "diagnostic",
                    "rendered": "Diagnostic message"
                }
            "#
            )?
        );
        Ok(())
    }

    #[test]
    fn test_process_line_diagnostic_rendered() -> Result<(), String> {
        let mut metadata_emitted = false;
        let LineOutput::Message(msg) = process_line(
            r#"
                {
                    "$message_type": "diagnostic",
                    "rendered": "Diagnostic message"
                }
            "#
            .to_string(),
            /*quit_on_rmeta=*/ false,
            ErrorFormat::Rendered,
            &mut metadata_emitted,
        )?
        else {
            return Err("Expected a LineOutput::Message".to_string());
        };
        assert_eq!(msg, "Diagnostic message");
        Ok(())
    }

    #[test]
    fn test_process_line_noise() -> Result<(), String> {
        let mut metadata_emitted = false;
        for text in [
            "'+zaamo' is not a recognized feature for this target (ignoring feature)",
            " WARN rustc_errors::emitter Invalid span...",
        ] {
            let LineOutput::Message(msg) = process_line(
                text.to_string(),
                /*quit_on_rmeta=*/ false,
                ErrorFormat::Json,
                &mut metadata_emitted,
            )?
            else {
                return Err("Expected a LineOutput::Message".to_string());
            };
            assert_eq!(
                parse_json(&msg)?,
                parse_json(&format!(
                    r#"{{
                        "$message_type": "diagnostic",
                        "message": "{0}",
                        "code": null,
                        "level": "warning",
                        "spans": [],
                        "children": [],
                        "rendered": "{0}"
                    }}"#,
                    text
                ))?
            );
        }
        Ok(())
    }

    #[test]
    fn test_process_line_emit_link() -> Result<(), String> {
        let mut metadata_emitted = false;
        assert!(matches!(
            process_line(
                r#"
                {
                    "$message_type": "artifact",
                    "emit": "link"
                }
            "#
                .to_string(),
                /*quit_on_rmeta=*/ true,
                ErrorFormat::Rendered,
                &mut metadata_emitted,
            )?,
            LineOutput::Skip
        ));
        assert!(!metadata_emitted);
        Ok(())
    }

    #[test]
    fn test_process_line_emit_metadata() -> Result<(), String> {
        let mut metadata_emitted = false;
        assert!(matches!(
            process_line(
                r#"
                {
                    "$message_type": "artifact",
                    "emit": "metadata"
                }
            "#
                .to_string(),
                /*quit_on_rmeta=*/ true,
                ErrorFormat::Rendered,
                &mut metadata_emitted,
            )?,
            LineOutput::Terminate
        ));
        assert!(metadata_emitted);
        Ok(())
    }
}

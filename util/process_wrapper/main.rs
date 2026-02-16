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
#[cfg(windows)]
use std::collections::{HashSet, VecDeque};
use std::fmt;
use std::fs::{self, copy, OpenOptions};
use std::io;
use std::path::PathBuf;
use std::process::{exit, Command, ExitStatus, Stdio};
#[cfg(windows)]
use std::time::{SystemTime, UNIX_EPOCH};

use tinyjson::JsonValue;

use crate::options::options;
use crate::output::{process_output, LineOutput};
use crate::rustc::ErrorFormat;
#[cfg(windows)]
use crate::util::read_file_to_array;

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

#[cfg(windows)]
struct TemporaryDirectoryGuard {
    path: Option<PathBuf>,
}

#[cfg(windows)]
impl TemporaryDirectoryGuard {
    fn new(path: Option<PathBuf>) -> Self {
        Self { path }
    }

    fn take(&mut self) -> Option<PathBuf> {
        self.path.take()
    }
}

#[cfg(windows)]
impl Drop for TemporaryDirectoryGuard {
    fn drop(&mut self) {
        if let Some(path) = self.path.take() {
            let _ = fs::remove_dir_all(path);
        }
    }
}

#[cfg(not(windows))]
struct TemporaryDirectoryGuard;

#[cfg(not(windows))]
impl TemporaryDirectoryGuard {
    fn new(_: Option<PathBuf>) -> Self {
        TemporaryDirectoryGuard
    }

    fn take(&mut self) -> Option<PathBuf> {
        None
    }
}

#[cfg(windows)]
fn get_dependency_search_paths_from_args(
    initial_args: &[String],
) -> Result<(Vec<PathBuf>, Vec<String>), ProcessWrapperError> {
    let mut dependency_paths = Vec::new();
    let mut filtered_args = Vec::new();
    let mut argfile_contents: HashMap<String, Vec<String>> = HashMap::new();

    let mut queue: VecDeque<(String, Option<String>)> = initial_args
        .iter()
        .map(|arg| (arg.clone(), None))
        .collect();

    while let Some((arg, parent_argfile)) = queue.pop_front() {
        let target = match &parent_argfile {
            Some(p) => argfile_contents.entry(format!("{}.filtered", p)).or_default(),
            None => &mut filtered_args,
        };

        if arg == "-L" {
            let next_arg = queue.front().map(|(a, _)| a.as_str());
            if let Some(path) = next_arg.and_then(|n| n.strip_prefix("dependency=")) {
                dependency_paths.push(PathBuf::from(path));
                queue.pop_front();
            } else {
                target.push(arg);
            }
        } else if let Some(path) = arg.strip_prefix("-Ldependency=") {
            dependency_paths.push(PathBuf::from(path));
        } else if let Some(argfile_path) = arg.strip_prefix('@') {
            let lines = read_file_to_array(argfile_path).map_err(|e| {
                ProcessWrapperError(format!("unable to read argfile {}: {}", argfile_path, e))
            })?;

            for line in lines {
                queue.push_back((line, Some(argfile_path.to_string())));
            }

            target.push(format!("@{}.filtered", argfile_path));
        } else {
            target.push(arg);
        }
    }

    for (path, content) in argfile_contents {
        fs::write(&path, content.join("\n")).map_err(|e| {
            ProcessWrapperError(format!("unable to write filtered argfile {}: {}", path, e))
        })?;
    }

    Ok((dependency_paths, filtered_args))
}

#[cfg(windows)]
fn consolidate_dependency_search_paths(
    args: &[String],
) -> Result<(Vec<String>, Option<PathBuf>), ProcessWrapperError> {
    let (dependency_paths, mut filtered_args) = get_dependency_search_paths_from_args(args)?;

    if dependency_paths.is_empty() {
        return Ok((filtered_args, None));
    }

    let unique_suffix = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis();
    let dir_name = format!(
        "rules_rust_process_wrapper_deps_{}_{}",
        std::process::id(),
        unique_suffix
    );

    let base_dir = std::env::current_dir().map_err(|e| {
        ProcessWrapperError(format!("unable to read current working directory: {}", e))
    })?;
    let unified_dir = base_dir.join(&dir_name);
    fs::create_dir_all(&unified_dir).map_err(|e| {
        ProcessWrapperError(format!(
            "unable to create unified dependency directory {}: {}",
            unified_dir.display(),
            e
        ))
    })?;

    let mut seen = HashSet::new();
    for path in dependency_paths {
        let entries = fs::read_dir(&path).map_err(|e| {
            ProcessWrapperError(format!(
                "unable to read dependency search path {}: {}",
                path.display(),
                e
            ))
        })?;

        for entry in entries {
            let entry = entry.map_err(|e| {
                ProcessWrapperError(format!(
                    "unable to iterate dependency search path {}: {}",
                    path.display(),
                    e
                ))
            })?;
            let file_type = entry.file_type().map_err(|e| {
                ProcessWrapperError(format!(
                    "unable to inspect dependency search path {}: {}",
                    path.display(),
                    e
                ))
            })?;
            if !(file_type.is_file() || file_type.is_symlink()) {
                continue;
            }

            let file_name = entry.file_name();
            let file_name_lower = file_name
                .to_string_lossy()
                .to_ascii_lowercase();
            if !seen.insert(file_name_lower) {
                continue;
            }

            let dest = unified_dir.join(&file_name);
            let src = entry.path();
            match fs::hard_link(&src, &dest) {
                Ok(_) => {}
                Err(err) if err.kind() == std::io::ErrorKind::AlreadyExists => {}
                Err(err) => {
                    debug_log!(
                        "failed to hardlink {} to {} ({}), falling back to copy",
                        src.display(),
                        dest.display(),
                        err
                    );
                    fs::copy(&src, &dest).map_err(|copy_err| {
                        ProcessWrapperError(format!(
                            "unable to copy {} into unified dependency dir {}: {}",
                            src.display(),
                            dest.display(),
                            copy_err
                        ))
                    })?;
                }
            }
        }
    }

    filtered_args.push(format!("-Ldependency={}", unified_dir.display()));

    Ok((filtered_args, Some(unified_dir)))
}

#[cfg(not(windows))]
fn consolidate_dependency_search_paths(
    args: &[String],
) -> Result<(Vec<String>, Option<PathBuf>), ProcessWrapperError> {
    Ok((args.to_vec(), None))
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

fn main() -> Result<(), ProcessWrapperError> {
    let opts = options().map_err(|e| ProcessWrapperError(e.to_string()))?;

    let (child_arguments, dep_dir_cleanup) =
        consolidate_dependency_search_paths(&opts.child_arguments)?;
    let mut temp_dir_guard = TemporaryDirectoryGuard::new(dep_dir_cleanup);

    let mut command = Command::new(opts.executable);
    command
        .args(child_arguments)
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
    }

    if let Some(path) = temp_dir_guard.take() {
        let _ = fs::remove_dir_all(path);
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

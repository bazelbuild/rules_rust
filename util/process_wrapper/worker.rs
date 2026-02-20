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

//! Bazel JSON persistent worker protocol implementation.
//!
//! When Bazel invokes process_wrapper with `--persistent_worker`, this module
//! takes over. It reads newline-delimited JSON WorkRequest messages from stdin,
//! executes each request by spawning process_wrapper itself with the request's
//! arguments, and writes a JSON WorkResponse to stdout.
//!
//! The worker runs in Bazel's execroot (without sandboxing), so incremental
//! compilation caches see stable source file paths between requests—avoiding
//! the ICE that occurs when sandbox paths change between builds.
//!
//! Protocol reference: https://bazel.build/remote/persistent

use std::collections::HashMap;
use std::io::{self, BufRead, Write};
use std::process::{Command, Stdio};

use tinyjson::JsonValue;

use crate::ProcessWrapperError;

/// Entry point for persistent worker mode.
///
/// Loops reading JSON WorkRequest messages from stdin until EOF,
/// executing each as a subprocess and writing a JSON WorkResponse to stdout.
///
/// Bazel starts the worker with:
///   `process_wrapper [startup_args] --persistent_worker`
/// where `startup_args` are the fixed parts of the action command line
/// (e.g. `--subst pwd=${pwd} -- /path/to/rustc`).
///
/// Each WorkRequest.arguments contains the per-request part (the `@flagfile`).
/// The worker must combine startup_args + per-request args when spawning the
/// subprocess, so process_wrapper receives the full argument list it expects.
pub(crate) fn worker_main() -> Result<(), ProcessWrapperError> {
    let self_path = std::env::current_exe()
        .map_err(|e| ProcessWrapperError(format!("failed to get worker executable path: {e}")))?;

    // Collect the startup args that Bazel passed when spawning this worker
    // process. These are the fixed action args (e.g. `--subst pwd=${pwd} --
    // /path/to/rustc`). We skip argv[0] (the binary path) and strip
    // `--persistent_worker` since that flag is what triggered worker mode.
    let startup_args: Vec<String> = std::env::args()
        .skip(1)
        .filter(|a| a != "--persistent_worker")
        .collect();

    let stdin = io::stdin();
    let mut stdout = io::stdout();

    for line in stdin.lock().lines() {
        let line =
            line.map_err(|e| ProcessWrapperError(format!("failed to read WorkRequest: {e}")))?;
        if line.is_empty() {
            continue;
        }

        let request: JsonValue = line
            .parse()
            .map_err(|e: tinyjson::JsonParseError| {
                ProcessWrapperError(format!("failed to parse WorkRequest JSON: {e}"))
            })?;

        let request_id = extract_request_id(&request);

        // Per-request args from WorkRequest (typically just `["@flagfile"]`).
        // Combine with startup_args to form the full subprocess command line.
        let mut full_args = startup_args.clone();
        full_args.extend(extract_arguments(&request));

        // Workers run in execroot without sandboxing. Bazel marks action outputs
        // read-only after each successful action, and the disk cache hardlinks them
        // as read-only. The next worker request (e.g. the full Rustc action after
        // a RustcMetadata action that already wrote the same .rmeta path) would
        // fail with "output file ... is not writeable". Make them writable first.
        prepare_outputs(&full_args);

        let (exit_code, output) = run_request(&self_path, full_args)?;

        let response = build_response(exit_code, &output, request_id);
        writeln!(stdout, "{response}")
            .map_err(|e| ProcessWrapperError(format!("failed to write WorkResponse: {e}")))?;
        stdout
            .flush()
            .map_err(|e| ProcessWrapperError(format!("failed to flush stdout: {e}")))?;
    }

    Ok(())
}

/// Extracts the `requestId` field from a WorkRequest (defaults to 0).
fn extract_request_id(request: &JsonValue) -> i64 {
    if let JsonValue::Object(map) = request {
        if let Some(JsonValue::Number(id)) = map.get("requestId") {
            return *id as i64;
        }
    }
    0
}

/// Extracts the `arguments` array from a WorkRequest.
fn extract_arguments(request: &JsonValue) -> Vec<String> {
    if let JsonValue::Object(map) = request {
        if let Some(JsonValue::Array(args)) = map.get("arguments") {
            return args
                .iter()
                .filter_map(|v| {
                    if let JsonValue::String(s) = v {
                        Some(s.clone())
                    } else {
                        None
                    }
                })
                .collect();
        }
    }
    vec![]
}

/// Executes a single WorkRequest by spawning process_wrapper with the given
/// arguments. Returns (exit_code, combined_output).
///
/// The spawned process runs with the worker's environment and working directory
/// (Bazel's execroot), so incremental compilation caches see stable paths.
fn run_request(
    self_path: &std::path::Path,
    arguments: Vec<String>,
) -> Result<(i32, String), ProcessWrapperError> {
    let output = Command::new(self_path)
        .args(&arguments)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| {
            ProcessWrapperError(format!("failed to spawn process_wrapper subprocess: {e}"))
        })?;

    let exit_code = output.status.code().unwrap_or(1);

    // Combine stdout and stderr for the WorkResponse output field.
    // process_wrapper normally writes rustc diagnostics to its stderr,
    // so this captures compilation errors/warnings for display in Bazel.
    let mut combined = String::from_utf8_lossy(&output.stdout).into_owned();
    combined.push_str(&String::from_utf8_lossy(&output.stderr));

    Ok((exit_code, combined))
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
fn prepare_outputs(args: &[String]) {
    let mut out_dirs: Vec<String> = Vec::new();

    let mut i = 0;
    while i < args.len() {
        let arg = &args[i];
        if let Some(dir) = arg.strip_prefix("--out-dir=") {
            out_dirs.push(dir.to_string());
        } else if let Some(flagfile_path) = arg.strip_prefix('@') {
            // Bazel @flagfile: one arg per line.
            scan_file_for_out_dir(flagfile_path, &mut out_dirs);
        } else if arg == "--arg-file" {
            // process_wrapper's --arg-file <path>: reads child (rustc) args from file.
            if let Some(path) = args.get(i + 1) {
                scan_file_for_out_dir(path, &mut out_dirs);
                i += 1; // skip the path argument
            }
        }
        i += 1;
    }

    for out_dir in out_dirs {
        make_dir_files_writable(&out_dir);
    }
}

/// Reads `path` line-by-line, collecting any `--out-dir=<dir>` values.
fn scan_file_for_out_dir(path: &str, out_dirs: &mut Vec<String>) {
    let Ok(content) = std::fs::read_to_string(path) else {
        return;
    };
    for line in content.lines() {
        if let Some(dir) = line.strip_prefix("--out-dir=") {
            out_dirs.push(dir.to_string());
        }
    }
}

/// Makes all regular files in `dir` writable (removes read-only bit).
fn make_dir_files_writable(dir: &str) {
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

/// Builds a JSON WorkResponse string.
fn build_response(exit_code: i32, output: &str, request_id: i64) -> String {
    let response = JsonValue::Object(HashMap::from([
        (
            "exitCode".to_string(),
            JsonValue::Number(exit_code as f64),
        ),
        ("output".to_string(), JsonValue::String(output.to_string())),
        (
            "requestId".to_string(),
            JsonValue::Number(request_id as f64),
        ),
    ]));
    response.stringify().unwrap_or_else(|_| {
        // Fallback: hand-craft a minimal valid response if stringify fails.
        format!(r#"{{"exitCode":{exit_code},"output":"","requestId":{request_id}}}"#)
    })
}

#[cfg(test)]
mod test {
    use super::*;

    fn parse_json(s: &str) -> JsonValue {
        s.parse().unwrap()
    }

    #[test]
    fn test_extract_request_id_present() {
        let req = parse_json(r#"{"requestId": 42, "arguments": []}"#);
        assert_eq!(extract_request_id(&req), 42);
    }

    #[test]
    fn test_extract_request_id_missing() {
        let req = parse_json(r#"{"arguments": []}"#);
        assert_eq!(extract_request_id(&req), 0);
    }

    #[test]
    fn test_extract_arguments() {
        let req = parse_json(r#"{"requestId": 0, "arguments": ["--subst", "pwd=/work", "--", "rustc"]}"#);
        assert_eq!(
            extract_arguments(&req),
            vec!["--subst", "pwd=/work", "--", "rustc"]
        );
    }

    #[test]
    fn test_extract_arguments_empty() {
        let req = parse_json(r#"{"requestId": 0, "arguments": []}"#);
        assert_eq!(extract_arguments(&req), Vec::<String>::new());
    }

    #[test]
    #[cfg(unix)]
    fn test_prepare_outputs_inline_out_dir() {
        use std::fs;
        use std::os::unix::fs::PermissionsExt;

        let dir = std::env::temp_dir().join("pw_test_prepare_inline");
        fs::create_dir_all(&dir).unwrap();
        let file_path = dir.join("libfoo.rmeta");
        fs::write(&file_path, b"content").unwrap();

        let mut perms = fs::metadata(&file_path).unwrap().permissions();
        perms.set_mode(0o444);
        fs::set_permissions(&file_path, perms).unwrap();
        assert!(fs::metadata(&file_path).unwrap().permissions().readonly());

        let args = vec![format!("--out-dir={}", dir.display())];
        prepare_outputs(&args);

        assert!(!fs::metadata(&file_path).unwrap().permissions().readonly());
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    #[cfg(unix)]
    fn test_prepare_outputs_arg_file() {
        use std::fs;
        use std::os::unix::fs::PermissionsExt;

        let tmp = std::env::temp_dir().join("pw_test_prepare_argfile");
        fs::create_dir_all(&tmp).unwrap();

        // Create the output dir and a read-only file in it.
        let out_dir = tmp.join("out");
        fs::create_dir_all(&out_dir).unwrap();
        let file_path = out_dir.join("libfoo.rmeta");
        fs::write(&file_path, b"content").unwrap();
        let mut perms = fs::metadata(&file_path).unwrap().permissions();
        perms.set_mode(0o444);
        fs::set_permissions(&file_path, perms).unwrap();
        assert!(fs::metadata(&file_path).unwrap().permissions().readonly());

        // Write an --arg-file containing --out-dir.
        let arg_file = tmp.join("rustc.params");
        fs::write(&arg_file, format!("--out-dir={}\n--crate-name=foo\n", out_dir.display())).unwrap();

        let args = vec![
            "--arg-file".to_string(),
            arg_file.display().to_string(),
        ];
        prepare_outputs(&args);

        assert!(!fs::metadata(&file_path).unwrap().permissions().readonly());
        let _ = fs::remove_dir_all(&tmp);
    }

    #[test]
    fn test_build_response_success() {
        let response = build_response(0, "", 0);
        let parsed = parse_json(&response);
        if let JsonValue::Object(map) = parsed {
            assert!(matches!(map.get("exitCode"), Some(JsonValue::Number(n)) if *n == 0.0));
            assert!(matches!(map.get("requestId"), Some(JsonValue::Number(n)) if *n == 0.0));
        } else {
            panic!("expected object");
        }
    }

    #[test]
    fn test_build_response_failure() {
        let response = build_response(1, "error: type mismatch", 0);
        let parsed = parse_json(&response);
        if let JsonValue::Object(map) = parsed {
            assert!(matches!(map.get("exitCode"), Some(JsonValue::Number(n)) if *n == 1.0));
            assert!(
                matches!(map.get("output"), Some(JsonValue::String(s)) if s == "error: type mismatch")
            );
        } else {
            panic!("expected object");
        }
    }
}

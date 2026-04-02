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

//! Threads that own rustc child processes for worker requests.

use std::io::BufRead;
use std::process::Child;
use std::sync::Arc;

use super::exec::graceful_kill;
use super::invocation::{InvocationDirs, RustcInvocation};
use crate::rustc::RustcStderrPolicy;

/// Spawns a thread that waits on a non-pipelined child process.
pub(crate) fn spawn_non_pipelined_rustc(child: Child) -> Arc<RustcInvocation> {
    let invocation = Arc::new(RustcInvocation::new());
    let pid = child.id();

    // Non-pipelined invocations do not use pipeline directories.
    invocation.transition_to_running(pid, InvocationDirs::default());

    let ret = Arc::clone(&invocation);
    std::thread::spawn(move || {
        let output = child.wait_with_output();

        if invocation.is_shutdown_requested() {
            invocation.transition_to_finished(-1, "shutdown requested".to_string());
            return;
        }

        let (exit_code, diagnostics) = match output {
            Ok(output) => {
                let exit_code = output.status.code().unwrap_or(-1);
                let mut diagnostics = String::from_utf8_lossy(&output.stderr).into_owned();
                let stdout = String::from_utf8_lossy(&output.stdout);
                if !stdout.is_empty() {
                    if !diagnostics.is_empty() {
                        diagnostics.push('\n');
                    }
                    diagnostics.push_str(&stdout);
                }
                (exit_code, diagnostics)
            }
            Err(e) => (-1, format!("wait_with_output failed: {}", e)),
        };

        invocation.transition_to_finished(exit_code, diagnostics);
    });

    ret
}

/// Spawns a thread that tracks a pipelined rustc process through completion.
pub(crate) fn spawn_pipelined_rustc(
    mut child: Child,
    dirs: InvocationDirs,
    rustc_output_format: Option<String>,
) -> Arc<RustcInvocation> {
    let invocation = Arc::new(RustcInvocation::new());
    let pid = child.id();
    let stderr = child
        .stderr
        .take()
        .expect("child must be spawned with Stdio::piped() stderr");

    invocation.transition_to_running(pid, dirs);

    let ret = Arc::clone(&invocation);
    std::thread::spawn(move || {
        let reader = std::io::BufReader::new(stderr);
        let mut policy = RustcStderrPolicy::from_option_str(rustc_output_format.as_deref());

        let mut diagnostics = String::new();
        let mut lines = reader.lines().map_while(Result::ok);

        // Read until rustc reports the `.rmeta` artifact.
        for line in lines.by_ref() {
            if let Some(rmeta_path) = crate::rustc::extract_rmeta_path(&line) {
                invocation.transition_to_metadata_ready(
                    pid,
                    diagnostics.clone(),
                    Some(rmeta_path),
                );
                break;
            }
            if let Some(processed) = policy.process_line(&line) {
                if !diagnostics.is_empty() {
                    diagnostics.push('\n');
                }
                diagnostics.push_str(&processed);
            }
        }

        // Drain the remaining diagnostics after metadata.
        for line in lines {
            if crate::rustc::extract_rmeta_path(&line).is_some() {
                continue;
            }
            if let Some(processed) = policy.process_line(&line) {
                if !diagnostics.is_empty() {
                    diagnostics.push('\n');
                }
                diagnostics.push_str(&processed);
            }
        }

        // stderr closed; rustc is likely exiting.
        if invocation.is_shutdown_requested() {
            graceful_kill(&mut child);
            invocation.transition_to_finished(-1, "shutdown requested".to_string());
            return;
        }

        let exit_code = match child.wait() {
            Ok(status) => status.code().unwrap_or(-1),
            Err(_) => -1,
        };

        invocation.transition_to_finished(exit_code, diagnostics);
    });

    ret
}

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

use std::fs::{copy, OpenOptions};
use std::io;
use std::process::{exit, Command, ExitStatus, Stdio};

use crate::options::options;
use crate::output::{process_output, LineOutput};

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

fn main() {
    let opts = match options() {
        Err(err) => panic!("process wrapper error: {}", err),
        Ok(v) => v,
    };

    let mut child = Command::new(opts.executable)
        .args(opts.child_arguments)
        .env_clear()
        .envs(opts.child_environment)
        .stdout(if let Some(stdout_file) = opts.stdout_file {
            OpenOptions::new()
                .create(true)
                .truncate(true)
                .write(true)
                .open(stdout_file)
                .expect("process wrapper error: unable to open stdout file")
                .into()
        } else {
            Stdio::inherit()
        })
        .stderr(Stdio::piped())
        .spawn()
        .expect("process wrapper error: failed to spawn child process");

    let mut stderr: Box<dyn io::Write> = if let Some(stderr_file) = opts.stderr_file {
        Box::new(
            OpenOptions::new()
                .create(true)
                .truncate(true)
                .write(true)
                .open(stderr_file)
                .expect("process wrapper error: unable to open stderr file"),
        )
    } else {
        Box::new(io::stderr())
    };

    let mut child_stderr = child.stderr.take().unwrap();

    let mut was_killed = false;
    let result = if let Some(format) = opts.rustc_output_format {
        let quit_on_rmeta = opts.rustc_quit_on_rmeta;
        // Process json rustc output and kill the subprocess when we get a signal
        // that we emitted a metadata file.
        let mut me = false;
        let metadata_emitted = &mut me;
        let result = process_output(&mut child_stderr, stderr.as_mut(), move |line| {
            if quit_on_rmeta {
                rustc::stop_on_rmeta_completion(line, format, metadata_emitted)
            } else {
                rustc::process_json(line, format)
            }
        });
        if me {
            // If recv returns Ok(), a signal was sent in this channel so we should terminate the child process.
            // We can safely ignore the Result from kill() as we don't care if the process already terminated.
            let _ = child.kill();
            was_killed = true;
        }
        result
    } else {
        // Process output normally by forwarding stderr
        process_output(&mut child_stderr, stderr.as_mut(), LineOutput::Message)
    };
    result.expect("process wrapper error: failed to process stderr");

    let status = child
        .wait()
        .expect("process wrapper error: failed to wait for child process");
    // If the child process is rustc and is killed after metadata generation, that's also a success.
    let code = status_code(status, was_killed);
    let success = code == 0;
    if success {
        if let Some(tf) = opts.touch_file {
            OpenOptions::new()
                .create(true)
                .write(true)
                .open(tf)
                .expect("process wrapper error: failed to create touch file");
        }
        if let Some((copy_source, copy_dest)) = opts.copy_output {
            copy(&copy_source, &copy_dest).unwrap_or_else(|_| {
                panic!(
                    "process wrapper error: failed to copy {} into {}",
                    copy_source, copy_dest
                )
            });
        }
    }

    exit(code)
}

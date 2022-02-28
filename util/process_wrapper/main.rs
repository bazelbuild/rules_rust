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
mod util;

use std::fs::{copy, OpenOptions};
use std::process::{exit, Command, Stdio};

use crate::options::options;

fn main() {
    let opts = match options() {
        Err(err) => panic!("process wrapper error: {}", err),
        Ok(v) => v,
    };
    let stdout = if let Some(stdout_file) = opts.stdout_file {
        OpenOptions::new()
            .create(true)
            .truncate(true)
            .write(true)
            .open(stdout_file)
            .expect("process wrapper error: unable to open stdout file")
            .into()
    } else {
        Stdio::inherit()
    };
    let stderr = if let Some(stderr_file) = opts.stderr_file {
        OpenOptions::new()
            .create(true)
            .truncate(true)
            .write(true)
            .open(stderr_file)
            .expect("process wrapper error: unable to open stderr file")
            .into()
    } else {
        Stdio::inherit()
    };
    let status = Command::new(opts.executable)
        .args(opts.child_arguments)
        .env_clear()
        .envs(opts.child_environment)
        .stdout(stdout)
        .stderr(stderr)
        .status()
        .expect("process wrapper error: failed to spawn child process");

    if status.success() {
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

    exit(status.code().unwrap())
}
